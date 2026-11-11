import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/user_profile.dart';
import '../services/api_exception.dart';
import '../services/auth_session.dart';
import '../services/social_service.dart';
import '../services/user_service.dart';
import '../utils/profile_navigation.dart';
import '../widgets/feed_skeleton.dart';
import '../widgets/settings_tile.dart';
import '../widgets/studio/studio.dart';
import 'follow_requests_page.dart';

/// Who can message you: the server's value and the words on the row and in the sheet.
const privacyMessageOptions = [
  ('everyone', 'Everyone'),
  ('following', 'People you follow'),
  ('no_one', 'No one'),
];

String privacyMessageLabel(String value) =>
    privacyMessageOptions.firstWhere((o) => o.$1 == value, orElse: () => privacyMessageOptions.first).$2;

/// Privacy (`SettingsPrivacy`, Flow 12): Private account (a switch; "Only approved followers see
/// your profile"), Follow requests (the count), Who can message you (Everyone, People you
/// follow, No one, in a sheet), Blocked accounts (the count), and See your profile as others do.
///
/// A seller profile can't go private (listings are public): the switch says so instead. Going
/// public with requests waiting asks first; the server approves them in the same call (B34). Private Collection (B34) shows once the server sends it; Hidden pieces
/// (B32) isn't shown until the server has it. My reports and the privacy policy, moved here from the old Settings, sit
/// under the board's rows.
class PrivacySettingsPage extends StatefulWidget {
  const PrivacySettingsPage({
    super.key,
    this.debugProfile,
    this.debugSeller,
    this.debugRequests,
    this.debugBlocked,
  });

  /// For tests: the account instead of loading it.
  @visibleForTesting
  final UserProfile? debugProfile;

  /// For tests: whether selling is on.
  @visibleForTesting
  final bool? debugSeller;

  /// For tests: the usernames waiting to follow.
  @visibleForTesting
  final List<String>? debugRequests;

  /// For tests: how many accounts are blocked.
  @visibleForTesting
  final int? debugBlocked;

  @override
  State<PrivacySettingsPage> createState() => _PrivacySettingsPageState();
}

class _PrivacySettingsPageState extends State<PrivacySettingsPage> {
  bool _private = false;

  /// Private Collection; null when the server doesn't have it (the row isn't shown).
  bool? _collectionPrivate;
  String _messages = 'everyone';
  bool _seller = AuthSession.instance.sellerEnabled;
  List<String> _requests = const [];
  int? _blocked;
  bool _loading = true;
  bool _saving = false;

  bool get _debug => widget.debugProfile != null;

  @override
  void initState() {
    super.initState();
    final profile = widget.debugProfile;
    if (profile != null) {
      _private = profile.isPrivate;
      _collectionPrivate = profile.collectionPrivate;
      _messages = profile.messagePermission;
      _seller = widget.debugSeller ?? false;
      _requests = widget.debugRequests ?? const [];
      _blocked = widget.debugBlocked;
      _loading = false;
      return;
    }
    _load();
  }

  Future<void> _load() async {
    try {
      final profile = await UserService.instance.getMe();
      if (!mounted) return;
      setState(() {
        _private = profile.isPrivate;
        _collectionPrivate = profile.collectionPrivate;
        _messages = profile.messagePermission;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
    _loadCounts();
    try {
      final status = await UserService.instance.getSellerStatus();
      if (mounted) setState(() => _seller = status.enabled);
    } catch (_) {
      // The session's seller flag stays.
    }
  }

  Future<void> _loadCounts() async {
    if (_debug) return;
    try {
      final requests = await SocialService.instance.listFollowRequests();
      if (mounted) setState(() => _requests = [for (final r in requests) r.username]);
    } catch (_) {}
    try {
      final blocked = await SocialService.instance.listBlocked();
      if (mounted) setState(() => _blocked = blocked.length);
    } catch (_) {}
  }

  Future<void> _setPrivate(bool value) async {
    if (_saving || value == _private) return;
    if (value && _seller) {
      showStudioToast(context, 'Seller profiles stay public, since listings are.', icon: null);
      return;
    }
    final waiting = _requests;
    if (!value && waiting.isNotEmpty) {
      final count = waiting.length;
      final confirmed = await showStudioConfirm(
        context,
        title: 'Make your account public?',
        message: count == 1
            ? 'The person waiting to follow you will be approved.'
            : 'The $count people waiting to follow you will be approved.',
        confirmLabel: 'Make public',
      );
      if (!confirmed || !mounted) return;
    }
    setState(() {
      _private = value;
      _saving = true;
    });
    try {
      if (!_debug) await UserService.instance.updateMe(profileVisibility: value ? 'private' : 'public');
      // Going public approves everyone waiting on the server (B34): reload the counts.
      if (!value && waiting.isNotEmpty) await _refreshRequests();
    } catch (e) {
      if (!mounted) return;
      setState(() => _private = !value);
      _showError(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Private Collection (`SettingsPrivacy`): hides the Collection tab from everyone but them,
  /// followers too. Shown at once; put back if the server refuses.
  Future<void> _setCollectionPrivate(bool value) async {
    if (_saving || value == _collectionPrivate) return;
    setState(() {
      _collectionPrivate = value;
      _saving = true;
    });
    try {
      if (!_debug) await UserService.instance.updateMe(collectionPrivate: value);
    } catch (e) {
      if (!mounted) return;
      setState(() => _collectionPrivate = !value);
      _showError(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Once the account is public the server has approved everyone waiting (B34): reload the
  /// counts so Follow requests shows what is left.
  Future<void> _refreshRequests() async {
    if (_debug) {
      if (mounted) setState(() => _requests = const []);
      return;
    }
    await _loadCounts();
  }

  Future<void> _pickMessages() async {
    final picked = await showStudioSheet<String>(
      context: context,
      builder: (sheetContext) {
        final c = sheetContext.studio;
        return StudioSheet(
          horizontalPadding: 24,
          gap: 0,
          children: [
            const SizedBox(height: 8),
            Text('Who can message you', style: StudioType.title22(color: c.textPrimary)),
            const SizedBox(height: 12),
            for (final (value, label) in privacyMessageOptions)
              StudioListRow(
                title: label,
                selected: value == _messages,
                divider: value != privacyMessageOptions.last.$1,
                onTap: () => Navigator.pop(sheetContext, value),
              ),
          ],
        );
      },
    );
    if (picked == null || picked == _messages || !mounted) return;
    final previous = _messages;
    setState(() => _messages = picked);
    try {
      if (!_debug) await UserService.instance.updateMe(messagePermission: picked);
    } catch (e) {
      if (!mounted) return;
      setState(() => _messages = previous);
      _showError(e);
    }
  }

  Future<void> _openFollowRequests() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => const FollowRequestsPage()),
    );
    _loadCounts();
  }

  Future<void> _openBlocked() async {
    await Navigator.pushNamed(context, '/blocked-users');
    _loadCounts();
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
    final c = context.studio;
    final blocked = _blocked;
    return Scaffold(
      backgroundColor: c.background,
      appBar: StudioTopBar(context: context, title: 'Privacy'),
      body: _loading
          ? const SettingsListSkeleton()
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
              children: [
                SettingsRow(
                  label: 'Private account',
                  subtitle: 'Only approved followers see your profile',
                  chevron: false,
                  valueWidget: StudioSwitch(
                    value: _private,
                    onChanged: _saving ? null : _setPrivate,
                    semanticLabel: 'Private account',
                  ),
                  onTap: _saving ? null : () => _setPrivate(!_private),
                ),
                SettingsRow(
                  label: 'Follow requests',
                  value: _requests.isEmpty ? null : '${_requests.length}',
                  onTap: _openFollowRequests,
                ),
                SettingsRow(
                  label: 'Who can message you',
                  value: privacyMessageLabel(_messages),
                  onTap: _pickMessages,
                ),
                if (_collectionPrivate != null)
                  SettingsRow(
                    label: 'Private Collection',
                    subtitle: 'Only you see the pieces you own',
                    chevron: false,
                    valueWidget: StudioSwitch(
                      value: _collectionPrivate!,
                      onChanged: _saving ? null : _setCollectionPrivate,
                      semanticLabel: 'Private Collection',
                    ),
                    onTap: _saving ? null : () => _setCollectionPrivate(!_collectionPrivate!),
                  ),
                SettingsRow(
                  label: 'Blocked accounts',
                  value: blocked == null || blocked == 0 ? null : '$blocked',
                  onTap: _openBlocked,
                ),
                SettingsRow(
                  label: 'See your profile as others do',
                  onTap: () => openOwnProfileAsViewer(context),
                ),
                const SizedBox(height: 28),
                SettingsRow(label: 'My reports', onTap: () => Navigator.pushNamed(context, '/my-reports')),
                SettingsRow(label: 'Privacy policy', onTap: _openPrivacyPolicy),
              ],
            ),
    );
  }
}
