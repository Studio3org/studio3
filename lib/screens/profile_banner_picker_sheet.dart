import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../services/piece_service.dart';
import '../services/post_service.dart';
import '../theme/studio_colors.dart';
import '../theme/studio_metrics.dart';
import '../theme/studio_type.dart';
import '../widgets/studio/studio_button.dart';
import '../widgets/studio/studio_sheet.dart';
import '../widgets/studio/studio_tab_bar.dart';

/// Result of the banner picker: (targetType, targetId), or (null, null) to
/// clear a manual pin and fall back to `bannerAutoRule`.
typedef BannerPick = (String?, String?);

/// No board: a board sheet (`showStudioSheet`: scrim, 24 top corners, 40 × 5 grabber)
/// with a 22/500 title, the profile section tabs, and 3-across thumbnails at the small
/// thumbnail radius (8).
Future<BannerPick?> showProfileBannerPicker(BuildContext context, {required String username}) {
  return showStudioSheet<BannerPick>(
    context: context,
    builder: (_) => _ProfileBannerPickerSheet(username: username),
  );
}

class _ProfileBannerPickerSheet extends StatelessWidget {
  const _ProfileBannerPickerSheet({required this.username});

  final String username;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return DefaultTabController(
      length: 2,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          children: [
            const SizedBox(height: 10),
            const StudioSheetGrabber(),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Pin profile banner',
                      style: StudioType.title22(color: c.textPrimary),
                    ),
                  ),
                  StudioButton(
                    label: 'Clear pin',
                    variant: StudioButtonVariant.text,
                    expand: false,
                    onPressed: () => Navigator.pop(context, (null, null) as BannerPick),
                  ),
                ],
              ),
            ),
            const StudioTabBar(labels: ['Pieces', 'Posts']),
            Expanded(
              child: TabBarView(
                children: [
                  _PieceGrid(username: username),
                  _PostGrid(username: username),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PieceGrid extends StatelessWidget {
  const _PieceGrid({required this.username});
  final String username;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: PieceService.instance.getUserPieces(username),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        final pieces = snapshot.data!;
        if (pieces.isEmpty) return const _EmptyGrid('No pieces yet');
        return _Grid(
          count: pieces.length,
          urlAt: (i) => pieces[i].mediaUrl,
          onPick: (i) => Navigator.pop(context, ('piece', pieces[i].id) as BannerPick),
        );
      },
    );
  }
}

class _PostGrid extends StatelessWidget {
  const _PostGrid({required this.username});
  final String username;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: PostService.instance.getUserPosts(username),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        final posts = snapshot.data!;
        if (posts.isEmpty) return const _EmptyGrid('No posts yet');
        return _Grid(
          count: posts.length,
          urlAt: (i) => posts[i].mediaUrl,
          onPick: (i) => Navigator.pop(context, ('post', posts[i].id) as BannerPick),
        );
      },
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.count, required this.urlAt, required this.onPick});

  final int count;
  final String? Function(int index) urlAt;
  final void Function(int index) onPick;

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.viewPaddingOf(context).bottom;
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        safeBottom > 0 ? safeBottom : StudioSize.noInsetBottomPadding,
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemCount: count,
      itemBuilder: (context, index) => GestureDetector(
        onTap: () => onPick(index),
        child: _Thumb(url: urlAt(index)),
      ),
    );
  }
}

class _EmptyGrid extends StatelessWidget {
  const _EmptyGrid(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(message, style: StudioType.body14(color: context.studio.textSecondary)),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    final placeholder = ColoredBox(color: context.studio.surface);
    return ClipRRect(
      borderRadius: BorderRadius.circular(StudioRadius.small),
      child: url == null
          ? placeholder
          : CachedNetworkImage(
              imageUrl: url!,
              fit: BoxFit.cover,
              placeholder: (_, _) => placeholder,
              errorWidget: (_, _, _) => placeholder,
            ),
    );
  }
}
