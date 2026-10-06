import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/blocked_user.dart';
import '../services/social_service.dart';
import '../theme/app_theme.dart';
import '../theme/home_feed_tokens.dart';
import '../utils/profile_navigation.dart';
import '../widgets/glass_card.dart';
import '../widgets/home_feed/home_feed_widgets.dart';
import '../widgets/offline_state.dart';
import '../widgets/studio_loading.dart';

class BlockedUsersPage extends StatefulWidget {
  const BlockedUsersPage({super.key});

  @override
  State<BlockedUsersPage> createState() => _BlockedUsersPageState();
}

class _BlockedUsersPageState extends State<BlockedUsersPage> {
  List<BlockedUser> _blocked = [];
  bool _loading = true;
  bool _showOfflineState = false;
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final blocked = await SocialService.instance.listBlocked();
      if (!mounted) return;
      setState(() {
        _blocked = blocked;
        _loading = false;
        _showOfflineState = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _showOfflineState = _blocked.isEmpty;
      });
    }
  }

  Future<void> _unblock(BlockedUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Unblock @${user.username}?'),
        content: const Text(
          'They will be able to follow and message you again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Unblock'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy.add(user.username));
    try {
      await SocialService.instance.unblockUser(user.username);
      if (!mounted) return;
      setState(() => _blocked.removeWhere((b) => b.username == user.username));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to unblock: $e')));
    } finally {
      if (mounted) setState(() => _busy.remove(user.username));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HomeFeedTokens.background,
      appBar: AppBar(
        backgroundColor: HomeFeedTokens.background,
        elevation: 0,
        title: Text(
          'Blocked accounts',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: HomeFeedTokens.textPrimary,
          ),
        ),
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_showOfflineState) {
      return OfflineState(onRetry: _load);
    }
    if (_loading && _blocked.isEmpty) {
      return const StudioLoadingBody();
    }
    if (_blocked.isEmpty) {
      return Center(
        child: Text(
          'No blocked accounts',
          style: GoogleFonts.inter(fontSize: 14, color: AppColors.slate400),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _blocked.length,
        itemBuilder: (context, index) {
          final user = _blocked[index];
          final busy = _busy.contains(user.username);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GlassCard(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => openUserProfile(context, user.username),
                    child: UserAvatar(
                      url: user.profilePhotoUrl,
                      name: user.name,
                      size: 40,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '@${user.username}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.slate500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    onPressed: busy ? null : () => _unblock(user),
                    child: busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Unblock'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
