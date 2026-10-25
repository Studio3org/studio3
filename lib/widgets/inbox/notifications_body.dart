import 'package:flutter/material.dart';

import '../../models/feed_item.dart';
import '../../models/feed_preview_item.dart';
import '../../models/notification_item.dart';
import '../../screens/auction_flow.dart';
import '../../services/chat_socket_service.dart';
import '../../services/connectivity_service.dart';
import '../../services/main_nav_service.dart';
import '../../services/notification_service.dart';
import '../../services/order_service.dart';
import '../../services/piece_service.dart';
import '../../services/post_service.dart';
import '../../theme/studio_colors.dart';
import '../../theme/studio_type.dart';
import '../../utils/explore_detail_route.dart';
import '../../utils/profile_navigation.dart';
import '../feed_skeleton.dart';
import '../home_feed/home_feed_widgets.dart';
import '../offline_state.dart';
import '../studio/studio_avatar.dart';
import '../studio/studio_empty_state.dart';

/// The Inbox's Activity tab (`NotifActivity`, with the in-app looks of `NotifCatalog`).
///
/// Grouped Today / This week / Earlier under Mono labels. Each row: a piece (40 × 53) or a
/// person (40 round), the line (unread 500 Ink; read 400 grey with names and titles 500
/// Ink), a status word where the catalog gives one (Outbid / Ending soon red, Now listed
/// green), the time in Mono, and for a like, save or comment the piece on the right.
/// Tapping a row marks it read and opens the piece, Scene, profile or order.
class NotificationsBody extends StatefulWidget {
  const NotificationsBody({super.key, this.onLiveNotification, this.debugItems});

  /// Fired when a live `notification:new` arrives (so parent can bump badge).
  final VoidCallback? onLiveNotification;

  /// Rows to show instead of loading them, for tests.
  @visibleForTesting
  final List<NotificationItem>? debugItems;

  @override
  State<NotificationsBody> createState() => NotificationsBodyState();
}

class NotificationsBodyState extends State<NotificationsBody> {
  final List<NotificationItem> _items = [];
  bool _loading = true;
  bool _loadingMore = false;
  String? _nextCursor;
  final _scrollController = ScrollController();

  bool _showOfflineState = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    final debug = widget.debugItems;
    if (debug != null) {
      _items.addAll(debug);
      _loading = false;
      return;
    }
    ConnectivityService.instance.addReconnectHook(_onReconnected);
    ChatSocketService.instance.onNotificationNew(_onSocketNotification);
    _load();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    if (widget.debugItems == null) {
      ConnectivityService.instance.removeReconnectHook(_onReconnected);
      ChatSocketService.instance.offNotificationNew(_onSocketNotification);
    }
    super.dispose();
  }

  void _onSocketNotification(Map<String, dynamic> json) {
    final item = NotificationItem.fromJson(json);
    if (item.isInquiry || item.isChatMessage) return;
    if (!mounted) return;
    if (_items.any((n) => n.id == item.id)) return;
    setState(() => _items.insert(0, item));
    widget.onLiveNotification?.call();
    NotificationService.instance.invalidateUnreadCache();
  }

  Future<void> _onReconnected() => _load(refresh: true);

  Future<void> _load({bool append = false, bool refresh = false}) async {
    if (append && (_nextCursor == null || _nextCursor!.isEmpty)) return;
    setState(() {
      if (append) {
        _loadingMore = true;
      } else {
        _loading = true;
      }
    });
    try {
      final page = append
          ? await NotificationService.instance.list(cursor: _nextCursor)
          : await NotificationService.instance.listCached(forceRefresh: refresh);
      if (!mounted) return;
      // Chat DMs (`message` / legacy `inquiry`) surface as phone push + the Messages tab
      // count — not in Activity.
      final items = page.items.where((n) => !n.isInquiry && !n.isChatMessage);
      setState(() {
        if (append) {
          _items.addAll(items);
        } else {
          _items
            ..clear()
            ..addAll(items);
        }
        _nextCursor = page.nextCursor;
        _loading = false;
        _loadingMore = false;
        _showOfflineState = _items.isEmpty && !ConnectivityService.instance.isOnline;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (!append) _items.clear();
        _loading = false;
        _loadingMore = false;
        _showOfflineState = _items.isEmpty && !ConnectivityService.instance.isOnline;
      });
    }
  }

  void _onScroll() {
    if (_loadingMore) return;
    if (_nextCursor == null || _nextCursor!.isEmpty) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 200) {
      _load(append: true);
    }
  }

  Future<void> _onTap(NotificationItem item) async {
    if (!item.read) {
      setState(() {
        final index = _items.indexWhere((n) => n.id == item.id);
        if (index != -1) _items[index] = item.copyWith(read: true);
      });
      NotificationService.instance.markRead(item.id).catchError((_) {
        // Keep the optimistic read state even if the request fails.
      });
    }
    await openNotificationTarget(context, item);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    if (_showOfflineState) {
      return OfflineState(onRetry: () => _load(refresh: true));
    }
    if (_loading && _items.isEmpty) {
      return const FlatListRowSkeleton();
    }
    if (_items.isEmpty) {
      // `NotifEmptyActivity`: usually a brand-new account. Explore art opens Explore.
      return RefreshIndicator(
        color: c.textPrimary,
        onRefresh: () => _load(refresh: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: 200, bottom: 40),
          children: [
            StudioEmptyState(
              title: 'Nothing here yet',
              message: 'Follow artists and save pieces. News about them shows up here.',
              actionLabel: 'Explore art',
              onAction: () => MainNavService.instance.goExplore(),
            ),
          ],
        ),
      );
    }

    final now = DateTime.now();
    final groups = <String, List<NotificationItem>>{
      'Today': [],
      'This week': [],
      'Earlier': [],
    };
    for (final item in _items) {
      groups[activityGroup(item.createdAt, now)]!.add(item);
    }

    return RefreshIndicator(
      color: c.textPrimary,
      onRefresh: () => _load(refresh: true),
      child: ListView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          for (final entry in groups.entries)
            if (entry.value.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(top: 18, bottom: 2),
                child: Text(
                  entry.key.toUpperCase(),
                  style: StudioType.mono(
                    11,
                    weight: StudioType.medium,
                    color: c.textTertiary,
                  ).copyWith(letterSpacing: 0.5),
                ),
              ),
              for (final item in entry.value)
                ActivityRow(item: item, now: now, onTap: () => _onTap(item)),
            ],
          if (_loadingMore)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: c.textSecondary),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Today (same calendar day), This week (the last 7 days) or Earlier.
String activityGroup(DateTime at, DateTime now) {
  final local = at.toLocal();
  final today = DateTime(now.year, now.month, now.day);
  if (!local.isBefore(today)) return 'Today';
  if (now.difference(local) < const Duration(days: 7)) return 'This week';
  return 'Earlier';
}

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "now", "12m", "4h" today; the weekday this week; "Oct 12" before that.
String activityTime(DateTime at, DateTime now) {
  final local = at.toLocal();
  switch (activityGroup(at, now)) {
    case 'Today':
      final diff = now.difference(local);
      if (diff.inMinutes < 1) return 'now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m';
      return '${diff.inHours}h';
    case 'This week':
      return _weekdays[local.weekday - 1];
    default:
      return '${_months[local.month - 1]} ${local.day}';
  }
}

/// How a notification looks in the app (`NotifCatalog` "How it looks inside the app").
enum _Lead { piece, person }

class _Look {
  const _Look({required this.lead, this.status, this.trailingPiece = false});

  final _Lead lead;
  final String? status;
  final bool trailingPiece;
}

_Look _lookFor(NotificationItem n) {
  switch (n.type) {
    case 'follow':
    case 'follow_request':
      return const _Look(lead: _Lead.person);
    case 'like':
    case 'save':
    case 'comment':
      return _Look(lead: _Lead.person, trailingPiece: n.targetId != null);
    case 'outbid':
    case 'bid_hold_expired':
      return const _Look(lead: _Lead.piece, status: 'Outbid');
    case 'auction_ending_soon':
    case 'ending_soon':
      return const _Look(lead: _Lead.piece, status: 'Ending soon');
    case 'now_listed':
      return const _Look(lead: _Lead.piece, status: 'Now listed');
    default:
      // Purchases, orders and auctions are about a piece; anything else about a person.
      final pieceLed = n.targetType == 'piece' || n.targetType == 'order';
      return _Look(lead: pieceLed ? _Lead.piece : _Lead.person);
  }
}

/// The line, as spans: names and titles are the bold parts.
List<(String, bool)> activityLine(NotificationItem n) {
  final name = n.actorDisplayName;
  final what = n.targetType == 'post' ? 'Scene' : 'piece';
  final title = n.payload['pieceTitle'] as String?;
  switch (n.type) {
    case 'follow':
      return n.payload['accepted'] == true
          ? [(name, true), (' accepted your follow request.', false)]
          : [(name, true), (' followed you.', false)];
    case 'follow_request':
      return [(name, true), (' asked to follow you.', false)];
    case 'like':
    case 'save':
      final verb = n.type == 'like' ? 'liked' : 'saved';
      // The title comes once the server adds it to the payload (BACKEND_CHANGES B6).
      return title == null
          ? [(name, true), (' $verb your $what.', false)]
          : [(name, true), (' $verb your $what ', false), (title, true), ('.', false)];
    case 'comment':
      final preview = (n.payload['commentPreview'] as String?)?.trim();
      return preview == null || preview.isEmpty
          ? [(name, true), (' commented on your $what.', false)]
          : [(name, true), (' commented: “$preview”', false)];
    case 'purchase':
      if (n.payload.containsKey('totalCents')) {
        return title == null
            ? [(name, true), (' collected a piece of yours.', false)]
            : [(name, true), (' collected ', false), (title, true), ('.', false)];
      }
      return title == null
          ? [('Your order is confirmed.', false)]
          : [('Your order ', false), (title, true), (' is confirmed.', false)];
    default:
      final text = n.message?.trim();
      return [(text == null || text.isEmpty ? 'You have a new update.' : text, false)];
  }
}

/// Opens what a notification is about: the piece or Scene, the person, or the order list
/// (My sales for the seller). Event reminders have nowhere to go yet (no events in the app).
/// Notifications that open an auction result (`BidWon`, `BidLost`, `BidReserveNotMet`,
/// `BidPaymentFailed`) instead of the piece.
const kAuctionOutcomeTypes = {
  'auction_won',
  'auction_lost',
  'auction_no_sale',
  'auction_payment_failed',
};

Future<void> openNotificationTarget(BuildContext context, NotificationItem n) async {
  final id = n.targetId;
  try {
    switch (n.targetType) {
      case 'piece' when id != null && kAuctionOutcomeTypes.contains(n.type):
        await openAuctionOutcome(context, pieceId: id, type: n.type);
      case 'piece':
        if (id == null) return;
        final piece = await PieceService.instance.getByIdCached(id);
        if (!context.mounted) return;
        await openPieceDetailPreview(context, FeedPreviewItem.fromPieceSummary(piece));
      case 'post':
        if (id == null) return;
        final post = await PostService.instance.getById(id);
        if (!context.mounted) return;
        await openExploreDetail(context, FeedItem.post(post));
      case 'order':
        final seller = n.payload.containsKey('totalCents') ||
            (n.message ?? '').contains('your sale') ||
            n.payload.containsKey('reason');
        await Navigator.of(context).pushNamed(seller ? '/sales' : '/orders');
      case 'user':
        openUserProfile(context, n.actorUsername);
      default:
        if (n.actorUsername != null && (n.type == 'follow' || n.type == 'follow_request')) {
          openUserProfile(context, n.actorUsername);
        }
    }
  } catch (_) {
    // The piece or Scene may be gone; the row stays read.
  }
}

/// Resolves the picture for a row's piece: the piece itself, a Scene's media, or an order's
/// first piece. Cached for the session; null when there is none.
abstract final class ActivityThumbs {
  static final Map<String, Future<String?>> _cache = {};

  static Future<String?> forItem(NotificationItem n) {
    // Sent with the notification once the server has BACKEND_CHANGES B6.
    final given = (n.payload['pieceImageUrl'] ?? n.payload['postImageUrl']) as String?;
    if (given != null && given.isNotEmpty) return Future.value(given);
    final id = n.targetId;
    final type = n.targetType;
    if (id == null || type == null) return Future.value(null);
    return _cache.putIfAbsent('$type:$id', () => _resolve(type, id));
  }

  static Future<String?> _resolve(String type, String id) async {
    try {
      switch (type) {
        case 'piece':
          return (await PieceService.instance.getByIdCached(id)).mediaUrl;
        case 'post':
          final post = await PostService.instance.getById(id);
          return post.thumbnailUrl ?? post.mediaUrl;
        case 'order':
          final order = await OrderService.instance.getOrder(id);
          if (order.items.isEmpty) return null;
          return (await PieceService.instance.getByIdCached(order.items.first.pieceId)).mediaUrl;
      }
    } catch (_) {}
    return null;
  }
}

/// One Activity row: 12 vertical padding, 12 gap, 1 px Line under.
class ActivityRow extends StatelessWidget {
  const ActivityRow({super.key, required this.item, required this.now, required this.onTap});

  final NotificationItem item;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final look = _lookFor(item);
    final unread = !item.read;
    final base = StudioType.body14(
      height: 1.4,
      weight: unread ? StudioType.medium : StudioType.regular,
      color: unread ? c.textPrimary : c.textSecondary,
    );
    final bold = TextStyle(fontWeight: StudioType.medium, color: c.textPrimary);
    final status = look.status;
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
          child: Row(
            children: [
              if (look.lead == _Lead.piece)
                _PieceThumb(item: item, width: 40, height: 53)
              else
                StudioAvatar(url: item.actorAvatarUrl, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (status != null) ...[
                      Text(
                        status,
                        style: StudioType.caption12(
                          color: status == 'Now listed' ? c.positive : c.alert,
                        ).copyWith(fontWeight: StudioType.medium),
                      ),
                      const SizedBox(height: 3),
                    ],
                    Text.rich(
                      TextSpan(
                        children: [
                          for (final (text, strong) in activityLine(item))
                            TextSpan(text: text, style: strong ? bold : null),
                        ],
                      ),
                      style: base,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      activityTime(item.createdAt, now),
                      style: StudioType.mono11(color: c.textTertiary),
                    ),
                  ],
                ),
              ),
              if (look.trailingPiece) ...[
                const SizedBox(width: 12),
                _PieceThumb(item: item, width: 34, height: 45),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The row's piece, radius 6, Surface until (or unless) its picture is known.
class _PieceThumb extends StatelessWidget {
  const _PieceThumb({required this.item, required this.width, required this.height});

  final NotificationItem item;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: width,
        height: height,
        child: FutureBuilder<String?>(
          future: ActivityThumbs.forItem(item),
          builder: (context, snap) {
            final url = snap.data;
            if (url == null || url.isEmpty) return ColoredBox(color: c.surface);
            return FeedPicsumImage(url: url);
          },
        ),
      ),
    );
  }
}
