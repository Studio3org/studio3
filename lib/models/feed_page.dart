import 'feed_item.dart';
import 'studio_event.dart';

/// Cursor-paginated feed response from `/api/feed/*`.
class FeedPage {
  const FeedPage({
    required this.items,
    this.nextCursor,
    this.stub = false,
    this.event,
    this.upcomingShows = const [],
  });

  final List<FeedItem> items;
  final String? nextCursor;

  /// The home feed's one event card, when the server put one on this page
  /// (`{"type": "event"}`, BACKEND_CHANGES B27). Kept out of [items].
  final StudioEvent? event;

  /// Explore's Upcoming shows (B27): soonest first, each with the pieces on its bill as its
  /// [StudioEvent.lineup]. First page of the whole Explore grid only.
  final List<StudioEvent> upcomingShows;

  /// True when `/api/feed/for-you` is still an explore clone (not personalized).
  final bool stub;

  bool get hasMore => nextCursor != null && nextCursor!.isNotEmpty;
}
