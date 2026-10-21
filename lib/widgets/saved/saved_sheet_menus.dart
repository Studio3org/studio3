import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/studio_colors.dart';
import '../../theme/studio_metrics.dart';
import '../../theme/studio_type.dart';
import '../home_feed/home_feed_widgets.dart';
import '../studio/studio_icon.dart';
import '../studio/studio_sheet.dart';

enum SavedHoldAction { move, share, remove }

/// Three dots inside a folder the person made. All saved and Available omit it.
class SavedFolderOptionsButton extends StatelessWidget {
  const SavedFolderOptionsButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const Key('saved-folder-options'),
      onPressed: onPressed,
      tooltip: 'Folder options',
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        minimumSize: const Size(StudioSize.tapTarget, StudioSize.tapTarget),
        fixedSize: const Size(StudioSize.tapTarget, StudioSize.tapTarget),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: StudioIcon(
        StudioIcons.folderOptions,
        size: 22,
        color: context.studio.textPrimary,
      ),
    );
  }
}

/// Rename and delete for one of the person's folders.
class SavedFolderMenu extends StatelessWidget {
  const SavedFolderMenu({super.key});

  static Future<String?> show(BuildContext context) {
    return showStudioSheet<String>(
      context: context,
      builder: (sheetContext) => const SavedFolderMenu(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StudioSheet(
      horizontalPadding: StudioSpace.marginForm,
      gap: 14,
      children: [
        _MenuRow(
          icon: StudioIcons.renameFolder,
          label: 'Rename folder',
          onTap: () => Navigator.pop(context, 'rename'),
        ),
        _MenuRow(
          icon: StudioIcons.deleteFolder,
          label: 'Delete folder',
          subtitle: 'The pieces stay in All saved',
          onTap: () => Navigator.pop(context, 'delete'),
        ),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
  });

  final String icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: StudioSize.tapTarget),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: c.line)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              children: [
                StudioIcon(icon, size: 22, color: c.textPrimary),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: StudioType.body16(color: c.textPrimary)),
                      if (subtitle != null)
                        Text(subtitle!, style: StudioType.caption12(color: c.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Confirm before a folder is removed. The pieces stay saved.
class SavedDeleteFolderSheet extends StatelessWidget {
  const SavedDeleteFolderSheet({super.key, required this.name});

  final String name;

  static Future<bool?> show(BuildContext context, {required String name}) {
    return showStudioSheet<bool>(
      context: context,
      builder: (context) => SavedDeleteFolderSheet(name: name),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return StudioSheet(
      horizontalPadding: StudioSpace.marginForm,
      gap: 14,
      children: [
        Text('Delete "$name"?', style: StudioType.title22(color: c.textPrimary)),
        Text(
          'The pieces stay in All saved.',
          style: StudioType.body14(color: c.textSecondary),
        ),
        Row(
          children: [
            Expanded(
              child: _TextAction(
                label: 'Cancel',
                color: c.textSecondary,
                onTap: () => Navigator.pop(context, false),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _TextAction(
                label: 'Delete',
                color: c.alert,
                onTap: () => Navigator.pop(context, true),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TextAction extends StatelessWidget {
  const _TextAction({required this.label, required this.color, required this.onTap});

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: StudioSize.tapTarget,
        child: Center(
          child: Text(label, style: StudioType.sans(15, weight: StudioType.medium, color: color)),
        ),
      ),
    );
  }
}

/// Press-and-hold menu. The piece lifts, the page behind blurs, and a tap
/// outside closes it.
class SavedHoldMenu {
  static Future<SavedHoldAction?> show(
    BuildContext context, {
    String? imageUrl,
  }) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return showGeneralDialog<SavedHoldAction>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Close',
      barrierColor: Colors.transparent,
      transitionDuration: reduce ? Duration.zero : StudioMotion.quick,
      pageBuilder: (dialogContext, _, _) {
        return SavedHoldMenuCard(
          imageUrl: imageUrl,
          onDismiss: () => Navigator.pop(dialogContext),
          onMove: () => Navigator.pop(dialogContext, SavedHoldAction.move),
          onShare: () => Navigator.pop(dialogContext, SavedHoldAction.share),
          onRemove: () => Navigator.pop(dialogContext, SavedHoldAction.remove),
        );
      },
      transitionBuilder: (context, animation, _, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );
  }
}

class SavedHoldMenuCard extends StatelessWidget {
  const SavedHoldMenuCard({
    super.key,
    required this.onDismiss,
    required this.onMove,
    required this.onShare,
    required this.onRemove,
    this.imageUrl,
  });

  final String? imageUrl;
  final VoidCallback onDismiss;
  final VoidCallback onMove;
  final VoidCallback onShare;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final url = imageUrl;
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: onDismiss,
            behavior: HitTestBehavior.opaque,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
              child: ColoredBox(color: c.background.withValues(alpha: 0.35)),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 76, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (url != null && url.isNotEmpty)
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(StudioRadius.card),
                    boxShadow: const [
                      BoxShadow(color: Color(0x33111111), blurRadius: 40, offset: Offset(0, 20)),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(StudioRadius.card),
                    child: SizedBox(
                      width: 200,
                      height: 267,
                      child: FeedPicsumImage(url: url),
                    ),
                  ),
                ),
              if (url != null && url.isNotEmpty) const SizedBox(height: 16),
              Material(
                color: c.card,
                elevation: 0,
                borderRadius: BorderRadius.circular(StudioRadius.panel),
                child: Container(
                  width: 250,
                  decoration: BoxDecoration(
                    color: c.card,
                    borderRadius: BorderRadius.circular(StudioRadius.panel),
                    boxShadow: const [
                      BoxShadow(color: Color(0x2E111111), blurRadius: 30, offset: Offset(0, 12)),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _HoldRow(label: 'Move to folder', icon: StudioIcons.folder, onTap: onMove),
                      _HoldRow(label: 'Share', icon: StudioIcons.share, onTap: onShare),
                      _HoldRow(label: 'Remove from Saved', icon: StudioIcons.save, onTap: onRemove),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HoldRow extends StatelessWidget {
  const _HoldRow({required this.label, required this.icon, required this.onTap});

  final String label;
  final String icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: c.surface)),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: StudioSize.tapTarget),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: StudioType.sans(15, color: c.textPrimary),
                  ),
                ),
                const SizedBox(width: 12),
                StudioIcon(icon, size: 20, color: c.textPrimary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
