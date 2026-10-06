import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/piece_service.dart';
import '../services/post_service.dart';
import '../theme/home_feed_tokens.dart';

/// Result of the banner picker: (targetType, targetId), or (null, null) to
/// clear a manual pin and fall back to `bannerAutoRule`.
typedef BannerPick = (String?, String?);

Future<BannerPick?> showProfileBannerPicker(
  BuildContext context, {
  required String username,
}) {
  return showModalBottomSheet<BannerPick>(
    context: context,
    isScrollControlled: true,
    backgroundColor: HomeFeedTokens.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _ProfileBannerPickerSheet(username: username),
  );
}

class _ProfileBannerPickerSheet extends StatelessWidget {
  const _ProfileBannerPickerSheet({required this.username});

  final String username;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: HomeFeedTokens.textPrimary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 48),
                Text(
                  'Pin profile banner',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: HomeFeedTokens.textPrimary,
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, (null, null) as BannerPick),
                  child: const Text('Clear pin'),
                ),
              ],
            ),
            TabBar(
              labelColor: HomeFeedTokens.textPrimary,
              unselectedLabelColor: HomeFeedTokens.textSecondary,
              indicatorColor: HomeFeedTokens.textPrimary,
              tabs: const [Tab(text: 'Pieces'), Tab(text: 'Posts')],
            ),
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
          return const Center(child: CircularProgressIndicator());
        }
        final pieces = snapshot.data!;
        if (pieces.isEmpty) {
          return const Center(child: Text('No pieces yet'));
        }
        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
          ),
          itemCount: pieces.length,
          itemBuilder: (context, index) {
            final piece = pieces[index];
            return GestureDetector(
              onTap: () => Navigator.pop(
                context,
                ('piece', piece.id) as BannerPick,
              ),
              child: _Thumb(url: piece.mediaUrl),
            );
          },
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
          return const Center(child: CircularProgressIndicator());
        }
        final posts = snapshot.data!;
        if (posts.isEmpty) {
          return const Center(child: Text('No posts yet'));
        }
        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
          ),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            return GestureDetector(
              onTap: () => Navigator.pop(
                context,
                ('post', post.id) as BannerPick,
              ),
              child: _Thumb(url: post.mediaUrl),
            );
          },
        );
      },
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: url == null
          ? Container(color: HomeFeedTokens.textPrimary.withValues(alpha: 0.08))
          : CachedNetworkImage(
              imageUrl: url!,
              fit: BoxFit.cover,
              errorWidget: (context, url, error) =>
                  Container(color: HomeFeedTokens.textPrimary.withValues(alpha: 0.08)),
            ),
    );
  }
}
