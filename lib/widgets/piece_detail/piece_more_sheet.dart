import 'package:flutter/material.dart';

import '../../models/feed_preview_item.dart';
import '../../services/api_exception.dart';
import '../../services/social_service.dart';
import '../../theme/collect_detail_tokens.dart';
import '../../theme/home_feed_tokens.dart';
import '../../utils/profile_navigation.dart';
import 'detail_share.dart';
import 'report_reason_sheet.dart';
import '../../theme/app_fonts.dart';

class PieceMoreSheet extends StatelessWidget {
  const PieceMoreSheet({
    super.key,
    required this.item,
    this.isOwner = false,
    this.onEdit,
    this.onManageAuction,
    this.imageIndex = 0,
  });

  final FeedPreviewItem item;
  final bool isOwner;
  final VoidCallback? onEdit;

  /// Extend, cancel or relist. Only offered to the owner of a piece that actually has an
  /// auction — there is nothing to manage on fixed-price work.
  final VoidCallback? onManageAuction;
  final int imageIndex;

  static Future<void> show(
    BuildContext context, {
    required FeedPreviewItem item,
    bool isOwner = false,
    VoidCallback? onEdit,
    VoidCallback? onManageAuction,
    int imageIndex = 0,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: HomeFeedTokens.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        top: false,
        child: PieceMoreSheet(
          item: item,
          isOwner: isOwner,
          onEdit: onEdit,
          onManageAuction: onManageAuction,
          imageIndex: imageIndex,
        ),
      ),
    );
  }

  String get _handle {
    final raw = item.handle;
    return raw.startsWith('@') ? raw.substring(1) : raw;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: HomeFeedTokens.textSecondary.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(100),
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (isOwner && onEdit != null)
            _MoreRow(
              label: 'Edit piece',
              onTap: () {
                Navigator.pop(context);
                onEdit!();
              },
            ),
          if (isOwner && onManageAuction != null)
            _MoreRow(
              label: 'Manage auction',
              onTap: () {
                Navigator.pop(context);
                onManageAuction!();
              },
            ),
          _MoreRow(
            label: 'Copy link',
            onTap: () {
              Navigator.pop(context);
              shareFeedPreviewItem(context, item, imageIndex: imageIndex);
            },
          ),
          if (!isOwner) ...[
            _MoreRow(
              label: 'View artist',
              onTap: () {
                Navigator.pop(context);
                openUserProfile(context, item.handle);
              },
            ),
            _MoreRow(
              label: item.isScene ? 'Report scene' : 'Report piece',
              destructive: true,
              onTap: () {
                Navigator.pop(context);
                _reportContent(context);
              },
            ),
            _MoreRow(
              label: 'Report artist',
              destructive: true,
              onTap: () {
                Navigator.pop(context);
                _reportArtist(context);
              },
            ),
            _MoreRow(
              label: 'Block $_handle',
              destructive: true,
              onTap: () {
                Navigator.pop(context);
                _confirmBlock(context);
              },
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _reportContent(BuildContext context) async {
    final result = await ReportReasonSheet.show(
      context,
      title: item.isScene ? 'Report this scene' : 'Report this piece',
    );
    if (result == null || !context.mounted) return;
    try {
      if (item.isScene) {
        await SocialService.instance
            .reportPost(item.id, result.reason, details: result.details);
      } else {
        await SocialService.instance
            .reportPiece(item.id, result.reason, details: result.details);
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thanks — we received your report')),
      );
    } catch (e) {
      if (!context.mounted) return;
      final message =
          e is ApiException ? e.message : 'Could not submit your report';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _reportArtist(BuildContext context) async {
    final result = await ReportReasonSheet.show(
      context,
      title: 'Report $_handle',
    );
    if (result == null || !context.mounted) return;
    try {
      await SocialService.instance
          .reportUser(_handle, result.reason, details: result.details);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thanks — we received your report')),
      );
    } catch (e) {
      if (!context.mounted) return;
      final message =
          e is ApiException ? e.message : 'Could not submit your report';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _confirmBlock(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: HomeFeedTokens.background,
        title: Text(
          'Block $_handle?',
          style: AppFonts.geist(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: CollectDetailTokens.textPrimary,
          ),
        ),
        content: Text(
          'You won’t see their pieces or scenes in your feed.',
          style: AppFonts.geist(
            fontSize: 14,
            color: CollectDetailTokens.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Block',
              style: AppFonts.geist(color: const Color(0xFFC45C4A)),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await SocialService.instance.blockUser(_handle);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Blocked $_handle')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!context.mounted) return;
      final message =
          e is ApiException ? e.message : 'Could not block this artist';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }
}

class _MoreRow extends StatelessWidget {
  const _MoreRow({
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      title: Text(
        label,
        style: AppFonts.geist(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: destructive
              ? const Color(0xFFC45C4A)
              : CollectDetailTokens.textPrimary,
        ),
      ),
    );
  }
}
