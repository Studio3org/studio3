import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_exception.dart';
import '../services/auth_service.dart';
import '../services/auth_session.dart';
import '../services/device_service.dart';
import '../services/payout_service.dart';
import '../models/user_profile.dart';
import '../services/theme_service.dart';
import '../services/user_service.dart';
import '../utils/app_version.dart';
import '../widgets/feed_skeleton.dart';
import '../widgets/loading/skeleton_primitives.dart';
import '../widgets/settings_tile.dart';
import '../widgets/studio/studio.dart';
import 'account_settings_page.dart';
import 'payment_shipping_page.dart';
import 'seller/seller_setup_flow.dart';
import 'seller_analytics_page.dart';
import 'selling_settings_page.dart';

/// Settings (`Settings`, Flow 12; `HandoffSettings`): opened from the gear on your own profile.
/// Back and "Settings"; Mono sections Account, Selling, Buying, App, Help; rows 16 with the value
/// in Graphite and a chevron. Sellers see Seller profile (On), Sales, Insights and Payouts
/// ("Finish setup" in red until Stripe can pay them); everyone else one Start selling row (seller
/// setup, Flow 11). Then Log out, Delete account in red, and the app version in Mono.
///
/// Rows the board doesn't draw (plan section 0.3): Series (Manage series) under Account, and
/// Appearance under App. Edit profile is the button on the profile; the visibility, follow
/// request, blocked, reports and privacy policy rows live on Privacy; email, password and "log
/// out of all devices" on Account.
class ProfileSettingsPage extends StatefulWidget {
  const ProfileSettingsPage({super.key, this.debugSeller, this.debugName, this.debugPayout});

  /// For tests: the seller state, the account name and the payout status, instead of loading.
  @visibleForTesting
  final bool? debugSeller;
  @visibleForTesting
  final String? debugName;
  @visibleForTesting
  final PayoutStatus? debugPayout;

  @override
  State<ProfileSettingsPage> createState() => _ProfileSettingsPageState();
}

class _ProfileSettingsPageState extends State<ProfileSettingsPage> {
  bool _sellerEnabled = false;
  PayoutStatus? _payoutStatus = PayoutService.instance.peekStatusCached();
  bool _loadingSeller = true;
  String? _name;
  SellerAnalytics? _analytics;

  @override
  void initState() {
    super.initState();
    final seller = widget.debugSeller;
    if (seller != null) {
      _sellerEnabled = seller;
      _name = widget.debugName;
      _payoutStatus = widget.debugPayout;
      _loadingSeller = false;
      return;
    }
    _name = AuthSession.instance.user?.name;
    _loadSellerStatus();
  }

  Future<void> _selectAppearance(String value) async {
    final previous = ThemeService.instance.mode;
    await ThemeService.instance.setMode(value == 'dark' ? ThemeMode.dark : ThemeMode.light);
    if (mounted) setState(() {});
    if (!AuthSession.instance.isLoggedIn) return;
    try {
      await UserService.instance.updateMe(themePreference: value);
    } catch (_) {
      await ThemeService.instance.setMode(previous);
      if (!mounted) return;
      setState(() {});
      showStudioToast(context, 'Could not save appearance');
    }
  }

  /// Appearance: Light or Dark in a select sheet (not on the board; plan section 0.3).
  Future<void> _pickAppearance() async {
    final dark = ThemeService.instance.isDark;
    final picked = await showStudioSheet<String>(
      context: context,
      builder: (sheetContext) {
        final c = sheetContext.studio;
        return StudioSheet(
          horizontalPadding: 24,
          gap: 0,
          children: [
            const SizedBox(height: 8),
            Text('Appearance', style: StudioType.title22(color: c.textPrimary)),
            const SizedBox(height: 12),
            StudioListRow(title: 'Light', selected: !dark, onTap: () => Navigator.pop(sheetContext, 'light')),
            StudioListRow(
              title: 'Dark',
              selected: dark,
              divider: false,
              onTap: () => Navigator.pop(sheetContext, 'dark'),
            ),
          ],
        );
      },
    );
    if (picked == null || picked == (dark ? 'dark' : 'light')) return;
    await _selectAppearance(picked);
  }

  Future<void> _loadSellerStatus() async {
    try {
      final results = await Future.wait([
        UserService.instance.getSellerStatus(),
        UserService.instance.getMe(),
      ]);
      final status = results[0] as SellerStatus;
      final profile = results[1] as UserProfile;
      if (!mounted) return;
      setState(() {
        _sellerEnabled = status.enabled;
        if (profile.name.trim().isNotEmpty) _name = profile.name;
        _loadingSeller = false;
      });
      if (status.enabled) {
        _loadAnalytics();
        _loadPayoutStatus();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sellerEnabled = AuthSession.instance.sellerEnabled;
        _loadingSeller = false;
      });
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final password = await showStudioSheet<String>(
      context: context,
      builder: (_) => const _DeleteAccountSheet(),
    );
    if (password == null || password.isEmpty || !mounted) return;
    try {
      await DeviceService.instance.unregisterCurrentDevice();
      await AuthService.instance.deleteAccount(password);
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    } on ApiException catch (e) {
      // e.g. wrong password, or an active listing / in-progress order that has to be
      // resolved first — the server's message says which.
      if (mounted) showStudioToast(context, e.message, icon: null);
    } catch (_) {
      if (mounted) showStudioToast(context, 'Could not delete your account. Please try again.', icon: null);
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showStudioConfirm(
      context,
      title: 'Log out?',
      message: "You'll need to log back in to use Studio 3.",
      confirmLabel: 'Log out',
    );
    if (!confirmed || !mounted) return;
    await DeviceService.instance.unregisterCurrentDevice();
    await AuthService.instance.logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  Future<void> _loadAnalytics() async {
    try {
      final analytics = await UserService.instance.getSellerAnalytics();
      if (!mounted) return;
      setState(() => _analytics = analytics);
    } catch (_) {
      // Seller mode still works if analytics fails to load.
    }
  }

  /// Start selling: the seller setup (`SellerIntro`, Flow 11).
  Future<void> _startSelling() async {
    await SellerSetupPage.start(context);
    if (!mounted) return;
    final on = AuthSession.instance.sellerEnabled;
    setState(() => _sellerEnabled = on);
    if (on) {
      _loadAnalytics();
      _loadPayoutStatus(refresh: true);
    }
  }

  /// Seller profile: the Selling page (`SettingsSelling`), where it can be turned off.
  Future<void> _openSelling() async {
    final turnedOff = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(builder: (_) => const SellingSettingsPage()),
    );
    if (turnedOff != true || !mounted) return;
    await PayoutService.instance.invalidateStatus();
    if (!mounted) return;
    setState(() {
      _sellerEnabled = false;
      _payoutStatus = null;
    });
  }

  Future<void> _loadPayoutStatus({bool refresh = false}) async {
    if (!_sellerEnabled) return;
    try {
      final status = await PayoutService.instance.getStatusCached(
        forceRefresh: refresh,
        onBackgroundUpdate: (fresh) {
          if (mounted) setState(() => _payoutStatus = fresh);
        },
      );
      if (mounted) setState(() => _payoutStatus = status);
    } catch (_) {
      // The row keeps its placeholder; the seller can still use the rest of settings.
    }
  }

  Future<void> _openPayoutDashboard() async {
    try {
      final url = await PayoutService.instance.dashboardUrl();
      final launched = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!launched && mounted) showStudioToast(context, 'Could not open the browser.', icon: null);
    } on ApiException catch (e) {
      if (mounted) showStudioToast(context, e.message, icon: null);
    } catch (_) {
      if (mounted) showStudioToast(context, 'Could not open payouts.', icon: null);
    }
  }

  /// Help: an email to support (there is no help centre yet; plan section 0.3).
  Future<void> _openHelp() async {
    try {
      final launched = await launchUrl(Uri.parse('mailto:support@studio-3.co?subject=Help'));
      if (!launched && mounted) showStudioToast(context, 'Email support@studio-3.co', icon: null);
    } catch (_) {
      if (mounted) showStudioToast(context, 'Email support@studio-3.co', icon: null);
    }
  }

  void _openInsights() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => SellerAnalyticsPage(
          savesCount: _analytics?.savesCount,
          likesCount: _analytics?.likesCount,
          inquiriesCount: _analytics?.inquiriesCount,
          salesCount: _analytics?.salesCount,
        ),
      ),
    );
  }

  Future<void> _openAccount() async {
    await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const AccountSettingsPage()));
    if (!mounted) return;
    final name = AuthSession.instance.user?.name;
    if (name != null && name.trim().isNotEmpty) setState(() => _name = name);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final dark = ThemeService.instance.isDark;
    return Scaffold(
      backgroundColor: c.background,
      appBar: StudioTopBar(context: context, title: 'Settings', onBack: () => Navigator.pop(context, true)),
      body: _loadingSeller
          ? const SettingsListSkeleton()
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
              children: [
                const SettingsSectionLabel('Account', top: 26),
                SettingsRow(label: 'Account', value: _name, onTap: _openAccount),
                SettingsRow(label: 'Series', onTap: () => Navigator.pushNamed(context, '/manage-series')),

                const SettingsSectionLabel('Selling', top: 26),
                if (_sellerEnabled) ...[
                  SettingsRow(label: 'Seller profile', value: 'On', onTap: _openSelling),
                  SettingsRow(label: 'Sales', onTap: () => Navigator.pushNamed(context, '/sales')),
                  SettingsRow(label: 'Insights', onTap: _openInsights),
                  PayoutSettingsTile(
                    status: _payoutStatus,
                    onStartSetup: () async {
                      await SellerSetupPage.resume(context);
                      if (!mounted) return;
                      _loadPayoutStatus(refresh: true);
                    },
                    onOpenDashboard: _openPayoutDashboard,
                  ),
                ] else
                  SettingsRow(label: 'Start selling', onTap: _startSelling),

                const SettingsSectionLabel('Buying', top: 26),
                SettingsRow(
                  label: 'Purchases',
                  subtitle: 'Orders, auction wins and tickets',
                  onTap: () => Navigator.pushNamed(context, '/orders'),
                ),
                SettingsRow(
                  label: 'Payment and shipping',
                  onTap: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(builder: (_) => const PaymentShippingPage()),
                  ),
                ),

                const SettingsSectionLabel('App', top: 26),
                SettingsRow(
                  label: 'Notifications',
                  onTap: () => Navigator.pushNamed(context, '/notification-preferences'),
                ),
                SettingsRow(label: 'Privacy', onTap: () => Navigator.pushNamed(context, '/privacy-settings')),
                SettingsRow(label: 'Appearance', value: dark ? 'Dark' : 'Light', onTap: _pickAppearance),

                const SettingsSectionLabel('Help', top: 26),
                SettingsRow(label: 'Help', onTap: _openHelp),
                SettingsRow(label: 'Terms and policies', onTap: () => Navigator.pushNamed(context, '/terms')),

                const SizedBox(height: 28),
                SettingsRow(label: 'Log out', chevron: false, onTap: _confirmLogout),
                SettingsRow(
                  label: 'Delete account',
                  labelColor: c.alert,
                  chevron: false,
                  onTap: _confirmDeleteAccount,
                ),
                const SizedBox(height: 18),
                Text(
                  'Studio 3 · $kAppVersion',
                  textAlign: TextAlign.center,
                  style: StudioType.mono(11, color: c.textTertiary),
                ),
              ],
            ),
    );
  }
}

/// The Payouts row (`Settings`): a placeholder while the status loads (inert: nothing to route
/// on yet); "Finish setup" in red while Stripe still needs details (it goes back into seller
/// setup); otherwise Payouts, which opens the Stripe dashboard.
class PayoutSettingsTile extends StatelessWidget {
  const PayoutSettingsTile({
    super.key,
    required this.status,
    required this.onStartSetup,
    required this.onOpenDashboard,
  });

  final PayoutStatus? status;
  final VoidCallback onStartSetup;
  final VoidCallback onOpenDashboard;

  @override
  Widget build(BuildContext context) {
    final current = status;
    if (current == null) {
      return const SettingsRow(
        label: 'Payouts',
        valueWidget: SkeletonShimmer(child: SkeletonBox(width: 56, height: 12, radius: 4)),
      );
    }
    if (current.needsAction) {
      return SettingsRow(
        label: 'Payouts',
        valueWidget: Text('Finish setup', style: StudioType.body14(color: context.studio.alert)),
        onTap: onStartSetup,
      );
    }
    return SettingsRow(label: 'Payouts', onTap: onOpenDashboard);
  }
}

/// "Delete your account?", what it removes, the password (an underline field), then Delete
/// account (on once a password is typed) and Cancel. Pops the password, or null. Until the
/// delete account page (`SettingsDelete`) is built.
class _DeleteAccountSheet extends StatefulWidget {
  const _DeleteAccountSheet();

  @override
  State<_DeleteAccountSheet> createState() => _DeleteAccountSheetState();
}

class _DeleteAccountSheetState extends State<_DeleteAccountSheet> {
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return StudioSheet(
      horizontalPadding: StudioSpace.marginForm,
      gap: 14,
      children: [
        Text('Delete your account?', style: StudioType.title22(color: c.textPrimary)),
        Text(
          'This permanently deletes your account and your data — profile, pieces, scenes, '
          'and listings. This cannot be undone.',
          style: StudioType.body14(color: c.textSecondary),
        ),
        StudioUnderlineField(
          label: 'Confirm your password',
          controller: _password,
          obscureText: true,
          autofocus: true,
          autofillHints: const [AutofillHints.password],
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 4),
        StudioButton(
          label: 'Delete account',
          onPressed: _password.text.isEmpty ? null : () => Navigator.pop(context, _password.text),
        ),
        StudioButton(
          label: 'Cancel',
          variant: StudioButtonVariant.text,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }
}
