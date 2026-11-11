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
    this.city,
    this.featured = false,
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
    this.hostIsFollowing,
    this.hostFollowRequested,
    this.description,
    this.cancellationReason,
    this.cohosts = const [],
    this.artists = const [],
    this.lineup = const [],
    this.faqs = const [],
    this.ticketTypes = const [],
    this.waitlist,
    this.ticketCount = 0,
    this.refundPolicy,
    this.refundPolicyText,
    this.refundableUntil,
    this.ageLimit,
    this.visibility,
    this.rescheduledAt,
    this.rescheduleMessage,
    this.auctionEndsAt,
    this.invites = const [],
    this.viewerInvite,
    this.viewerCanEdit = false,
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

  /// The town, read from the address by the server (BACKEND_CHANGES B23), for "Near me".
  final String? city;

  /// The team's pick for the Events tab's Featured slot (B23).
  final bool featured;
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

  /// Whether the signed-in viewer follows the host, or has asked to (BACKEND_CHANGES B24).
  /// Null when the payload doesn't say: a card, a guest, or a server without B24.
  final bool? hostIsFollowing;
  final bool? hostFollowRequested;

  final String? description;
  final String? cancellationReason;
  final List<EventPerson> cohosts;
  final List<EventPerson> artists;
  final List<EventLineupItem> lineup;

  /// The host's questions and answers (`EvDetail` FAQs), in the host's order (BACKEND_CHANGES
  /// B24); empty when there are none.
  final List<EventFaq> faqs;

  /// The host's ticket types (`EvChooseTickets`). Not sent by the server yet (BACKEND_CHANGES
  /// B22); see [ticketOptions] for what the sheet shows until then.
  final List<EventTicketType> ticketTypes;

  /// How many tickets the viewer holds (`EvMyTickets` "2 tickets"). 0 for an RSVP, which has
  /// no ticket codes (BACKEND_CHANGES B22).
  final int ticketCount;

  /// The waitlist on a sold-out event (`EvSoldOut`, `EvWaitlistJoin`, `EvWaitlistHeld`). Null
  /// until the server runs one (BACKEND_CHANGES B22); the page then keeps the Save bar.
  final EventWaitlist? waitlist;

  /// The host's refund terms: `7d` · `24h` · `none` (BACKEND_CHANGES B22). Null on an older
  /// server or a card.
  final String? refundPolicy;

  /// The refund terms in one line: "Refunds up to 7 days before the event."
  final String? refundPolicyText;

  /// Until when a ticket can be refunded, when the server says.
  final DateTime? refundableUntil;

  /// `all` · `18` · `21` (B28). Null on an older server.
  final String? ageLimit;

  /// `public` · `link` (link-only events stay out of browse, search and feeds). Null on an
  /// older server, which treats every event as public.
  final String? visibility;

  /// When the host last moved the event (Phase 4); null if it never moved.
  final DateTime? rescheduledAt;

  /// The host's note about the move, when there is one.
  final String? rescheduleMessage;

  /// When bidding on the event's auctions ends, when the host set it (Phase 5).
  final DateTime? auctionEndsAt;

  /// Everyone asked onto the bill with where they stand (`invited` · `accepted` ·
  /// `declined`), Phase 5.1. Only the host and accepted co-hosts get it; empty otherwise.
  final List<EventInvite> invites;

  /// The viewer's own invite to this event, when they were ever asked. Stays after an
  /// answer, so a declined invite reads `declined`.
  final EventViewerInvite? viewerInvite;

  /// True for the host and accepted co-hosts (Phase 5.1): they can edit the event.
  final bool viewerCanEdit;

  /// The host or an accepted co-host: can open Manage and edit the event.
  bool get canManage => isHost || viewerCanEdit;

  /// The viewer was asked onto the bill and hasn't answered yet.
  bool get hasPendingInvite => viewerInvite?.status == 'invited';

  /// The bill as everyone sees it: approved pieces only. Waiting and declined entries reach
  /// the host, co-hosts and the piece's artist, but aren't on the event yet (Phase 5.2).
  List<EventLineupItem> get liveLineup => lineup.where((item) => item.isLive).toList();

  /// Whether the event is link-only (not listed in browse, search or feeds).
  bool get isLinkOnly => visibility == 'link';

  /// What Choose tickets offers: the host's ticket types, or, while every event is a free
  /// RSVP, one free General Admission place per person with the places left as its count.
  List<EventTicketType> get ticketOptions => ticketTypes.isNotEmpty
      ? ticketTypes
      : [
          EventTicketType(
            // An RSVP, never an order item (`EventService.rsvpTypeId`).
            id: 'rsvp',
            name: 'General Admission',
            includes: 'Open to everyone',
            left: isFull ? 0 : spotsLeft,
            perOrderLimit: 1,
          ),
        ];

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
      lineup.where((item) => item.isSelling && item.isLive).toList();

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

  /// Detail line: `Sat, Jul 25 · 8:00 – 10:00 PM CST` (`EvDetail`); the first AM / PM is left out
  /// when both times share it.
  String get scheduleLine {
    final sameDay = startsAt.year == endsAt.year &&
        startsAt.month == endsAt.month &&
        startsAt.day == endsAt.day;
    final date = '${_weekday(startsAt)}, ${_month(startsAt)} ${startsAt.day}';
    final end = _longTime(endsAt);
    final sameHalf = (startsAt.hour < 12) == (endsAt.hour < 12);
    final start = sameDay && sameHalf ? _longTime(startsAt).split(' ').first : _longTime(startsAt);
    if (sameDay) return '$date · $start – $end$_zoneSuffix';
    final endDate = '${_weekday(endsAt)}, ${_month(endsAt)} ${endsAt.day}';
    return '$date $start – $endDate $end$_zoneSuffix';
  }

  /// "CST" (the event's own zone), or empty when only an IANA name is known.
  String get zoneLabel => _zoneSuffix.trim();

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
  List<String> get pieceImageUrls => liveLineup
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
    EventWaitlist? waitlist,
    List<EventTicketType>? ticketTypes,
    int? ticketCount,
    DateTime? rescheduledAt,
    String? rescheduleMessage,
    List<EventInvite>? invites,
    EventViewerInvite? viewerInvite,
    bool? viewerCanEdit,
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
        city: city,
        featured: featured,
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
        hostIsFollowing: hostIsFollowing,
        hostFollowRequested: hostFollowRequested,
        description: description,
        cancellationReason: cancellationReason,
        cohosts: cohosts,
        artists: artists,
        lineup: lineup,
        faqs: faqs,
        ticketTypes: ticketTypes ?? this.ticketTypes,
        ticketCount: ticketCount ?? this.ticketCount,
        waitlist: waitlist ?? this.waitlist,
        refundPolicy: refundPolicy,
        refundPolicyText: refundPolicyText,
        refundableUntil: refundableUntil,
        ageLimit: ageLimit,
        visibility: visibility,
        rescheduledAt: rescheduledAt ?? this.rescheduledAt,
        rescheduleMessage: rescheduleMessage ?? this.rescheduleMessage,
        auctionEndsAt: auctionEndsAt,
        invites: invites ?? this.invites,
        viewerInvite: viewerInvite ?? this.viewerInvite,
        viewerCanEdit: viewerCanEdit ?? this.viewerCanEdit,
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
        if (city != null) 'city': city,
        if (featured) 'featured': featured,
        'isFree': isFree,
        if (hostUsername != null) 'hostUsername': hostUsername,
        if (hostName != null) 'hostName': hostName,
        if (hostAvatarUrl != null) 'hostAvatarUrl': hostAvatarUrl,
        'saved': saved,
        if (ageLimit != null) 'ageLimit': ageLimit,
        if (visibility != null) 'visibility': visibility,
        if (refundPolicy != null) 'refundPolicy': refundPolicy,
        if (refundPolicyText != null) 'refundPolicyText': refundPolicyText,
        if (refundableUntil != null) 'refundableUntil': refundableUntil!.toUtc().toIso8601String(),
        if (rescheduledAt != null) 'rescheduledAt': rescheduledAt!.toUtc().toIso8601String(),
        if (rescheduleMessage != null) 'rescheduleMessage': rescheduleMessage,
        if (auctionEndsAt != null) 'auctionEndsAt': auctionEndsAt!.toUtc().toIso8601String(),
        if (invites.isNotEmpty) 'invites': [for (final i in invites) i.toJson()],
        if (viewerInvite != null) 'viewerInvite': viewerInvite!.toJson(),
        if (viewerCanEdit) 'viewerCanEdit': viewerCanEdit,
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
      city: json['city'] as String?,
      featured: json['featured'] as bool? ?? false,
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
      hostIsFollowing: json['hostIsFollowing'] as bool?,
      hostFollowRequested: json['hostFollowRequested'] as bool?,
      description: json['description'] as String?,
      cancellationReason: json['cancellationReason'] as String?,
      cohosts: _people(json['cohosts']),
      artists: _people(json['artists']),
      lineup: (json['lineup'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(EventLineupItem.fromJson)
              .toList() ??
          const [],
      faqs: (json['faqs'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(EventFaq.fromJson)
              .where((f) => f.question.isNotEmpty)
              .toList() ??
          const [],
      ticketCount: (json['ticketCount'] as num?)?.toInt() ?? 0,
      ticketTypes: (json['ticketTypes'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(EventTicketType.fromJson)
              .toList() ??
          const [],
      waitlist: json['waitlist'] is Map<String, dynamic>
          ? EventWaitlist.fromJson(json['waitlist'] as Map<String, dynamic>)
          : null,
      refundPolicy: json['refundPolicy'] as String?,
      refundPolicyText: json['refundPolicyText'] as String?,
      refundableUntil: _date(json['refundableUntil']),
      ageLimit: json['ageLimit'] as String?,
      visibility: json['visibility'] as String?,
      rescheduledAt: _date(json['rescheduledAt']),
      rescheduleMessage: json['rescheduleMessage'] as String?,
      auctionEndsAt: _date(json['auctionEndsAt']),
      invites: (json['invites'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(EventInvite.fromJson)
              .where((i) => i.username.isNotEmpty)
              .toList() ??
          const [],
      viewerInvite: json['viewerInvite'] is Map<String, dynamic>
          ? EventViewerInvite.fromJson(json['viewerInvite'] as Map<String, dynamic>)
          : null,
      viewerCanEdit: json['viewerCanEdit'] as bool? ?? false,
    );
  }

  static DateTime? _date(Object? raw) =>
      raw is String ? DateTime.tryParse(raw)?.toLocal() : null;

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

/// Someone asked onto the bill as a co-host or featured artist, with their answer (Phase 5.1).
class EventInvite {
  const EventInvite({
    required this.username,
    this.name,
    this.avatarUrl,
    this.role = 'artist',
    this.status = 'invited',
  });

  final String username;
  final String? name;
  final String? avatarUrl;

  /// `cohost` · `artist`.
  final String role;

  /// `invited` · `accepted` · `declined`.
  final String status;

  bool get isCohost => role == 'cohost';
  bool get isDeclined => status == 'declined';

  /// "Invited" / "Accepted" / "Declined".
  String get statusLabel => switch (status) {
        'accepted' => 'Accepted',
        'declined' => 'Declined',
        _ => 'Invited',
      };

  EventPerson get person => EventPerson(username: username, name: name, avatarUrl: avatarUrl);

  factory EventInvite.fromJson(Map<String, dynamic> json) => EventInvite(
        username: json['username'] as String? ?? '',
        name: json['name'] as String?,
        avatarUrl: json['avatarUrl'] as String?,
        role: json['role'] as String? ?? 'artist',
        status: json['status'] as String? ?? 'invited',
      );

  Map<String, dynamic> toJson() => {
        'username': username,
        if (name != null) 'name': name,
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
        'role': role,
        'status': status,
      };
}

/// The viewer's own invite to an event: which roles they were asked for and their answer.
class EventViewerInvite {
  const EventViewerInvite({this.roles = const [], this.status = 'invited'});

  final List<String> roles;

  /// `invited` · `accepted` · `declined`.
  final String status;

  bool get isCohost => roles.contains('cohost');

  factory EventViewerInvite.fromJson(Map<String, dynamic> json) => EventViewerInvite(
        roles: (json['roles'] as List?)?.whereType<String>().toList() ?? const [],
        status: json['status'] as String? ?? 'invited',
      );

  Map<String, dynamic> toJson() => {'roles': roles, 'status': status};
}

/// An invite waiting for the viewer's answer (`GET /me/event-invites`).
class EventInviteRequest {
  const EventInviteRequest({required this.role, required this.event, this.invitedAt});

  /// `cohost` · `artist`.
  final String role;
  final StudioEvent event;
  final DateTime? invitedAt;

  /// "Co-host" / "Featured artist".
  String get roleLabel => role == 'cohost' ? 'Co-host' : 'Featured artist';

  factory EventInviteRequest.fromJson(Map<String, dynamic> json) => EventInviteRequest(
        role: json['role'] as String? ?? 'artist',
        event: StudioEvent.fromJson(json['event'] as Map<String, dynamic>? ?? const {}),
        invitedAt: DateTime.tryParse(json['invitedAt'] as String? ?? '')?.toLocal(),
      );
}

/// A host asking to show, sell or auction one of the viewer's pieces (`GET
/// /me/piece-requests`, Phase 5.2): the lineup entry, what approving would end, and the event.
class EventPieceRequest {
  const EventPieceRequest({required this.item, required this.event, this.preview});

  final EventLineupItem item;
  final StudioEvent event;
  final EventTaggingPreview? preview;

  factory EventPieceRequest.fromJson(Map<String, dynamic> json) => EventPieceRequest(
        item: EventLineupItem.fromJson(json),
        event: StudioEvent.fromJson(json['event'] as Map<String, dynamic>? ?? const {}),
        preview: json['preview'] is Map<String, dynamic>
            ? EventTaggingPreview.fromJson(json['preview'] as Map<String, dynamic>)
            : null,
      );
}

/// A question the host answers on the event page.
class EventFaq {
  const EventFaq({required this.question, required this.answer});

  final String question;
  final String answer;

  factory EventFaq.fromJson(Map<String, dynamic> json) => EventFaq(
        question: json['question'] as String? ?? '',
        answer: json['answer'] as String? ?? '',
      );
}

/// A kind of ticket the host sells (`EvChooseTickets`): name, price, what it includes, how
/// many are left and how many one order may take.
class EventTicketType {
  const EventTicketType({
    required this.id,
    required this.name,
    this.priceCents = 0,
    this.includes,
    this.left,
    this.perOrderLimit,
    this.quantity,
    this.sold,
    this.hostNetCents,
    this.closed = false,
    this.waiting,
    this.saleStartsAt,
    this.saleEndsAt,
    this.onSale,
    this.soldOut,
    this.sortOrder,
  });

  final String id;
  final String name;

  /// 0 for a free ticket.
  final int priceCents;
  final String? includes;

  /// Null when there is no cap.
  final int? left;

  /// Null when only [left] limits an order.
  final int? perOrderLimit;

  /// The host's own view only (B22): the cap the host set (null = no cap), how many are sold
  /// or held, what the host receives per ticket, whether the type is closed and how many wait.
  final int? quantity;
  final int? sold;
  final int? hostNetCents;
  final bool closed;
  final int? waiting;

  /// The sale window, when the host set one.
  final DateTime? saleStartsAt;
  final DateTime? saleEndsAt;

  /// Whether it can be bought right now (open and inside its sale window). Null on an older
  /// server, which treats every type as on sale.
  final bool? onSale;
  final bool? soldOut;
  final int? sortOrder;

  bool get isFree => priceCents == 0;
  bool get isSoldOut => soldOut == true || left == 0;

  /// The most one order can hold.
  int? get maxPerOrder {
    final caps = [?left, ?perOrderLimit];
    if (caps.isEmpty) return null;
    return caps.reduce((a, b) => a < b ? a : b);
  }

  static DateTime? _date(Object? raw) =>
      raw is String ? DateTime.tryParse(raw)?.toLocal() : null;

  factory EventTicketType.fromJson(Map<String, dynamic> json) => EventTicketType(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        priceCents: (json['priceCents'] as num?)?.toInt() ?? 0,
        includes: json['includes'] as String?,
        left: (json['left'] as num?)?.toInt(),
        perOrderLimit: (json['perOrderLimit'] as num?)?.toInt() ?? (json['maxPerOrder'] as num?)?.toInt(),
        quantity: (json['quantity'] as num?)?.toInt(),
        sold: (json['sold'] as num?)?.toInt(),
        hostNetCents: (json['hostNetCents'] as num?)?.toInt(),
        closed: json['closed'] as bool? ?? false,
        waiting: (json['waiting'] as num?)?.toInt(),
        saleStartsAt: _date(json['saleStartsAt']),
        saleEndsAt: _date(json['saleEndsAt']),
        onSale: json['onSale'] as bool?,
        soldOut: json['soldOut'] as bool?,
        sortOrder: (json['sortOrder'] as num?)?.toInt(),
      );

  /// The body the ticket-type endpoints take (POST and PATCH). Read-only facts (`left`,
  /// `sold`, `hostNetCents`…) are left out; a null sale window or cap is sent as null so an
  /// edit can clear it.
  Map<String, dynamic> toJson() => {
        'name': name,
        'priceCents': priceCents,
        'includes': includes,
        'quantity': quantity,
        'perOrderLimit': perOrderLimit,
        'saleStartsAt': saleStartsAt?.toUtc().toIso8601String(),
        'saleEndsAt': saleEndsAt?.toUtc().toIso8601String(),
        if (sortOrder != null) 'sortOrder': sortOrder,
      };
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
    this.approvalStatus,
    this.listingEnded,
    this.respondedAt,
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

  /// The artist's answer when someone else tagged their piece (Phase 5.2): `waiting` ·
  /// `approved` · `declined`. Null when the server leaves it out, which means approved.
  final String? approvalStatus;

  /// Whether approving ended the piece's own listing or auction.
  final bool? listingEnded;
  final DateTime? respondedAt;

  /// On the event for everyone to see: approved, or no approval needed.
  bool get isLive => approvalStatus == null || approvalStatus == 'approved';
  bool get isWaiting => approvalStatus == 'waiting';
  bool get isDeclined => approvalStatus == 'declined';

  /// The artist's name for captions, falling back to the handle.
  String get artistLabel {
    final name = artistName ?? '';
    if (name.isNotEmpty) return name;
    final handle = artistUsername ?? '';
    return handle.isNotEmpty ? '@$handle' : 'the artist';
  }

  /// "Waiting for Mira" / "Approved by Mira" / "Declined by Mira", or null with no status.
  String? get approvalLine => switch (approvalStatus) {
        'waiting' => 'Waiting for $artistLabel',
        'approved' => 'Approved by $artistLabel',
        'declined' => 'Declined by $artistLabel',
        _ => null,
      };

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
        approvalStatus: json['approvalStatus'] as String?,
        listingEnded: json['listingEnded'] as bool?,
        respondedAt: DateTime.tryParse(json['respondedAt'] as String? ?? '')?.toLocal(),
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
    this.featured,
    this.today = const [],
    this.following = const [],
    this.upcoming = const [],
    this.categories = const [],
  });

  /// The team's Featured pick in the asked range and place (BACKEND_CHANGES B23), if any.
  final StudioEvent? featured;
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

    final featured = json['featured'];
    return EventBrowse(
      featured: featured is Map<String, dynamic> ? StudioEvent.fromJson(featured) : null,
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

/// The waitlist on a sold-out event, as the server describes it (BACKEND_CHANGES B22;
/// `EvWaitlistRules`): whether it is taking names, the viewer's place (how many of each type
/// they want), tickets held for them with when the hold ends, and for the host how many wait.
class EventWaitlist {
  const EventWaitlist({
    this.open = false,
    this.wanted = const {},
    this.held = const {},
    this.heldUntil,
    this.waitingCount,
  });

  /// Taking names (sold out, and the event hasn't started).
  final bool open;

  /// The viewer's place in line: ticket type id → how many. Empty when they aren't on it.
  final Map<String, int> wanted;

  /// Tickets held for the viewer: ticket type id → how many. Empty when nothing is held.
  final Map<String, int> held;
  final DateTime? heldUntil;

  /// The host's view: how many people are waiting. Null for everyone else.
  final int? waitingCount;

  bool get joined => wanted.values.any((n) => n > 0);

  /// A hold that hasn't run out.
  bool isHeld(DateTime now) => held.values.any((n) => n > 0) && heldUntil != null && heldUntil!.isAfter(now);

  static Map<String, int> _items(Object? raw) => {
        for (final item in (raw as List?)?.whereType<Map<String, dynamic>>() ?? const <Map<String, dynamic>>[])
          if ((item['ticketTypeId'] as String?)?.isNotEmpty == true)
            item['ticketTypeId'] as String: (item['quantity'] as num?)?.toInt() ?? 0,
      };

  factory EventWaitlist.fromJson(Map<String, dynamic> json) => EventWaitlist(
        open: json['open'] as bool? ?? false,
        wanted: _items(json['wanted']),
        held: _items((json['held'] as Map<String, dynamic>?)?['items']),
        heldUntil: DateTime.tryParse((json['held'] as Map<String, dynamic>?)?['until'] as String? ?? '')?.toLocal(),
        waitingCount: (json['waitingCount'] as num?)?.toInt(),
      );
}
