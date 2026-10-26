import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_exception.dart';
import '../services/payout_service.dart';
import '../widgets/loading/app_skeletons.dart';
import '../widgets/loading/section_loader.dart';
import '../widgets/studio/studio.dart';
import '../widgets/studio_loading.dart';

/// Stripe Connect Express setup — identity and bank details stay on Stripe.
class PayoutSetupPage extends StatefulWidget {
  const PayoutSetupPage({super.key});

  @override
  State<PayoutSetupPage> createState() => _PayoutSetupPageState();
}

class _PayoutSetupPageState extends State<PayoutSetupPage> with WidgetsBindingObserver {
  PayoutStatus? _status;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    try {
      final status = await PayoutService.instance.getStatus();
      if (!mounted) return;
      setState(() {
        _status = status;
        _loading = false;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 403) {
        Navigator.pop(context);
        return;
      }
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load payout status.';
      });
    }
  }

  Future<void> _openUrl(Future<String> Function() fetchUrl) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final url = await fetchUrl();
      final launched = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!launched && mounted) showStudioToast(context, 'Could not open the browser.', icon: null);
    } on ApiException catch (e) {
      if (mounted) showStudioToast(context, e.message, icon: null);
    } catch (_) {
      if (mounted) showStudioToast(context, 'Something went wrong. Try again.', icon: null);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _continueSetup() => _openUrl(PayoutService.instance.startOnboarding);

  Future<void> _openDashboard() => _openUrl(PayoutService.instance.dashboardUrl);

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final ready = _status?.canListForSale == true;
    return StudioLoadingGate(
      loading: _busy,
      child: Scaffold(
        backgroundColor: c.background,
        appBar: StudioTopBar(
          context: context,
          title: ready ? 'Payouts' : 'Payout details required',
          onBack: () => Navigator.pop(context, _status?.canListForSale),
        ),
        body: SectionLoader(
          hasData: _status != null || _error != null,
          loading: _loading,
          skeleton: (_) => const FormSkeleton(fieldCount: 3, padding: EdgeInsets.fromLTRB(24, 8, 24, 32)),
          content: (_) => ListView(
            padding: const EdgeInsets.fromLTRB(StudioSpace.marginForm, 12, StudioSpace.marginForm, 40),
            children: [
              if (_error != null)
                StudioEmptyState(
                  title: "Payouts didn't load",
                  message: _error,
                  actionLabel: 'Try again',
                  onAction: _refresh,
                )
              else if (ready)
                _ReadyBody(onOpenDashboard: _openDashboard)
              else
                _NeedsActionBody(onContinue: _continueSetup),
            ],
          ),
        ),
      ),
    );
  }
}

/// Title 22, what Stripe needs 14 Graphite and a 13 Tertiary line, Continue setup (Ink) and
/// Do this later (text).
class _NeedsActionBody extends StatelessWidget {
  const _NeedsActionBody({required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Finish payout setup', style: StudioType.title22(color: c.textPrimary)),
        const SizedBox(height: 8),
        Text(
          'We need your identity and bank details so we can pay you when '
          'your work sells. Stripe collects this — we never see those details.',
          style: StudioType.body14(color: c.textSecondary),
        ),
        const SizedBox(height: 12),
        Text('Stripe still needs a few details.', style: StudioType.label13(color: c.textTertiary)),
        const SizedBox(height: 28),
        StudioButton(label: 'Continue setup', onPressed: onContinue),
        const SizedBox(height: 4),
        StudioButton(
          label: 'Do this later',
          variant: StudioButtonVariant.text,
          onPressed: () => Navigator.pop(context, false),
        ),
      ],
    );
  }
}

/// Title 22, the line 14 Graphite, Open payout dashboard (Ink).
class _ReadyBody extends StatelessWidget {
  const _ReadyBody({required this.onOpenDashboard});

  final VoidCallback onOpenDashboard;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text("You're ready to list", style: StudioType.title22(color: c.textPrimary)),
        const SizedBox(height: 8),
        Text(
          'Payouts are set up. When a collector confirms they received a piece, '
          'payment is released to you.',
          style: StudioType.body14(color: c.textSecondary),
        ),
        const SizedBox(height: 28),
        StudioButton(label: 'Open payout dashboard', onPressed: onOpenDashboard),
      ],
    );
  }
}
