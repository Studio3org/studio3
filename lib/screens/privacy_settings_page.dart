import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_exception.dart';
import '../services/user_service.dart';
import '../utils/profile_navigation.dart';
import 'inbox_page.dart';
import '../widgets/settings_tile.dart';
import '../widgets/studio/studio.dart';
import '../widgets/labeled_dropdown.dart';
import '../widgets/studio_loading.dart';

const _visibilityOptions = [('public', 'Public'), ('private', 'Private')];
const _messagePermissionOptions = [
  ('everyone', 'Everyone'),
  ('following', 'People I follow'),
  ('no_one', 'No one'),
];

class PrivacySettingsPage extends StatefulWidget {
  const PrivacySettingsPage({super.key});

  @override
  State<PrivacySettingsPage> createState() => _PrivacySettingsPageState();
}

class _PrivacySettingsPageState extends State<PrivacySettingsPage> {
  String _profileVisibility = 'public';
  String _messagePermission = 'everyone';
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final profile = await UserService.instance.getMe();
      if (!mounted) return;
      setState(() {
        _profileVisibility = profile.profileVisibility;
        _messagePermission = profile.messagePermission;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _updateVisibility(String value) async {
    final previous = _profileVisibility;
    setState(() => _profileVisibility = value);
    try {
      setState(() => _saving = true);
      await UserService.instance.updateMe(profileVisibility: value);
    } catch (e) {
      if (!mounted) return;
      setState(() => _profileVisibility = previous);
      _showError(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _updateMessagePermission(String value) async {
    final previous = _messagePermission;
    setState(() => _messagePermission = value);
    try {
      setState(() => _saving = true);
      await UserService.instance.updateMe(messagePermission: value);
    } catch (e) {
      if (!mounted) return;
      setState(() => _messagePermission = previous);
      _showError(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openPrivacyPolicy() async {
    try {
      final launched = await launchUrl(
        Uri.parse('https://studiosthree.com/privacy'),
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) showStudioToast(context, 'Could not open the browser.', icon: null);
    } catch (_) {
      if (mounted) showStudioToast(context, 'Could not open the privacy policy.', icon: null);
    }
  }

  void _showError(Object e) {
    showStudioToast(context, e is ApiException ? e.message : 'Could not save that.', icon: null);
  }

  @override
  Widget build(BuildContext context) {
    return StudioLoadingGate(
      loading: _loading,
      child: Scaffold(
        backgroundColor: context.studio.background,
        appBar: StudioTopBar(context: context, title: 'Privacy'),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(StudioSpace.marginForm, 16, StudioSpace.marginForm, 40),
          children: [
            LabeledDropdown(
              label: 'Profile visibility',
              value: _profileVisibility,
              options: _visibilityOptions,
              onChanged: _saving ? (_) {} : _updateVisibility,
            ),
            const SizedBox(height: 22),
            LabeledDropdown(
              label: 'Who can message you',
              value: _messagePermission,
              options: _messagePermissionOptions,
              onChanged: _saving ? (_) {} : _updateMessagePermission,
            ),
            // Moved here from Settings when it was rebuilt to its board (`Settings`); this page
            // follows `SettingsPrivacy` next (plan section 17.10).
            const SizedBox(height: 12),
            SettingsRow(label: 'Follow requests', onTap: () => Navigator.pushNamed(context, '/inbox', arguments: InboxTab.requests)),
            SettingsRow(label: 'See your profile as others do', onTap: () => openOwnProfileAsViewer(context)),
            SettingsRow(label: 'Blocked accounts', onTap: () => Navigator.pushNamed(context, '/blocked-users')),
            SettingsRow(label: 'My reports', onTap: () => Navigator.pushNamed(context, '/my-reports')),
            SettingsRow(label: 'Privacy policy', onTap: _openPrivacyPolicy),
          ],
        ),
      ),
    );
  }
}
