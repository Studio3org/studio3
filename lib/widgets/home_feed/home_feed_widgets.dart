import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/feed_item.dart';
import '../../models/feed_preview_item.dart';
import '../../models/piece_summary.dart';
import '../../models/series_summary.dart';
import '../../screens/series_view_page.dart';
import '../../services/auth_session.dart';
import '../../services/chat_service.dart';
import '../../services/chat_socket_service.dart';
import '../../services/main_nav_service.dart';
import '../../services/notification_service.dart';
import '../../services/social_service.dart';
import '../../theme/home_feed_tokens.dart';
import '../../utils/explore_detail_route.dart';
import '../../utils/profile_navigation.dart';
import '../../utils/require_login.dart';
import '../explore/explore_browse.dart' show exploreBrowseAspect;
import '../studio/studio.dart';

/// `Main` top bar: "All ▾" (17/500) on the left, the wordmark centered, Saved
/// and inbox on the right. The chevron keeps the All / Available filter.
/// Inbox keeps its unread check and shows a dot, not a count. Post lives in
/// the floating nav.
class FeedHomeHeader extends StatelessWidget {
  const FeedHomeHeader({
    super.key,
    required this.filter,
    required this.onFilterChanged,
    this.hasAvailableItems = false,
  });

  final FeedAvailabilityFilter filter;
  final ValueChanged<FeedAvailabilityFilter> onFilterChanged;

  /// Green dot on the Available choice when something is for sale.
  final bool hasAvailableItems;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: SizedBox(
        height: StudioSize.tapTarget,
        child: Stack(
          alignment: Alignment.center,
          children: [
            const StudioLogo.header(),
            Row(
              children: [
                _FeedFilterButton(
                  filter: filter,
                  hasAvailableItems: hasAvailableItems,
                  onSelected: onFilterChanged,
                ),
                const Spacer(),
                _HeaderIconButton(
                  icon: StudioIcons.save,
                  label: 'Saved',
                  onTap: () => MainNavService.instance.goSaved(),
                ),
                const _InboxMenuButton(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedFilterButton extends StatelessWidget {
  const _FeedFilterButton({
    required this.filter,
    required this.hasAvailableItems,
    required this.onSelected,
  });

  final FeedAvailabilityFilter filter;
  final bool hasAvailableItems;
  final ValueChanged<FeedAvailabilityFilter> onSelected;

  Future<void> _open(BuildContext context) async {
    final box = context.findRenderObject()! as RenderBox;
    final overlay = Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
    final origin = box.localToGlobal(Offset(0, box.size.height), ancestor: overlay);
    final position = RelativeRect.fromRect(
      origin & box.size,
      Offset.zero & overlay.size,
    );
    final c = context.studio;
    final style = StudioType.body14(weight: StudioType.medium, color: c.textPrimary);
    final next = await showMenu<FeedAvailabilityFilter>(
      context: context,
      position: position,
      color: c.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(StudioRadius.button),
        side: BorderSide(color: c.line),
      ),
      items: [
        PopupMenuItem(
          value: FeedAvailabilityFilter.all,
          height: StudioSize.tapTarget,
          child: Text('All', style: style),
        ),
        PopupMenuItem(
          value: FeedAvailabilityFilter.available,
          height: StudioSize.tapTarget,
          child: Row(
            children: [
              Text('Available', style: style),
              if (hasAvailableItems) ...[
                const SizedBox(width: 8),
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(color: c.available, shape: BoxShape.circle),
                ),
              ],
            ],
          ),
        ),
      ],
    );
    if (next != null) onSelected(next);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final label = filter == FeedAvailabilityFilter.available ? 'Available' : 'All';
    return Semantics(
      button: true,
      container: true,
      excludeSemantics: true,
      label: 'Filter feed',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _open(context),
        child: SizedBox(
          height: StudioSize.tapTarget,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: StudioType.header17(color: c.textPrimary)),
              const SizedBox(width: 4),
              StudioIcon(StudioIcons.filter, size: 14, color: c.textPrimary),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge,
  });

  final String icon;
  final String label;
  final VoidCallback onTap;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: StudioSize.tapTarget,
          height: StudioSize.tapTarget,
          child: Stack(
            alignment: Alignment.center,
            children: [
              StudioIcon(icon, size: 22),
              if (badge != null) Positioned(top: 8, right: 8, child: badge!),
            ],
          ),
        ),
      ),
    );
  }
}

/// 9 px alert dot with a 1.5 px page-colored ring (`Main` inbox). No count.
class FeedUnreadDot extends StatelessWidget {
  const FeedUnreadDot({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: c.alert,
        shape: BoxShape.circle,
        border: Border.all(color: c.background, width: 1.5),
      ),
    );
  }
}

/// Right-side header icon that opens the full Inbox page (Notifications /
/// Chats / Requests).
class _InboxMenuButton extends StatefulWidget {
  const _InboxMenuButton();

  @override
  State<_InboxMenuButton> createState() => _InboxMenuButtonState();
}

class _InboxMenuButtonState extends State<_InboxMenuButton> {
  int _unreadCount = 0;
  int _followRequestCount = 0;
  int _chatUnreadCount = 0;

  @override
  void initState() {
    super.initState();
    _refreshCounts();
    ChatSocketService.instance.onNotificationNew(_onLiveNotification);
  }

  @override
  void dispose() {
    ChatSocketService.instance.offNotificationNew(_onLiveNotification);
    super.dispose();
  }

  void _onLiveNotification(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    if (type == 'message' || type == 'inquiry') return;
    if (!mounted) return;
    setState(() => _unreadCount += 1);
    NotificationService.instance.invalidateUnreadCache();
  }

  Future<void> _refreshCounts() async {
    // Every count below is per-account; a guest has none to fetch.
    if (!AuthSession.instance.isLoggedIn) return;
    final results = await Future.wait<int>([
      NotificationService.instance
          .getUnreadCount()
          .catchError((_) => _unreadCount),
      SocialService.instance
          .listFollowRequests()
          .then((requests) => requests.length)
          .catchError((_) => _followRequestCount),
      ChatService.instance
          .unreadCount()
          .catchError((_) => _chatUnreadCount),
    ]);
    if (!mounted) return;
    setState(() {
      _unreadCount = results[0];
      _followRequestCount = results[1];
      _chatUnreadCount = results[2];
    });
  }

  Future<void> _openInbox(BuildContext context) async {
    if (!await requireLogin(
      context,
      title: 'Sign in to see your inbox',
      message: 'Log in to see your notifications and messages.',
    )) {
      return;
    }
    if (!context.mounted) return;
    await Navigator.pushNamed(context, '/inbox');
    if (context.mounted) _refreshCounts();
  }

  int get _badgeCount =>
      _unreadCount + _followRequestCount + _chatUnreadCount;

  @override
  Widget build(BuildContext context) {
    final unread = _badgeCount > 0;
    return _HeaderIconButton(
      icon: StudioIcons.inbox,
      label: unread ? 'Inbox, unread items' : 'Inbox',
      onTap: () => _openInbox(context),
      badge: unread ? const FeedUnreadDot() : null,
    );
  }
}

class FeedFilterTab extends StatelessWidget {
  const FeedFilterTab({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
    this.fontSize = 16,
    this.underline = true,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final double fontSize;
  final bool underline;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: fontSize,
          fontWeight: FontWeight.w400,
          color: active
              ? HomeFeedTokens.textPrimary
              : HomeFeedTokens.textSecondary,
          decoration: active && underline ? TextDecoration.underline : null,
          decorationColor: HomeFeedTokens.textPrimary,
          decorationThickness: 1,
        ),
      ),
    );
  }
}

class FeedDotIndicators extends StatelessWidget {
  const FeedDotIndicators({
    super.key,
    required this.count,
    required this.page,
  });

  final int count;
  final double page;

  @override
  Widget build(BuildContext context) {
    if (count <= 1) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (i) {
        final d = (page - i).abs().clamp(0.0, 1.0);
        final opacity = 0.5 + 0.5 * (1.0 - d);
        return Padding(
          padding: EdgeInsets.only(left: i > 0 ? 4 : 0),
          child: Container(
            width: HomeFeedTokens.dotSize,
            height: HomeFeedTokens.dotSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: opacity.clamp(0.5, 1.0)),
            ),
          ),
        );
      }),
    );
  }
}

/// Shows a real avatar photo when a URL is available, otherwise an
/// initials circle — avoids ever showing a fake stranger's photo.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.url,
    required this.name,
    this.size = HomeFeedTokens.avatarSize,
  });

  final String? url;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (url != null && url!.isNotEmpty) {
      final px = (size * MediaQuery.devicePixelRatioOf(context)).round();
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: url!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          memCacheWidth: px,
          memCacheHeight: px,
          errorWidget: (context, error, stackTrace) =>
              _InitialsAvatar(name: name, size: size),
        ),
      );
    }
    return _InitialsAvatar(name: name, size: size);
  }
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({required this.name, required this.size});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final initial = trimmed.isNotEmpty ? trimmed[0].toUpperCase() : '?';
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: HomeFeedTokens.neutral800,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: GoogleFonts.inter(
          fontSize: size * 0.42,
          fontWeight: FontWeight.w600,
          color: HomeFeedTokens.textInverse,
        ),
      ),
    );
  }
}

class FeedCardArtistStrip extends StatelessWidget {
  const FeedCardArtistStrip({
    super.key,
    required this.avatarUrl,
    required this.name,
    this.medium,
    this.authorUsername,
  });

  final String? avatarUrl;
  final String name;
  final String? medium;
  final String? authorUsername;

  void _onAvatarTap(BuildContext context) {
    openUserProfile(context, authorUsername);
  }

  @override
  Widget build(BuildContext context) {
    final canNavigate =
        authorUsername != null && authorUsername!.trim().isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        GestureDetector(
          onTap: canNavigate ? () => _onAvatarTap(context) : null,
          behavior:
              canNavigate ? HitTestBehavior.opaque : HitTestBehavior.deferToChild,
          child: UserAvatar(
            url: avatarUrl,
            name: name,
            size: HomeFeedTokens.avatarSize,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: GestureDetector(
            onTap: canNavigate ? () => _onAvatarTap(context) : null,
            behavior: canNavigate
                ? HitTestBehavior.opaque
                : HitTestBehavior.deferToChild,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: HomeFeedTokens.textInverse,
                  ),
                ),
                if (medium != null && medium!.isNotEmpty)
                  Text(
                    medium!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w300,
                      color: HomeFeedTokens.textInverse.withValues(alpha: 0.6),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Bottom scrim + artist strip for API grid cards.
class FeedApiCardOverlay extends StatelessWidget {
  const FeedApiCardOverlay({
    super.key,
    required this.avatarUrl,
    required this.name,
    this.medium,
    this.authorUsername,
  });

  final String? avatarUrl;
  final String name;
  final String? medium;
  final String? authorUsername;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const FeedCardBottomScrim(),
        Positioned(
          left: 8,
          right: 8,
          bottom: 8,
          child: FeedCardArtistStrip(
            avatarUrl: avatarUrl,
            name: name,
            medium: medium,
            authorUsername: authorUsername,
          ),
        ),
      ],
    );
  }
}

class FeedPicsumImage extends StatelessWidget {
  const FeedPicsumImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
  });

  final String url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final cacheWidth = (maxWidth * dpr).round().clamp(1, 2048);
        final c = context.studio;
        // Surface while loading (a spinner only when motion is allowed) and when it fails.
        final still = MediaQuery.disableAnimationsOf(context);
        return CachedNetworkImage(
          imageUrl: url,
          fit: fit,
          width: double.infinity,
          height: double.infinity,
          memCacheWidth: cacheWidth,
          progressIndicatorBuilder: (context, child, progress) => Container(
            color: c.surface,
            alignment: Alignment.center,
            child: still
                ? null
                : SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2, color: c.textTertiary),
                  ),
          ),
          errorWidget: (context, error, stackTrace) => ColoredBox(color: c.surface),
        );
      },
    );
  }
}

class FeedCardBottomScrim extends StatelessWidget {
  const FeedCardBottomScrim({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      height: 88,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              const Color(0xFF231F1B).withValues(alpha: 0.8),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-bleed feed piece (`Main`): width × 4/3, square corners, artist row
/// underneath. Dots and a sideways swipe only when the payload has 2+ photos. A photo
/// Scene keeps its own shape (3:4, 1:1 or landscape, as in Explore) rather than being
/// cropped to a piece's.
class FeedPieceCard extends StatefulWidget {
  const FeedPieceCard({super.key, required this.item, required this.onTap});

  final FeedItem item;
  final VoidCallback onTap;

  @override
  State<FeedPieceCard> createState() => _FeedPieceCardState();
}

class _FeedPieceCardState extends State<FeedPieceCard> {
  int _page = 0;

  List<String> get _urls => widget.item.imageUrls;

  StudioStatus? get _status {
    final piece = widget.item.piece;
    if (piece == null) return null;
    switch (piece.listingState) {
      case 'available':
        return StudioStatus.available;
      case 'collected':
        return StudioStatus.collected;
      default:
        if (piece.isForSale && piece.isLive) return StudioStatus.available;
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final item = widget.item;
    final urls = _urls;
    final name = item.authorName?.trim().isNotEmpty == true ? item.authorName!.trim() : 'Artist';
    final title = item.title?.trim();
    final username = item.authorUsername;
    final canOpenAuthor = username != null && username.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: exploreBrowseAspect(item),
          child: Semantics(
            label: urls.length > 1 ? 'Photo ${_page + 1} of ${urls.length}' : null,
            child: GestureDetector(
              onTap: widget.onTap,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (urls.length > 1)
                    PageView.builder(
                      itemCount: urls.length,
                      onPageChanged: (page) => setState(() => _page = page),
                      itemBuilder: (_, index) => _FeedPhoto(url: urls[index]),
                    )
                  else if (urls.isNotEmpty)
                    _FeedPhoto(url: urls.first)
                  else
                    ColoredBox(color: c.surface),
                  if (urls.length > 1)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 12,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < urls.length; i++) ...[
                            if (i > 0) const SizedBox(width: 5),
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: StudioColors.galleryWhite.withValues(alpha: i == _page ? 1 : 0.5),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              GestureDetector(
                onTap: canOpenAuthor ? () => openUserProfile(context, username) : null,
                child: StudioAvatar(url: item.authorAvatarUrl, size: 32, semanticLabel: name),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: canOpenAuthor ? () => openUserProfile(context, username) : null,
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: StudioType.body14(weight: StudioType.medium, color: c.textPrimary),
                      ),
                    ),
                    if (title != null && title.isNotEmpty)
                      GestureDetector(
                        onTap: widget.onTap,
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: StudioType.label13(color: c.textSecondary),
                        ),
                      ),
                  ],
                ),
              ),
              if (_status != null) ...[
                const SizedBox(width: 10),
                StudioStatusChip(_status!),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _FeedPhoto extends StatelessWidget {
  const _FeedPhoto({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      memCacheWidth: (MediaQuery.sizeOf(context).width * MediaQuery.devicePixelRatioOf(context)).round(),
      placeholder: (_, _) => ColoredBox(color: context.studio.surface),
      errorWidget: (_, _, _) => ColoredBox(color: context.studio.surface),
    );
  }
}

/// Series shelf from a piece that already carries [PieceSeriesInfo]. Cards are
/// 80% of the width inside the 16 px margins, 3:4, radius 12, and the next
/// card peeks. Cover only. See all and the last card open the series (`SeriesPage`).
class FeedSeriesRow extends StatefulWidget {
  const FeedSeriesRow({
    super.key,
    required this.series,
    required this.artistName,
    this.artistUsername,
  });

  final PieceSeriesInfo series;
  final String artistName;
  final String? artistUsername;

  @override
  State<FeedSeriesRow> createState() => _FeedSeriesRowState();
}

class _FeedSeriesRowState extends State<FeedSeriesRow> {
  PageController? _pages;

  @override
  void dispose() {
    _pages?.dispose();
    super.dispose();
  }

  int get _count {
    final ids = widget.series.pieceIds.length;
    if (ids > 0) return ids;
    return widget.series.previewPieces.length;
  }

  void _seeAll() {
    final series = widget.series;
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SeriesViewPage(
          seriesId: series.id,
          initialName: series.name,
          initialPieceCount: _count,
          initialCoverUrl: series.previewPieces.firstOrNull?.mediaUrl,
          authorName: widget.artistName,
          authorUsername: widget.artistUsername,
        ),
      ),
    );
  }

  void _openPreview(SeriesPreviewPiece preview) {
    openExploreDetail(
      context,
      FeedItem.piece(
        PieceSummary(
          id: preview.id,
          title: preview.title ?? '',
          mediaUrl: preview.mediaUrl,
          authorName: widget.artistName,
          authorUsername: widget.artistUsername,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final previews = widget.series.previewPieces;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final cardWidth = (width - 32) * 0.8;
          final cardHeight = cardWidth * 4 / 3;
          final fraction = (cardWidth + 10) / (width - 16);
          _pages ??= PageController(viewportFraction: fraction);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.series.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: StudioType.header17(color: c.textPrimary),
                          ),
                          Text.rich(
                            TextSpan(
                              style: StudioType.label13(color: c.textSecondary),
                              children: [
                                TextSpan(text: '${widget.artistName} · '),
                                TextSpan(
                                  text: '$_count pieces',
                                  style: StudioType.mono(12, color: c.textSecondary),
                                ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: _seeAll,
                      style: TextButton.styleFrom(
                        foregroundColor: c.textSecondary,
                        minimumSize: const Size(44, 44),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.symmetric(horizontal: 0),
                      ),
                      child: Text('See all', style: StudioType.body14(weight: StudioType.medium, color: c.textSecondary)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: cardHeight,
                child: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: PageView.builder(
                    controller: _pages,
                    padEnds: false,
                    itemCount: previews.length + 1,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: index == previews.length
                            ? _SeeAllSeriesCard(
                                width: cardWidth,
                                count: _count,
                                thumbs: [for (final preview in previews.take(3)) preview.mediaUrl],
                                onTap: _seeAll,
                              )
                            : _SeriesCoverCard(
                                width: cardWidth,
                                preview: previews[index],
                                onTap: () => _openPreview(previews[index]),
                              ),
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SeriesCoverCard extends StatelessWidget {
  const _SeriesCoverCard({required this.width, required this.preview, required this.onTap});

  final double width;
  final SeriesPreviewPiece preview;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = preview.title?.trim() ?? '';
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(StudioRadius.button),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (preview.mediaUrl != null && preview.mediaUrl!.isNotEmpty)
                _FeedPhoto(url: preview.mediaUrl!)
              else
                ColoredBox(color: context.studio.surface),
              if (title.isNotEmpty)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: ColoredBox(
                    color: StudioColors.imageCaptionBar,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: StudioType.label13(weight: StudioType.medium, color: StudioColors.galleryWhite),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeeAllSeriesCard extends StatelessWidget {
  const _SeeAllSeriesCard({
    required this.width,
    required this.count,
    required this.thumbs,
    required this.onTap,
  });

  final double width;
  final int count;
  final List<String?> thumbs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(StudioRadius.button),
            border: Border.all(color: c.line),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < thumbs.length; i++) ...[
                    if (i > 0) const SizedBox(width: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        width: 44,
                        height: 58,
                        child: thumbs[i] != null && thumbs[i]!.isNotEmpty
                            ? _FeedPhoto(url: thumbs[i]!)
                            : ColoredBox(color: c.line),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              Text('See all $count pieces', style: StudioType.header17(color: c.textPrimary)),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Open the series', style: StudioType.body14(color: c.textSecondary)),
                  const SizedBox(width: 6),
                  StudioIcon(StudioIcons.arrowRight, size: 16, color: c.textSecondary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

