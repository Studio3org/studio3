import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/auth_service.dart';
import '../services/auth_session.dart';
import '../services/device_service.dart';
import '../models/user_profile.dart';
import '../services/user_service.dart';
import '../theme/home_feed_tokens.dart';
import '../utils/profile_navigation.dart';
import '../widgets/feed_skeleton.dart';
import '../widgets/settings_tile.dart';
import '../widgets/studio_loading.dart';
import 'inbox_page.dart';
import 'profile/widgets/profile_seller_insights.dart';
import 'seller_analytics_page.dart';

class ProfileSettingsPage extends StatefulWidget {
  const ProfileSettingsPage({super.key});

  @override
  State<ProfileSettingsPage> createState() => _ProfileSettingsPageState();
}

class _ProfileSettingsPageState extends State<ProfileSettingsPage> {
  bool _sellerEnabled = false;
  bool _loadingSeller = true;
  bool _togglingSeller = false;
  String? _profileLocation;
  SellerAnalytics? _analytics;

  @override
  void initState() {
    super.initState();
    _loadSellerStatus();
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
        _profileLocation = profile.location;
        _loadingSeller = false;
      });
      if (status.enabled) _loadAnalytics();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sellerEnabled = AuthSession.instance.sellerEnabled;
        _loadingSeller = false;
      });
    }
  }

  Future<void> _confirmLogout({
    required String title,
    required String message,
    required Future<void> Function() onConfirmed,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Log out',
              style: TextStyle(color: Color(0xFFE05252)),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
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
    setState(() => _togglingSeller = true);
    final result = await toggleSellerMode(
      context: context,
      enable: value,
      profileLocation: _profileLocation,
    );
    if (!mounted) return;
    setState(() {
      _togglingSeller = false;
      if (result != null) _sellerEnabled = result;
    });
    if (result == true) _loadAnalytics();
  }

  @override
  Widget build(BuildContext context) {
    return StudioLoadingGate(
      loading: _togglingSeller,
      child: Scaffold(
        backgroundColor: HomeFeedTokens.background,
        appBar: AppBar(
          backgroundColor: HomeFeedTokens.background,
          elevation: 0,
          centerTitle: true,
          title: Text(
            'Settings',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: HomeFeedTokens.textPrimary,
            ),
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                color: HomeFeedTokens.textPrimary, size: 20),
            onPressed: () => Navigator.pop(context, true),
          ),
        ),
        body: _loadingSeller
            ? const SettingsListSkeleton()
            : ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const _SectionHeader('Seller'),
            SettingsToggleTile(
              icon: Icons.storefront_outlined,
              label: 'Seller account',
              value: _sellerEnabled,
              onChanged: _onSellerToggle,
            ),
            if (_sellerEnabled) ...[
              SettingsTile(
                icon: Icons.bar_chart_rounded,
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
              SettingsTile(
                icon: Icons.point_of_sale_outlined,
                label: 'My sales',
                onTap: () => Navigator.pushNamed(context, '/sales'),
              ),
            ],
            SettingsTile(
              icon: Icons.receipt_long_outlined,
              label: 'My orders',
              onTap: () => Navigator.pushNamed(context, '/orders'),
            ),

            const _SectionHeader('Account'),
            SettingsTile(
              icon: Icons.person_outline_rounded,
              label: 'Edit profile',
              onTap: () => Navigator.pushNamed(context, '/edit-profile'),
            ),
            SettingsTile(
              icon: Icons.collections_bookmark_outlined,
              label: 'Manage series',
              onTap: () async {
                await Navigator.pushNamed(context, '/manage-series');
                if (!context.mounted) return;
                // Parent profile reloads when settings is popped; no extra action here.
              },
            ),
            SettingsTile(
              icon: Icons.local_shipping_outlined,
              label: 'Shipping addresses',
              onTap: () => Navigator.pushNamed(context, '/addresses'),
            ),
            SettingsTile(
              icon: Icons.visibility_outlined,
              label: 'See profile as viewer',
              onTap: () => openOwnProfileAsViewer(context),
            ),

            const _SectionHeader('Privacy'),
            SettingsTile(
              icon: Icons.shield_outlined,
              label: 'Profile visibility & messaging',
              onTap: () => Navigator.pushNamed(context, '/privacy-settings'),
            ),
            SettingsTile(
              icon: Icons.person_add_alt_outlined,
              label: 'Follow requests',
              onTap: () => Navigator.pushNamed(
                context,
                '/inbox',
                arguments: InboxTab.requests,
              ),
            ),
            SettingsTile(
              icon: Icons.block_outlined,
              label: 'Blocked accounts',
              onTap: () => Navigator.pushNamed(context, '/blocked-users'),
            ),

            const _SectionHeader('Login & security'),
            SettingsTile(
              icon: Icons.lock_outline_rounded,
              label: 'Password & security',
              onTap: () => Navigator.pushNamed(context, '/change-password'),
            ),
            SettingsTile(
              icon: Icons.email_outlined,
              label: 'Change email',
              onTap: () => Navigator.pushNamed(context, '/change-email'),
            ),
            SettingsTile(
              icon: Icons.devices_other_outlined,
              label: 'Log out of all devices',
              onTap: () => _confirmLogout(
                title: 'Log out of all devices?',
                message:
                    "You'll be signed out everywhere you're currently logged in.",
                onConfirmed: () async {
                  await DeviceService.instance.unregisterCurrentDevice();
                  await AuthService.instance.logoutAllDevices();
                },
              ),
            ),

            const _SectionHeader('Notifications'),
            SettingsTile(
              icon: Icons.notifications_outlined,
              label: 'Notifications',
              onTap: () => Navigator.pushNamed(
                context,
                '/inbox',
                arguments: InboxTab.notifications,
              ),
            ),
            SettingsTile(
              icon: Icons.tune_rounded,
              label: 'Notification preferences',
              onTap: () => Navigator.pushNamed(context, '/notification-preferences'),
            ),

            const SizedBox(height: 16),
            SettingsTile(
              icon: Icons.logout_rounded,
              label: 'Log out',
              destructive: true,
              onTap: () => _confirmLogout(
                title: 'Log out?',
                message: "You'll need to log back in to use Studio 3.",
                onConfirmed: () async {
                  await DeviceService.instance.unregisterCurrentDevice();
                  await AuthService.instance.logout();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Instagram-style bold section label grouping related settings rows.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
          color: HomeFeedTokens.textPrimary.withValues(alpha: 0.45),
        ),
      ),
    );
  }
}
