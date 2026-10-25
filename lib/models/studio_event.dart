import 'auction_summary.dart';

/// An event as the server describes it.
///
/// One class for both the card and the detail payload rather than two: a list hands its card
/// straight to the detail page, and the richer fields simply arrive null until that page
/// fetches. Splitting them would mean converting between near-identical types at every
/// navigation.
///
/// Entry is free and open by design. [isFree] is sent by the server rather than assumed here
/// so that when paid ticketing lands it changes in one place — and until then the app should
/// never imply a door charge that does not exist.
class StudioEvent {
  const StudioEvent({
    required this.id,
    required this.title,
    required this.startsAt,
    required this.endsAt,
    this.status = 'published',
    this.category,
    this.coverMediaUrl,
    this.timezoneName,
    this.venueName,
    this.address,
    this.latitude,
    this.longitude,
    this.isFree = true,
    this.hostUsername,
    this.hostName,
    this.hostAvatarUrl,
    this.saved = false,
    this.saveCount = 0,
    this.isHost = false,
    this.capacity,
    this.rsvpCount = 0,
    this.spotsLeft,
    this.isFull = false,
    this.viewerIsGoing = false,
    this.description,
    this.cancellationReason,
    this.cohosts = const [],
    this.artists = const [],
    this.lineup = const [],
  });

  final String id;
  final String title;
  final DateTime startsAt;
  final DateTime endsAt;

  /// `draft` · `published` · `cancelled` · `archived`.
  final String status;
  final String? category;
  final String? coverMediaUrl;

  /// The IANA zone the host chose. An event happens in one place, so its time should read
  /// the same to everyone rather than being shifted into each reader's own zone.
  final String? timezoneName;

  final String? venueName;
  final String? address;
  final double? latitude;
  final double? longitude;
  final bool isFree;

  final String? hostUsername;
  final String? hostName;
  final String? hostAvatarUrl;

  final bool saved;
  final int saveCount;
  final bool isHost;

  /// Null means unlimited, which is the default — entry is free and open.
  final int? capacity;

  /// How many people have said they are coming. A headcount, not ticket sales.
  final int rsvpCount;

  /// Places remaining, or null when the event is uncapped. Null is not zero: an uncapped
  /// event has no number to show, a full one has exactly zero.
  final int? spotsLeft;

  final bool isFull;

  /// Whether the viewer has RSVP'd. Viewer-relative, like [saved].
  final bool viewerIsGoing;

  // --- detail only -------------------------------------------------------------------------
  final String? description;
  final String? cancellationReason;
  final List<EventPerson> cohosts;
  final List<EventPerson> artists;
  final List<EventLineupItem> lineup;

  bool get isDraft => status == 'draft';
  bool get isPublished => status == 'published';
  bool get isCancelled => status == 'cancelled';

  /// Running right now — doors open, and for an event auction, bidding open.
  bool get isHappeningNow {
    final now = DateTime.now();
    return !startsAt.isAfter(now) && endsAt.isAfter(now);
  }

  bool get isOver => !endsAt.isAfter(DateTime.now());

  /// Work on the bill that can actually be bought or bid on, as opposed to merely shown.
  List<EventLineupItem> get sellingLineup =>
      lineup.where((item) => item.isSelling).toList();

  // --- presentation -------------------------------------------------------------------------
  // Kept on the model rather than in each widget so the events tab, the detail page and any
  // future surface phrase an event the same way. The server sends facts; these turn them
  // into the lines the design asks for.

  /// The cover. Empty when the host never set one — callers fall back to their own
  /// placeholder rather than this inventing a URL.
  String get imageUrl => coverMediaUrl ?? '';

  /// The small label above the title: `GALLERY WALK`.
  String get kicker {
    final slug = category;
    if (slug == null || slug.isEmpty) return 'EVENT';
    return slug.replaceAll('_', ' ').toUpperCase();
  }

  String get venue => venueName ?? '';

  /// Always "Free" today. Entry is free and open by design, and [isFree] is what will carry
  /// a real price when paid ticketing lands — so this never hardcodes the word twice.
  String get priceLabel => isFree ? 'Free' : 'Ticketed';

  /// `Cedars Union · Free`, dropping either half when it is missing rather than leaving a
  /// dangling separator.
  String get venueLine {
    final parts = [venue, priceLabel].where((p) => p.isNotEmpty);
    return parts.join(' · ');
  }

  /// Card line: `Sat · 8PM CST`.
  String get whenLabel {
    final zone = _zoneSuffix;
    return '${_weekday(startsAt)} · ${_shortTime(startsAt)}$zone';
  }

  /// Detail line: `Sat, Jul 25 · 8:00 PM – 10:00 PM CST`.
  String get scheduleLine {
    final sameDay = startsAt.year == endsAt.year &&
        startsAt.month == endsAt.month &&
        startsAt.day == endsAt.day;
    final date = '${_weekday(startsAt)}, ${_month(startsAt)} ${startsAt.day}';
    final start = _longTime(startsAt);
    final end = _longTime(endsAt);
    if (sameDay) return '$date · $start – $end$_zoneSuffix';
    final endDate = '${_weekday(endsAt)}, ${_month(endsAt)} ${endsAt.day}';
    return '$date $start – $endDate $end$_zoneSuffix';
  }

  /// The event's own zone, not the reader's. An event happens in one place, and shifting its
  /// time into whatever zone the phone is in makes "8PM" wrong for everyone travelling.
  String get _zoneSuffix {
    final zone = timezoneName;
    if (zone == null || zone.isEmpty) return '';
    // An IANA zone ("America/Chicago") is not something to show a reader; an abbreviation
    // the device already resolved ("CST") is.
    if (zone.contains('/')) return '';
    return ' $zone';
  }

  /// The work on the bill, for the detail page's strip of images.
  List<String> get pieceImageUrls => lineup
      .map((item) => item.mediaUrl ?? '')
      .where((url) => url.isNotEmpty)
      .toList();

  /// The host's own words about the event.
  String get details => description ?? '';

  /// Whether there is a place to point a map at.
  bool get hasLocation => latitude != null && longitude != null;

  /// What the RSVP button should say.
  ///
  /// An RSVP is not a ticket and the copy should never imply one — entry is free and open,
  /// and this only tells the host how many to expect.
  String get rsvpCtaLabel {
    if (viewerIsGoing) return "You're going";
    if (isFull) return 'Event is full';
    return "I'm going";
  }

  /// Whether the RSVP button does anything. A full event that the viewer is not already on
  /// stays visible but inert, so "full" reads as a fact rather than a missing button.
  bool get canRsvp => isPublished && !isOver && !isHost && (viewerIsGoing || !isFull);

  /// The line under the button: `12 going · 8 places left`.
  String get rsvpSummary {
    final going = rsvpCount == 1 ? '1 going' : '$rsvpCount going';
    final left = spotsLeft;
    if (left == null) return going;
    return left == 0 ? '$going · full' : '$going · $left ${left == 1 ? "place" : "places"} left';
  }

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String _weekday(DateTime d) => _weekdays[d.weekday - 1];
  static String _month(DateTime d) => _months[d.month - 1];

  /// `8PM`, or `8:30PM` when it is not on the hour.
  static String _shortTime(DateTime d) {
    final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final suffix = d.hour < 12 ? 'AM' : 'PM';
    return d.minute == 0
        ? '$hour$suffix'
        : '$hour:${d.minute.toString().padLeft(2, '0')}$suffix';
  }

  /// `8:00 PM`.
  static String _longTime(DateTime d) {
    final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final suffix = d.hour < 12 ? 'AM' : 'PM';
    return '$hour:${d.minute.toString().padLeft(2, '0')} $suffix';
  }

  StudioEvent copyWith({
    bool? saved,
    int? saveCount,
    String? status,
    int? rsvpCount,
    int? spotsLeft,
    bool? isFull,
    bool? viewerIsGoing,
  }) =>
      StudioEvent(
        id: id,
        title: title,
        startsAt: startsAt,
        endsAt: endsAt,
        status: status ?? this.status,
        category: category,
        coverMediaUrl: coverMediaUrl,
        timezoneName: timezoneName,
        venueName: venueName,
        address: address,
        latitude: latitude,
        longitude: longitude,
        isFree: isFree,
        hostUsername: hostUsername,
        hostName: hostName,
        hostAvatarUrl: hostAvatarUrl,
        saved: saved ?? this.saved,
        saveCount: saveCount ?? this.saveCount,
        isHost: isHost,
        capacity: capacity,
        rsvpCount: rsvpCount ?? this.rsvpCount,
        spotsLeft: spotsLeft ?? this.spotsLeft,
        isFull: isFull ?? this.isFull,
        viewerIsGoing: viewerIsGoing ?? this.viewerIsGoing,
        description: description,
        cancellationReason: cancellationReason,
        cohosts: cohosts,
        artists: artists,
        lineup: lineup,
      );

  /// Enough to render a saved-events tile offline.
  ///
  /// Deliberately partial: the bill, the cohosts and the save count are all live facts that
  /// go stale the moment they are written to disk, and a cached copy claiming an event still
  /// has four works on it would be worse than re-fetching.
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'startsAt': startsAt.toUtc().toIso8601String(),
        'endsAt': endsAt.toUtc().toIso8601String(),
        'status': status,
        if (category != null) 'category': category,
        if (coverMediaUrl != null) 'coverMediaUrl': coverMediaUrl,
        if (timezoneName != null) 'timezone': timezoneName,
        if (venueName != null) 'venueName': venueName,
        if (address != null) 'address': address,
        'isFree': isFree,
        if (hostUsername != null) 'hostUsername': hostUsername,
        if (hostName != null) 'hostName': hostName,
        if (hostAvatarUrl != null) 'hostAvatarUrl': hostAvatarUrl,
        'saved': saved,
      };

  factory StudioEvent.fromJson(Map<String, dynamic> json) {
    DateTime dateOf(String key) =>
        DateTime.tryParse(json[key] as String? ?? '')?.toLocal() ?? DateTime.now();

    return StudioEvent(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      startsAt: dateOf('startsAt'),
      endsAt: dateOf('endsAt'),
      status: json['status'] as String? ?? 'published',
      category: json['category'] as String?,
      coverMediaUrl: json['coverMediaUrl'] as String?,
      timezoneName: json['timezone'] as String?,
      venueName: json['venueName'] as String?,
      address: json['address'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      isFree: json['isFree'] as bool? ?? true,
      hostUsername: json['hostUsername'] as String?,
      hostName: json['hostName'] as String?,
      hostAvatarUrl: json['hostAvatarUrl'] as String?,
      saved: json['saved'] as bool? ?? false,
      saveCount: (json['saveCount'] as num?)?.toInt() ?? 0,
      isHost: json['isHost'] as bool? ?? false,
      capacity: (json['capacity'] as num?)?.toInt(),
      rsvpCount: (json['rsvpCount'] as num?)?.toInt() ?? 0,
      spotsLeft: (json['spotsLeft'] as num?)?.toInt(),
      isFull: json['isFull'] as bool? ?? false,
      viewerIsGoing: json['viewerIsGoing'] as bool? ?? false,
      description: json['description'] as String?,
      cancellationReason: json['cancellationReason'] as String?,
      cohosts: _people(json['cohosts']),
      artists: _people(json['artists']),
      lineup: (json['lineup'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(EventLineupItem.fromJson)
              .toList() ??
          const [],
    );
  }

  static List<EventPerson> _people(Object? raw) =>
      (raw as List?)
          ?.whereType<Map<String, dynamic>>()
          .map(EventPerson.fromJson)
          .toList() ??
      const [];
}

/// A cohost or a credited artist.
///
/// A credit, not a permission: being on the bill does not let a host sell this person's work
/// or end their listings, and does not let this person edit the event.
class EventPerson {
  const EventPerson({required this.username, this.name, this.avatarUrl});

  final String username;
  final String? name;
  final String? avatarUrl;

  String get displayName => (name?.isNotEmpty ?? false) ? name! : username;
  String get handle => '@$username';

  factory EventPerson.fromJson(Map<String, dynamic> json) => EventPerson(
        username: json['username'] as String? ?? '',
        name: json['name'] as String?,
        avatarUrl: json['avatarUrl'] as String?,
      );
}

/// One work on the bill, and how it appears at this event.
class EventLineupItem {
  const EventLineupItem({
    required this.id,
    required this.pieceId,
    required this.mode,
    this.priceCents,
    this.deliveryMode,
    this.title,
    this.mediaUrl,
    this.artistUsername,
    this.artistName,
    this.pieceStatus,
    this.auction,
  });

  final String id;
  final String pieceId;

  /// `featured` (shown only) · `sale` (fixed price) · `bid` (auctioned in the room).
  final String mode;

  /// The fixed price for a sale, the starting bid for an auction — the artist's asking
  /// number either way.
  final int? priceCents;

  /// `pickup` is the norm at an event: the work changes hands in the room.
  final String? deliveryMode;

  final String? title;
  final String? mediaUrl;
  final String? artistUsername;
  final String? artistName;
  final String? pieceStatus;

  /// Live auction state, on `bid` entries only.
  ///
  /// Present so the room's own screen can show what each work is actually at. Without it a
  /// lineup could only show the starting price, which stops being true the moment somebody
  /// bids — and the screen in the room would be the least current thing in it.
  final AuctionSummary? auction;

  bool get isSelling => mode == 'sale' || mode == 'bid';
  bool get isAuction => mode == 'bid';
  bool get isPickup => deliveryMode == 'pickup';

  String? get priceLabel {
    final cents = priceCents;
    if (cents == null) return null;
    final amount = cents / 100;
    final text = amount == amount.roundToDouble()
        ? amount.toStringAsFixed(0)
        : amount.toStringAsFixed(2);
    return '\$$text';
  }

  /// What to show as this work's headline figure right now.
  ///
  /// The live high bid once there is one, otherwise the asking price. Falling back the other
  /// way would show a starting bid on a piece that has already been bid past.
  int? get currentCents => auction?.highestBidCents ?? priceCents;

  /// Bidding is open on this work at this moment.
  bool get isBiddingOpen => auction?.isOpenForBidding ?? false;

  /// The label under the work in the room: `12 bids` / `Starting bid` / `Sold`.
  String get statusLine {
    if (mode != 'bid') {
      return mode == 'sale' ? 'For sale' : 'On show';
    }
    final live = auction;
    if (live == null) return 'Auction';
    if (live.isClosed) {
      return live.winningBidCents != null ? 'Sold' : 'Auction ended';
    }
    final count = live.bidCount;
    if (count == 0) return 'Starting bid';
    return count == 1 ? '1 bid' : '$count bids';
  }

  factory EventLineupItem.fromJson(Map<String, dynamic> json) => EventLineupItem(
        id: json['id'] as String? ?? '',
        pieceId: json['pieceId'] as String? ?? '',
        mode: json['mode'] as String? ?? 'featured',
        priceCents: (json['priceCents'] as num?)?.toInt(),
        deliveryMode: json['deliveryMode'] as String?,
        title: json['title'] as String?,
        mediaUrl: json['mediaUrl'] as String?,
        artistUsername: json['artistUsername'] as String?,
        artistName: json['artistName'] as String?,
        pieceStatus: json['pieceStatus'] as String?,
        auction: json['auction'] is Map<String, dynamic>
            ? AuctionSummary.maybeFrom(json['auction'] as Map<String, dynamic>)
            : null,
      );
}

/// What adding a piece to a bill would end, so the host is told before it happens.
///
/// Tagging a piece for sale at an event closes whatever listing it already had — and if that
/// was a running auction, every bidder's hold is released and they are notified. That is
/// irreversible, so the create flow asks first with real numbers.
class EventTaggingPreview {
  const EventTaggingPreview({
    required this.endsAuction,
    required this.endsFixedListing,
    required this.activeBidCount,
    required this.ownedByViewer,
  });

  final bool endsAuction;
  final bool endsFixedListing;
  final int activeBidCount;
  final bool ownedByViewer;

  bool get endsSomething => endsAuction || endsFixedListing;

  factory EventTaggingPreview.fromJson(Map<String, dynamic> json) => EventTaggingPreview(
        endsAuction: json['endsAuction'] as bool? ?? false,
        endsFixedListing: json['endsFixedListing'] as bool? ?? false,
        activeBidCount: (json['activeBidCount'] as num?)?.toInt() ?? 0,
        ownedByViewer: json['ownedByViewer'] as bool? ?? false,
      );
}

/// The events tab in one payload — what's on today, from people you follow, and everything
/// coming up. One round trip rather than four, because the tab shows all of them at once.
class EventBrowse {
  const EventBrowse({
    this.today = const [],
    this.following = const [],
    this.upcoming = const [],
    this.categories = const [],
  });

  final List<StudioEvent> today;
  final List<StudioEvent> following;
  final List<StudioEvent> upcoming;
  final List<EventCategoryCount> categories;

  bool get isEmpty =>
      today.isEmpty && following.isEmpty && upcoming.isEmpty;

  factory EventBrowse.fromJson(Map<String, dynamic> json) {
    List<StudioEvent> events(String key) =>
        (json[key] as List?)
            ?.whereType<Map<String, dynamic>>()
            .map(StudioEvent.fromJson)
            .toList() ??
        const [];

    return EventBrowse(
      today: events('today'),
      following: events('following'),
      upcoming: events('upcoming'),
      categories: (json['categories'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(EventCategoryCount.fromJson)
              .toList() ??
          const [],
    );
  }
}

class EventCategoryCount {
  const EventCategoryCount({
    required this.id,
    required this.upcomingCount,
    this.coverMediaUrl,
  });

  final String id;
  final int upcomingCount;

  /// Borrowed from the soonest upcoming event in this category, so the tile always shows
  /// something actually happening rather than a fixed stock image.
  final String? coverMediaUrl;

  String get imageUrl => coverMediaUrl ?? '';

  /// `gallery_walk` → `Gallery Walks`.
  String get title {
    final words = id.split('_').where((w) => w.isNotEmpty);
    final titled = words.map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');
    return titled.endsWith('s') ? titled : '${titled}s';
  }

  String get upcomingLabel => '$upcomingCount upcoming';

  factory EventCategoryCount.fromJson(Map<String, dynamic> json) => EventCategoryCount(
        id: json['id'] as String? ?? '',
        upcomingCount: (json['upcomingCount'] as num?)?.toInt() ?? 0,
        coverMediaUrl: json['coverMediaUrl'] as String?,
      );
}


/// The counts that come back from an RSVP, so a screen can update without re-fetching.
class EventRsvpResult {
  const EventRsvpResult({
    required this.going,
    required this.rsvpCount,
    this.spotsLeft,
    this.isFull = false,
  });

  final bool going;
  final int rsvpCount;

  /// Null when the event is uncapped.
  final int? spotsLeft;
  final bool isFull;

  factory EventRsvpResult.fromJson(Map<String, dynamic> json) => EventRsvpResult(
        going: json['going'] as bool? ?? false,
        rsvpCount: (json['rsvpCount'] as num?)?.toInt() ?? 0,
        spotsLeft: (json['spotsLeft'] as num?)?.toInt(),
        isFull: json['isFull'] as bool? ?? false,
      );
}
