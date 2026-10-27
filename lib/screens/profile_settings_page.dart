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
import '../utils/profile_navigation.dart';
import '../widgets/feed_skeleton.dart';
import '../widgets/loading/skeleton_primitives.dart';
import '../widgets/settings_tile.dart';
import '../widgets/studio/studio.dart';
import '../widgets/studio_loading.dart';
import 'inbox_page.dart';
import 'profile/widgets/profile_seller_insights.dart';
import 'seller/seller_setup_flow.dart';
import 'seller_analytics_page.dart';

class ProfileSettingsPage extends StatefulWidget {
  const ProfileSettingsPage({super.key});

  @override
  State<ProfileSettingsPage> createState() => _ProfileSettingsPageState();
}

class _ProfileSettingsPageState extends State<ProfileSettingsPage> {
  bool _sellerEnabled = false;
  PayoutStatus? _payoutStatus = PayoutService.instance.peekStatusCached();
  bool _loadingSeller = true;
  bool _togglingSeller = false;
  String? _profileLocation;
  SellerAnalytics? _analytics;

  @override
  void initState() {
    super.initState();
    _loadSellerStatus();
  }

  Future<void> _selectAppearance(String value) async {
    final previous = ThemeService.instance.mode;
    await ThemeService.instance.setMode(value == 'dark' ? ThemeMode.dark : ThemeMode.light);
    if (!AuthSession.instance.isLoggedIn) return;
    try {
      await UserService.instance.updateMe(themePreference: value);
    } catch (_) {
      await ThemeService.instance.setMode(previous);
      if (!mounted) return;
      showStudioToast(context, 'Could not save appearance');
    }
  }

  Future<void> _loadSellerStatus() async {
    try {
      final results = await Future.wait([UserService.instance.getSellerStatus(), UserService.instance.getMe()]);
      final status = results[0] as SellerStatus;
      final profile = results[1] as UserProfile;
      if (!mounted) return;
      setState(() {
        _sellerEnabled = status.enabled;
        _profileLocation = profile.location;
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
    final password = await showStudioSheet<String>(context: context, builder: (_) => const _DeleteAccountSheet());
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

  Future<void> _confirmLogout({
    required String title,
    required String message,
    required Future<void> Function() onConfirmed,
  }) async {
    final confirmed = await showStudioConfirm(context, title: title, message: message, confirmLabel: 'Log out');
    if (!confirmed || !mounted) return;
    await onConfirmed();
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

  Future<void> _onSellerToggle(bool value) async {
    if (_togglingSeller) return;
    if (value) {
      // Turning it on is seller setup (`SellerIntro` "Also opened from Settings").
      await SellerSetupPage.start(context);
      if (!mounted) return;
      final on = AuthSession.instance.sellerEnabled;
      setState(() => _sellerEnabled = on);
      if (on) {
        _loadAnalytics();
        _loadPayoutStatus(refresh: true);
      }
      return;
    }
    setState(() => _togglingSeller = true);
    final result = await toggleSellerMode(context: context, enable: value, profileLocation: _profileLocation);
    if (!mounted) return;
    setState(() {
      _togglingSeller = false;
      if (result != null) _sellerEnabled = result;
    });
    if (result == true) {
      _loadAnalytics();
      _loadPayoutStatus();
    } else if (result == false) {
      await PayoutService.instance.invalidateStatus();
      if (!mounted) return;
      setState(() => _payoutStatus = null);
    }
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

  Future<void> _openExternalLink(String url, {required String errorMessage}) async {
    try {
      final launched = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!launched && mounted) showStudioToast(context, 'Could not open the browser.', icon: null);
    } catch (_) {
      if (mounted) showStudioToast(context, errorMessage, icon: null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.studio;
    final dark = ThemeService.instance.isDark;
    return StudioLoadingGate(
      loading: _togglingSeller,
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: StudioTopBar(context: context, title: 'Settings', onBack: () => Navigator.pop(context, true)),
        body: _loadingSeller
            ? const SettingsListSkeleton()
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                children: [
                  const SettingsSectionLabel('Appearance', top: 12),
                  StudioSelectRow(
                    title: 'Light',
                    selected: !dark,
                    titleSize: 17,
                    titleLetterSpacing: -0.2,
                    verticalPadding: 16,
                    ruleInset: 14,
                    onTap: dark ? () => _selectAppearance('light') : null,
                  ),
                  StudioSelectRow(
                    title: 'Dark',
                    selected: dark,
                    divider: false,
                    titleSize: 17,
                    titleLetterSpacing: -0.2,
                    verticalPadding: 16,
                    ruleInset: 14,
                    onTap: dark ? null : () => _selectAppearance('dark'),
                  ),

                  const SettingsSectionLabel('Seller'),
                  SettingsToggleTile(label: 'Seller account', value: _sellerEnabled, onChanged: _onSellerToggle),
                  if (_sellerEnabled) ...[
                    SettingsTile(
                      label: 'Seller analytics',
                      onTap: () {
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
                      },
                    ),
                    SettingsTile(label: 'My sales', onTap: () => Navigator.pushNamed(context, '/sales')),
                    PayoutSettingsTile(
                      status: _payoutStatus,
                      onStartSetup: () async {
                        await SellerSetupPage.resume(context);
                        if (!mounted) return;
                        _loadPayoutStatus(refresh: true);
                      },
                      onOpenDashboard: _openPayoutDashboard,
                    ),
                  ],
                  SettingsTile(label: 'My orders', onTap: () => Navigator.pushNamed(context, '/orders')),

                  const SettingsSectionLabel('Account'),
                  SettingsTile(label: 'Edit profile', onTap: () => Navigator.pushNamed(context, '/edit-profile')),
                  SettingsTile(
                    label: 'Manage series',
                    onTap: () async {
                      await Navigator.pushNamed(context, '/manage-series');
                      if (!context.mounted) return;
                      // Parent profile reloads when settings is popped; no extra action here.
                    },
                  ),
                  SettingsTile(label: 'Shipping addresses', onTap: () => Navigator.pushNamed(context, '/addresses')),
                  SettingsTile(label: 'See profile as viewer', onTap: () => openOwnProfileAsViewer(context)),

                  const SettingsSectionLabel('Privacy'),
                  SettingsTile(
                    label: 'Profile visibility & messaging',
                    onTap: () => Navigator.pushNamed(context, '/privacy-settings'),
                  ),
                  SettingsTile(
                    label: 'Follow requests',
                    onTap: () => Navigator.pushNamed(context, '/inbox', arguments: InboxTab.requests),
                  ),
                  SettingsTile(label: 'Blocked accounts', onTap: () => Navigator.pushNamed(context, '/blocked-users')),
                  SettingsTile(label: 'Terms of Use (EULA)', onTap: () => Navigator.pushNamed(context, '/terms')),
                  SettingsTile(
                    label: 'Privacy policy',
                    onTap: () => _openExternalLink(
                      'https://studiosthree.com/privacy',
                      errorMessage: 'Could not open the privacy policy.',
                    ),
                  ),
                  SettingsTile(label: 'My reports', onTap: () => Navigator.pushNamed(context, '/my-reports')),

                  const SettingsSectionLabel('Login & security'),
                  SettingsTile(
                    label: 'Password & security',
                    onTap: () => Navigator.pushNamed(context, '/change-password'),
                  ),
                  SettingsTile(label: 'Change email', onTap: () => Navigator.pushNamed(context, '/change-email')),
                  SettingsTile(
                    label: 'Log out of all devices',
                    onTap: () => _confirmLogout(
                      title: 'Log out of all devices?',
                      message: "You'll be signed out everywhere you're currently logged in.",
                      onConfirmed: () async {
                        await DeviceService.instance.unregisterCurrentDevice();
                        await AuthService.instance.logoutAllDevices();
                      },
                    ),
                  ),

                  const SettingsSectionLabel('Notifications'),
                  SettingsTile(
                    label: 'Notifications',
                    onTap: () => Navigator.pushNamed(context, '/inbox', arguments: InboxTab.notifications),
                  ),
                  SettingsTile(
                    label: 'Notification preferences',
                    onTap: () => Navigator.pushNamed(context, '/notification-preferences'),
                  ),

                  const SizedBox(height: 28),
                  SettingsTile(
                    label: 'Log out',
                    chevron: false,
                    onTap: () => _confirmLogout(
                      title: 'Log out?',
                      message: "You'll need to log back in to use Studio 3.",
                      onConfirmed: () async {
                        await DeviceService.instance.unregisterCurrentDevice();
                        await AuthService.instance.logout();
                      },
                    ),
                  ),
                  SettingsTile(label: 'Delete account', chevron: false, onTap: _confirmDeleteAccount),
                ],
              ),
      ),
    );
  }
}

/// The Payouts row (restored from before commit 76f4ef9): a placeholder while the status
/// loads, "Seller profile: setup not finished" with Continue while Stripe still needs details
/// (`SellerStripe` note; Continue goes back into seller setup), otherwise Payouts, which opens
/// the Stripe dashboard.
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
      return const SettingsTile(
        label: 'Payouts',
        trailing: SkeletonShimmer(child: SkeletonBox(width: 56, height: 12, radius: 4)),
      );
    }
    if (current.needsAction) {
      return SettingsTile(
        label: 'Seller profile: setup not finished',
        trailing: Text(
          'Continue',
          style: StudioType.label13(weight: StudioType.medium, color: context.studio.textPrimary),
        ),
        onTap: onStartSetup,
      );
    }
    return SettingsTile(label: 'Payouts', onTap: onOpenDashboard);
  }
}

/// "Delete your account?", what it removes, the password (an underline field), then Delete
/// account (on once a password is typed) and Cancel. Pops the password, or null.
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
        StudioButton(label: 'Cancel', variant: StudioButtonVariant.text, onPressed: () => Navigator.pop(context)),
      ],
    );
  }
}
