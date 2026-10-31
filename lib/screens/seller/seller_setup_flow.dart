import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/post_location_options.dart';
import '../../services/api_exception.dart';
import '../../services/auth_session.dart';
import '../../services/main_nav_service.dart';
import '../../services/payout_service.dart';
import '../../services/user_service.dart';
import '../../widgets/choose_location_sheet.dart';
import '../../widgets/studio/studio.dart';

/// What the person chose on "Turn on selling first" (`SellerPrompt`).
enum SellerPromptChoice { setUp, notForSale }

/// "Turn on selling first" (`SellerPrompt`): shown when someone without a seller profile picks
/// Fixed price or Auction while posting (or lists a piece later). Set up seller profile starts
/// the setup and keeps the draft; the second line switches to Not for sale ([secondaryLabel]
/// changes it where that makes no sense, e.g. "Not now" when listing a piece later).
Future<SellerPromptChoice?> showSellerPrompt(
  BuildContext context, {
  String secondaryLabel = 'Post it as not for sale instead',
}) {
  return showStudioSheet<SellerPromptChoice>(
    context: context,
    builder: (sheetContext) {
      final c = sheetContext.studio;
      return StudioSheet(
        horizontalPadding: StudioSpace.marginForm,
        gap: 0,
        children: [
          const SizedBox(height: 15),
          Text('Turn on selling first', style: StudioType.title22(color: c.textPrimary)),
          const SizedBox(height: 5),
          Text(
            'To sell or auction work, you need a seller profile. It takes about 5 minutes and your '
            'draft stays saved.',
            style: StudioType.sans(15, height: 1.5, color: c.textSecondary),
          ),
          const SizedBox(height: 15),
          StudioButton(
            label: 'Set up seller profile',
            height: 54,
            onPressed: () => Navigator.pop(sheetContext, SellerPromptChoice.setUp),
          ),
          const SizedBox(height: 6),
          StudioButton(
            label: secondaryLabel,
            variant: StudioButtonVariant.text,
            height: 44,
            onPressed: () => Navigator.pop(sheetContext, SellerPromptChoice.notForSale),
          ),
          const SizedBox(height: 16),
        ],
      );
    },
  );
}

enum _Step { intro, stripe, studio, done }

/// Seller setup (Flow 11, `HandoffSeller`): intro, Stripe, your studio, done. One page that steps
/// through them; it pops true once the person can sell.
///
/// - `SellerIntro`: what a seller profile unlocks, Stripe and the studio, "Selling fees apply.
///   See seller terms", Get started (turns the seller profile on).
/// - `SellerStripe`: Continue to Stripe opens Stripe Connect Express (identity, bank, tax; Stripe
///   hosts it); coming back to the app checks again. Finish later leaves it unfinished; Settings
///   then shows "Seller profile: setup not finished" with Continue.
/// - `SellerStudio`: "Stripe verified" (or what Stripe still needs and Back to Stripe), then the
///   studio. Only the city can be saved today (it is the profile's public place); the private
///   street, ZIP and pickup notes for the shipper need the server (BACKEND_CHANGES B31).
/// - `SellerDone`: a black circle with a white check, "You can sell now", then Back to your draft
///   (from posting; [returnLabel]) or List a piece, and Go to your profile.
class SellerSetupPage extends StatefulWidget {
  const SellerSetupPage({super.key, this.returnLabel, this.startAtStripe = false});

  /// Opened from something unfinished ("Back to your draft"): the done screen's button says
  /// this and goes back there. Null shows List a piece.
  final String? returnLabel;

  /// Settings' "setup not finished" Continue: the seller profile is already on.
  final bool startAtStripe;

  /// True while the flow is open: a Stripe return link then just lets it check again rather
  /// than opening the payout page on top.
  static bool active = false;

  /// Runs the flow; true when the person can now sell.
  static Future<bool> start(BuildContext context, {String? returnLabel, bool startAtStripe = false}) async {
    final done = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SellerSetupPage(returnLabel: returnLabel, startAtStripe: startAtStripe),
      ),
    );
    return done == true;
  }

  /// Turn on selling first (`SellerPrompt`), then the setup. True when the seller profile is on
  /// afterwards; false when they chose [secondaryLabel] or closed it.
  static Future<bool> prompt(
    BuildContext context, {
    String secondaryLabel = 'Post it as not for sale instead',
    String returnLabel = 'Back to your draft',
  }) async {
    final choice = await showSellerPrompt(context, secondaryLabel: secondaryLabel);
    if (choice != SellerPromptChoice.setUp || !context.mounted) return false;
    await start(context, returnLabel: returnLabel);
    return AuthSession.instance.sellerEnabled;
  }

  /// Settings' Continue and Stripe's return link: back into the setup at Stripe, unless it is
  /// already open (that one checks again when the app comes back).
  static Future<bool> resume(BuildContext context) async {
    if (active) return false;
    return start(context, startAtStripe: true);
  }

  @override
  State<SellerSetupPage> createState() => _SellerSetupPageState();
}

class _SellerSetupPageState extends State<SellerSetupPage> with WidgetsBindingObserver {
  late _Step _step = widget.startAtStripe ? _Step.stripe : _Step.intro;
  PayoutStatus? _status;
  bool _busy = false;
  bool _sentToStripe = false;
  PostLocationOption? _city;
  final _cityController = TextEditingController();

  String get _cityLabel => _cityController.text;

  late final TapGestureRecognizer _terms = TapGestureRecognizer()
    ..onTap = () => Navigator.of(context).pushNamed('/terms');

  @override
  void initState() {
    super.initState();
    SellerSetupPage.active = true;
    WidgetsBinding.instance.addObserver(this);
    _loadCity();
    // Picking up an unfinished setup: Stripe may be done already.
    if (widget.startAtStripe) _afterStripe();
  }

  @override
  void dispose() {
    SellerSetupPage.active = false;
    WidgetsBinding.instance.removeObserver(this);
    _terms.dispose();
    _cityController.dispose();
    super.dispose();
  }

  /// Back from Stripe: ask again and move on when it is done.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _sentToStripe && _step == _Step.stripe) {
      _afterStripe();
    }
  }

  Future<void> _loadCity() async {
    try {
      final me = await UserService.instance.getMeCached();
      if (mounted && _cityLabel.isEmpty) setState(() => _cityController.text = me.location ?? '');
    } catch (_) {
      // The field starts empty.
    }
  }

  Future<PayoutStatus?> _fetchStatus() async {
    try {
      final status = await PayoutService.instance.getStatus();
      if (mounted) setState(() => _status = status);
      return status;
    } catch (_) {
      return null;
    }
  }

  Future<void> _getStarted() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (!AuthSession.instance.sellerEnabled) {
        // The city is asked in the studio step; until then the profile's own place stands.
        await UserService.instance.enableSeller(location: _cityLabel, useProfileLocation: true);
      }
      final status = await _fetchStatus();
      if (!mounted) return;
      setState(() => _step = status?.canListForSale == true ? _Step.studio : _Step.stripe);
    } on ApiException catch (e) {
      if (mounted) showStudioToast(context, e.message, icon: null);
    } catch (_) {
      if (mounted) showStudioToast(context, 'Could not turn on your seller profile. Try again.', icon: null);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _continueToStripe() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final url = await PayoutService.instance.startOnboarding();
      _sentToStripe = true;
      final opened = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!opened && mounted) showStudioToast(context, 'Could not open Stripe.', icon: null);
    } on ApiException catch (e) {
      if (mounted) showStudioToast(context, e.message, icon: null);
    } catch (_) {
      if (mounted) showStudioToast(context, 'Could not open Stripe. Try again.', icon: null);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Stripe sent them back: the studio step shows whether it is verified or what is missing.
  Future<void> _afterStripe() async {
    final status = await _fetchStatus();
    if (!mounted || status == null) return;
    if (status.onboarded || status.canListForSale) {
      setState(() => _step = _Step.studio);
    }
  }

  void _pickCity() {
    ChooseLocationSheet.show(
      context,
      subtitle: 'Where your studio is. Buyers only ever see your city.',
      footnote: null,
      onLocationSelected: (place) => setState(() {
        _city = place;
        _cityController.text = place.displayName;
      }),
    );
  }

  Future<void> _finishSetup() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final city = _city;
      if (city != null) {
        await UserService.instance.updateMe(location: city.displayName, latitude: city.lat, longitude: city.lng);
      }
      if (mounted) setState(() => _step = _Step.done);
    } on ApiException catch (e) {
      if (mounted) showStudioToast(context, e.message, icon: null);
    } catch (_) {
      if (mounted) showStudioToast(context, 'Could not save your studio. Try again.', icon: null);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _back() {
    switch (_step) {
      case _Step.intro:
      case _Step.done:
        Navigator.of(context).pop(_step == _Step.done);
      case _Step.stripe:
        if (widget.startAtStripe) {
          Navigator.of(context).pop(false);
        } else {
          setState(() => _step = _Step.intro);
        }
      case _Step.studio:
        setState(() => _step = _Step.stripe);
    }
  }

  void _listAPiece() {
    final navigator = Navigator.of(context);
    navigator.pop(true);
    navigator.pushNamed('/post');
  }

  void _goToProfile() {
    Navigator.of(context).pop(true);
    MainNavService.instance.goProfile();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final safe = MediaQuery.viewPaddingOf(context).bottom;
    final progress = switch (_step) {
      _Step.stripe => 1,
      _Step.studio => 2,
      _ => null,
    };
    return PopScope(
      canPop: _step == _Step.intro,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: c.background,
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
                child: Row(
                  mainAxisAlignment: _step == _Step.done ? MainAxisAlignment.end : MainAxisAlignment.start,
                  children: [
                    IconButton(
                      onPressed: _back,
                      tooltip: _step == _Step.intro || _step == _Step.done ? 'Close' : 'Back',
                      style: IconButton.styleFrom(
                        fixedSize: const Size(44, 44),
                        minimumSize: const Size(44, 44),
                        padding: EdgeInsets.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: StudioIcon(
                        _step == _Step.intro || _step == _Step.done ? StudioIcons.close : StudioIcons.backBold,
                        size: 22,
                        color: c.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              if (progress != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                  child: StudioProgressSegments(current: progress, total: 3),
                ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(24, _step == _Step.intro ? 22 : 30, 24, 24),
                  child: switch (_step) {
                    _Step.intro => _intro(c),
                    _Step.stripe => _stripe(c),
                    _Step.studio => _studio(c),
                    _Step.done => _done(c),
                  },
                ),
              ),
              Padding(padding: EdgeInsets.fromLTRB(24, 8, 24, safe > 0 ? safe : 32), child: _bottom()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottom() {
    final ready = _status?.canListForSale == true;
    return switch (_step) {
      _Step.intro => StudioButton(label: 'Get started', height: 54, loading: _busy, onPressed: _getStarted),
      _Step.stripe => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StudioButton(label: 'Continue to Stripe', height: 54, loading: _busy, onPressed: _continueToStripe),
          const SizedBox(height: 4),
          StudioButton(
            label: 'Finish later',
            variant: StudioButtonVariant.text,
            height: 44,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
      _Step.studio =>
        ready
            ? StudioButton(
                label: 'Finish setup',
                height: 54,
                loading: _busy,
                onPressed: _cityLabel.trim().isEmpty ? null : _finishSetup,
              )
            : StudioButton(label: 'Back to Stripe', height: 54, loading: _busy, onPressed: _continueToStripe),
      _Step.done => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StudioButton(
            label: widget.returnLabel ?? 'List a piece',
            height: 54,
            onPressed: widget.returnLabel != null ? () => Navigator.of(context).pop(true) : _listAPiece,
          ),
          const SizedBox(height: 4),
          StudioButton(
            label: 'Go to your profile',
            variant: StudioButtonVariant.text,
            height: 44,
            onPressed: _goToProfile,
          ),
        ],
      ),
    };
  }

  // `SellerIntro`.
  Widget _intro(StudioColors c) {
    Widget row(String icon, String title, String line) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.surface, shape: BoxShape.circle),
            child: StudioIcon(icon, size: 18, color: c.textPrimary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: StudioType.sans(15, weight: StudioType.medium, color: c.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(line, style: StudioType.sans(13, height: 1.45, color: c.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('SELLER PROFILE', style: StudioType.mono(11, color: c.textTertiary).copyWith(letterSpacing: 0.5)),
        const SizedBox(height: 8),
        Text(
          'Sell your work on Studio 3',
          style: StudioType.sans(30, weight: StudioType.medium, letterSpacing: -0.6, height: 1.1, color: c.textPrimary),
        ),
        const SizedBox(height: 10),
        Text(
          'List pieces for sale or auction, host paid events, and see how your work is doing.',
          style: StudioType.sans(15, height: 1.5, color: c.textSecondary),
        ),
        const SizedBox(height: 14),
        row(
          StudioIcons.card,
          'Set up payouts with Stripe',
          'Studio 3 pays you through Stripe Connect. You will verify your identity and add a bank account on Stripe.',
        ),
        row(StudioIcons.location, 'Your studio', 'Where pieces are picked up for shipping. Only your city is shown.'),
        const SizedBox(height: 18),
        Text.rich(
          TextSpan(
            style: StudioType.sans(13, height: 1.5, color: c.textSecondary),
            children: [
              const TextSpan(text: 'Selling fees apply. '),
              TextSpan(
                text: 'See seller terms',
                recognizer: _terms,
                style: TextStyle(
                  color: c.textPrimary,
                  decoration: TextDecoration.underline,
                  decorationColor: c.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // `SellerStripe`.
  Widget _stripe(StudioColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Set up payouts with Stripe',
          style: StudioType.sans(26, weight: StudioType.medium, letterSpacing: -0.4, color: c.textPrimary),
        ),
        const SizedBox(height: 15),
        Text(
          "Studio 3 uses Stripe Connect to pay sellers. On Stripe you'll verify your identity and add a bank "
          'account, then come right back here.',
          style: StudioType.sans(15, height: 1.5, color: c.textSecondary),
        ),
        const SizedBox(height: 15),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(StudioRadius.button),
            border: Border.all(color: c.line),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StudioIcon(StudioIcons.lock, size: 18, color: c.textPrimary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Studio 3 never sees your full bank or ID details. Stripe stores them securely.',
                  style: StudioType.sans(13, height: 1.5, color: c.textPrimary),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // `SellerStudio`.
  Widget _studio(StudioColors c) {
    final status = _status;
    final ready = status?.canListForSale == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (ready)
          Row(
            children: [
              StudioIcon(StudioIcons.check, size: 14, color: c.positive),
              const SizedBox(width: 8),
              Text('Stripe verified', style: StudioType.label13(color: c.positive)),
            ],
          )
        else
          Text(
            status == null || status.requirementsDue.isEmpty
                ? 'Stripe needs a little more information.'
                : 'Stripe still needs: ${status.requirementsDue.map(_requirement).toSet().join(', ')}.',
            style: StudioType.label13(color: c.textPrimary),
          ),
        const SizedBox(height: 18),
        Text(
          'Your studio',
          style: StudioType.sans(26, weight: StudioType.medium, letterSpacing: -0.4, color: c.textPrimary),
        ),
        const SizedBox(height: 18),
        Text(
          'Where Convelio picks up pieces you sell. Buyers only ever see your city.',
          style: StudioType.sans(15, height: 1.5, color: c.textSecondary),
        ),
        const SizedBox(height: 18),
        StudioUnderlineField(
          label: 'City',
          controller: _cityController,
          hint: 'Choose your city',
          valueSize: 16,
          readOnly: true,
          onTap: _pickCity,
          trailing: StudioIcon(StudioIcons.chevronRight, size: 16, color: c.textTertiary),
        ),
      ],
    );
  }

  /// Stripe's requirement keys in plain words ("individual.verification.document" → "ID").
  static String _requirement(String key) {
    if (key.contains('external_account')) return 'a bank account';
    if (key.contains('verification') || key.contains('id_number') || key.contains('ssn')) return 'ID';
    if (key.contains('address')) return 'an address';
    if (key.contains('dob')) return 'date of birth';
    if (key.contains('tos')) return 'their terms';
    return 'details';
  }

  // `SellerDone`.
  Widget _done(StudioColors c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 90, 8, 0),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.textPrimary, shape: BoxShape.circle),
            child: StudioIcon(StudioIcons.check, size: 24, color: c.background),
          ),
          const SizedBox(height: 22),
          Text(
            'You can sell now',
            textAlign: TextAlign.center,
            style: StudioType.sans(28, weight: StudioType.medium, letterSpacing: -0.5, color: c.textPrimary),
          ),
          const SizedBox(height: 12),
          Text(
            'Your seller profile is on. Insights and Payouts are now on your profile and in Settings.',
            textAlign: TextAlign.center,
            style: StudioType.sans(15, height: 1.5, color: c.textSecondary),
          ),
        ],
      ),
    );
  }
}
