import 'package:flutter/material.dart';

import '../models/blocked_user.dart';
import '../services/social_service.dart';
import '../utils/profile_navigation.dart';
import '../widgets/studio/studio.dart';
import '../widgets/offline_state.dart';
import '../widgets/studio_loading.dart';

class BlockedUsersPage extends StatefulWidget {
  const BlockedUsersPage({super.key, this.debugBlocked});

  /// For tests: the list, instead of asking the server.
  @visibleForTesting
  final List<BlockedUser>? debugBlocked;

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
    final given = widget.debugBlocked;
    if (given != null) {
      setState(() {
        _blocked = [...given];
        _loading = false;
      });
      return;
    }
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
    final confirmed = await showStudioConfirm(
      context,
      title: 'Unblock @${user.username}?',
      message: 'They will be able to follow and message you again.',
      confirmLabel: 'Unblock',
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy.add(user.username));
    try {
      await SocialService.instance.unblockUser(user.username);
      if (!mounted) return;
      setState(() => _blocked.removeWhere((b) => b.username == user.username));
    } catch (e) {
      if (!mounted) return;
      showStudioToast(context, 'Could not unblock. Try again.', icon: null);
    } finally {
      if (mounted) setState(() => _busy.remove(user.username));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.studio.background,
      appBar: StudioTopBar(context: context, title: 'Blocked accounts'),
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
      return const Center(
        child: StudioEmptyState(
          title: 'No blocked accounts',
          message: "People you block can't message you or see your work in their feeds.",
        ),
      );
    }
    final c = context.studio;
    return RefreshIndicator(
      color: c.textPrimary,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(StudioSpace.marginPage, 4, StudioSpace.marginPage, 40),
        itemCount: _blocked.length,
        itemBuilder: (context, index) {
          final user = _blocked[index];
          final busy = _busy.contains(user.username);
          // Avatar 40, name 14/500 over the handle 12 Graphite, the small outline Unblock;
          // 12 above and below, a Line under (the follow list rows).
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => openUserProfile(context, user.username),
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      children: [
                        StudioAvatar(url: user.profilePhotoUrl, size: 40, semanticLabel: user.name),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: StudioType.body14(weight: StudioType.medium, color: c.textPrimary),
                              ),
                              Text(
                                '@${user.username}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: StudioType.caption12(color: c.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                StudioButton(
                  label: 'Unblock',
                  variant: StudioButtonVariant.small,
                  loading: busy,
                  onPressed: busy ? null : () => _unblock(user),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
