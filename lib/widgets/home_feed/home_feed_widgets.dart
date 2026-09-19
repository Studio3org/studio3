import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';

import '../../data/nav_assets.dart';
import '../../models/feed_preview_item.dart';
import '../../services/chat_service.dart';
import '../../services/chat_socket_service.dart';
import '../../services/notification_service.dart';
import '../../services/social_service.dart';
import '../../theme/home_feed_tokens.dart';
import '../../utils/profile_navigation.dart';

class FeedHomeHeader extends StatelessWidget {
  const FeedHomeHeader({
    super.key,
    required this.filter,
    required this.onFilterChanged,
    required this.onSavedTap,
  });

  final HomeFeedContentFilter filter;
  final ValueChanged<HomeFeedContentFilter> onFilterChanged;
  final VoidCallback onSavedTap;

  String get _filterLabel => switch (filter) {
        HomeFeedContentFilter.all => 'All',
        HomeFeedContentFilter.piece => 'Piece',
        HomeFeedContentFilter.scene => 'Scene',
      };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Row(
        children: [
          _FeedTypeDropdown(
            label: _filterLabel,
            selected: filter,
            onSelected: onFilterChanged,
          ),
          Expanded(
            child: Text(
              'studio 3',
              textAlign: TextAlign.center,
              style: GoogleFonts.geist(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Colors.black,
                height: 1,
              ),
            ),
          ),
          SizedBox(
            width: 64,
            height: 22,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                SvgPicture.asset(
                  NavAssets.headerActions,
                  width: 64,
                  height: 22,
                  fit: BoxFit.fill,
                ),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: onSavedTap,
                        behavior: HitTestBehavior.opaque,
                      ),
                    ),
                    const Expanded(child: _InboxMenuButton()),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedTypeDropdown extends StatelessWidget {
  const _FeedTypeDropdown({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final HomeFeedContentFilter selected;
  final ValueChanged<HomeFeedContentFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<HomeFeedContentFilter>(
      padding: EdgeInsets.zero,
      tooltip: 'Filter feed',
      offset: const Offset(0, 36),
      color: HomeFeedTokens.background,
      style: const ButtonStyle(
        padding: WidgetStatePropertyAll(EdgeInsets.zero),
        minimumSize: WidgetStatePropertyAll(Size.zero),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final option in HomeFeedContentFilter.values)
          PopupMenuItem(
            value: option,
            child: Text(
              switch (option) {
                HomeFeedContentFilter.all => 'All',
                HomeFeedContentFilter.piece => 'Piece',
                HomeFeedContentFilter.scene => 'Scene',
              },
              style: GoogleFonts.geist(
                fontSize: 16,
                fontWeight: option == selected
                    ? FontWeight.w600
                    : FontWeight.w400,
                color: HomeFeedTokens.textPrimary,
              ),
            ),
          ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.geist(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: HomeFeedTokens.textPrimary,
              height: 1.1,
            ),
          ),
          const SizedBox(width: 4),
          SvgPicture.asset(
            NavAssets.chevronDown,
            width: 8,
            height: 4,
          ),
        ],
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
    await Navigator.pushNamed(context, '/inbox');
    if (context.mounted) _refreshCounts();
  }

  int get _badgeCount =>
      _unreadCount + _followRequestCount + _chatUnreadCount;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openInbox(context),
      behavior: HitTestBehavior.opaque,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          const SizedBox.expand(),
          if (_badgeCount > 0)
            Positioned(
              top: -4,
              right: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                decoration: const BoxDecoration(
                  color: Color(0xFFE05252),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  _badgeCount > 9 ? '9+' : '$_badgeCount',
                  style: GoogleFonts.geist(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
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
      crossAxisAlignment: CrossAxisAlignment.center,
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
        const SizedBox(width: 10),
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
                  style: GoogleFonts.geist(
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
                    style: GoogleFonts.geist(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
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
    this.showAvailable = false,
    this.showAuction = false,
    this.showCollected = false,
  });

  final String? avatarUrl;
  final String name;
  final String? medium;
  final String? authorUsername;
  final bool showAvailable;

  /// Bidding is open. Distinct from [showAvailable] because the price on an
  /// auction card is a starting bid, not a purchase price.
  final bool showAuction;
  final bool showCollected;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const FeedCardBottomScrim(),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 56,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: FeedCardArtistStrip(
                    avatarUrl: avatarUrl,
                    name: name,
                    medium: medium,
                    authorUsername: authorUsername,
                  ),
                ),
                if (showAvailable)
                  const _StatusPill(
                    label: 'Available',
                    iconAsset: NavAssets.availableDot,
                  )
                else if (showAuction)
                  const _StatusPill(
                    label: 'Bidding open',
                    iconAsset: NavAssets.availableDot,
                  )
                else if (showCollected)
                  const _StatusPill(
                    label: 'Collected',
                    iconAsset: NavAssets.collectedMark,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.iconAsset});

  final String label;
  final String iconAsset;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0x99231F1B),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            iconAsset,
            width: 8,
            height: 8,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.geist(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: HomeFeedTokens.textInverse,
            ),
          ),
        ],
      ),
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
        return CachedNetworkImage(
          imageUrl: url,
          fit: fit,
          width: double.infinity,
          height: double.infinity,
          memCacheWidth: cacheWidth,
          // Animated left-to-right wave instead of a static gray box +
          // spinner, so an individual piece/post image loading in mid-scroll
          // reads the same "loading" way the initial feed skeleton does.
          progressIndicatorBuilder: (context, child, progress) =>
              Shimmer.fromColors(
            baseColor: HomeFeedTokens.skeletonBase,
            highlightColor: Colors.white,
            period: const Duration(milliseconds: 1100),
            direction: ShimmerDirection.ltr,
            child: const DecoratedBox(
              decoration: BoxDecoration(color: HomeFeedTokens.skeletonBase),
            ),
          ),
          errorWidget: (context, error, stackTrace) => Container(
            color: Colors.grey.shade400,
            alignment: Alignment.center,
            child: Icon(
              Icons.image_not_supported_outlined,
              color: Colors.grey.shade600,
            ),
          ),
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
      height: 56,
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

