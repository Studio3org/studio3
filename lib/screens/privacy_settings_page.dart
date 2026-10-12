import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_exception.dart';
import '../services/user_service.dart';
import '../theme/home_feed_tokens.dart';
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

  void _showError(Object e) {
    final message = e is ApiException ? e.message : e.toString();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return StudioLoadingGate(
      loading: _loading,
      child: Scaffold(
        backgroundColor: HomeFeedTokens.background,
        appBar: AppBar(
          backgroundColor: HomeFeedTokens.background,
          elevation: 0,
          title: Text(
            'Privacy',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: HomeFeedTokens.textPrimary,
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            LabeledDropdown(
              label: 'Profile visibility',
              value: _profileVisibility,
              options: _visibilityOptions,
              onChanged: _saving ? (_) {} : _updateVisibility,
            ),
            const SizedBox(height: 16),
            LabeledDropdown(
              label: 'Who can message you',
              value: _messagePermission,
              options: _messagePermissionOptions,
              onChanged: _saving ? (_) {} : _updateMessagePermission,
            ),
          ],
        ),
      ),
    );
  }
}
