import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_exception.dart';
import '../services/payout_service.dart';
import '../theme/home_feed_tokens.dart';
import '../widgets/loading/app_skeletons.dart';
import '../widgets/loading/section_loader.dart';
import '../widgets/studio_loading.dart';
import '../theme/app_fonts.dart';

/// Stripe Connect Express setup — identity and bank details stay on Stripe.
class PayoutSetupPage extends StatefulWidget {
  const PayoutSetupPage({super.key});

  @override
  State<PayoutSetupPage> createState() => _PayoutSetupPageState();
}

class _PayoutSetupPageState extends State<PayoutSetupPage>
    with WidgetsBindingObserver {
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
      final launched = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the browser.')),
        );
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Something went wrong. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _continueSetup() =>
      _openUrl(PayoutService.instance.startOnboarding);

  Future<void> _openDashboard() =>
      _openUrl(PayoutService.instance.dashboardUrl);

  @override
  Widget build(BuildContext context) {
    final ready = _status?.canListForSale == true;
    return StudioLoadingGate(
      loading: _busy,
      child: Scaffold(
        backgroundColor: HomeFeedTokens.background,
        appBar: AppBar(
          backgroundColor: HomeFeedTokens.background,
          elevation: 0,
          centerTitle: true,
          title: Text(
            ready ? 'Payouts' : 'Payout details required',
            style: AppFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: HomeFeedTokens.textPrimary,
            ),
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                color: HomeFeedTokens.textPrimary, size: 20),
            onPressed: () => Navigator.pop(context, _status?.canListForSale),
          ),
        ),
        body: SectionLoader(
          hasData: _status != null || _error != null,
          loading: _loading,
          skeleton: (_) => const FormSkeleton(
            fieldCount: 3,
            padding: EdgeInsets.fromLTRB(20, 8, 20, 32),
          ),
          content: (_) => ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  if (_error != null) ...[
                    Text(
                      _error!,
                      style: AppFonts.inter(
                        fontSize: 14,
                        color: const Color(0xFFE05252),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _PrimaryButton(label: 'Try again', onTap: _refresh),
                  ] else if (ready)
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

class _NeedsActionBody extends StatelessWidget {
  const _NeedsActionBody({required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Finish payout setup',
          style: AppFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: HomeFeedTokens.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'We need your identity and bank details so we can pay you when '
          'your work sells. Stripe collects this — we never see those details.',
          style: AppFonts.inter(
            fontSize: 14,
            color: HomeFeedTokens.textPrimary.withValues(alpha: 0.55),
            height: 1.45,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Stripe still needs a few details.',
          style: AppFonts.inter(
            fontSize: 13,
            color: HomeFeedTokens.textPrimary.withValues(alpha: 0.45),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 28),
        _PrimaryButton(label: 'Continue setup', onTap: onContinue),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            'Do this later',
            style: AppFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: HomeFeedTokens.textPrimary.withValues(alpha: 0.55),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReadyBody extends StatelessWidget {
  const _ReadyBody({required this.onOpenDashboard});

  final VoidCallback onOpenDashboard;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "You're ready to list",
          style: AppFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: HomeFeedTokens.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Payouts are set up. When a collector confirms they received a piece, '
          'payment is released to you.',
          style: AppFonts.inter(
            fontSize: 14,
            color: HomeFeedTokens.textPrimary.withValues(alpha: 0.55),
            height: 1.45,
          ),
        ),
        const SizedBox(height: 28),
        _PrimaryButton(label: 'Open payout dashboard', onTap: onOpenDashboard),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: HomeFeedTokens.neutral800,
          foregroundColor: HomeFeedTokens.textInverse,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          label,
          style: AppFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
