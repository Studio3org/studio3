import 'package:flutter/foundation.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import '../models/event_check_in.dart';
import '../models/event_order.dart';
import '../models/event_qr_code.dart';
import '../models/studio_event.dart';
import 'api_client.dart';
import 'api_exception.dart';
import 'stripe_setup.dart';
import 'cache_service.dart';
import 'connectivity_service.dart';

/// Events: browsing them, and hosting one.
///
/// The create flow is deliberately two-phase. [create] makes a **draft**, which lists
/// nothing and is visible to nobody but its host, and [publish] is what puts the event out
/// and turns its bill into real listings. That split is what lets a host add and rearrange
/// work without anything going on sale under them — and it is why the create screen should
/// create the draft early and publish once, rather than holding everything in memory until
/// the final tap.
class EventService {
  EventService._();
  static final EventService instance = EventService._();

  final _api = ApiClient.instance;

  // --- browsing -------------------------------------------------------------------------

  /// The whole events tab in one request. Works signed out — entry is free and open.
  static const _browseKey = 'events.browse';

  /// The Events tab, narrowed to a range ([from] to [to]), a [city] and a search [q] on the
  /// server (BACKEND_CHANGES B23). With none of them, everything coming up.
  Future<EventBrowse> browse({DateTime? from, DateTime? to, String? city, String? q, int? limit}) async {
    final json = await _api.get(
      '/api/events/browse',
      query: eventFilterQuery(from: from, to: to, city: city, q: q, limit: limit),
      auth: true,
    );
    return EventBrowse.fromJson(_api.extractData(json) as Map<String, dynamic>);
  }

  /// The Near me sheet's places: cities with something coming up (B23).
  Future<List<String>> cities() async {
    final json = await _api.get('/api/events/cities');
    final data = _api.extractData(json) as Map<String, dynamic>;
    return [
      for (final c in (data['cities'] as List? ?? const []).whereType<Map<String, dynamic>>())
        if ((c['city'] as String?)?.isNotEmpty ?? false) c['city'] as String,
    ];
  }

  /// Cache-first browse payload, so returning to the Events tab paints the
  /// last known line-up immediately and revalidates behind it.
  Future<EventBrowse> browseCached({
    bool forceRefresh = false,
    void Function(EventBrowse fresh)? onBackgroundUpdate,
  }) {
    return CacheService.instance.fetchWithCache<EventBrowse>(
      key: _browseKey,
      ttl: const Duration(minutes: 3),
      forceRefresh: forceRefresh,
      fetchRaw: () {
        if (!ConnectivityService.instance.isOnline) {
          throw const CacheMiss(_browseKey);
        }
        return _api.get('/api/events/browse', auth: true);
      },
      parse: (json) =>
          EventBrowse.fromJson(_api.extractData(json) as Map<String, dynamic>),
      onBackgroundUpdate: onBackgroundUpdate,
    );
  }

  EventBrowse? peekBrowseCached() {
    return CacheService.instance.peekCache<EventBrowse>(
      key: _browseKey,
      parse: (json) =>
          EventBrowse.fromJson(_api.extractData(json) as Map<String, dynamic>),
    );
  }

  /// One slice of the list. [scope] is `upcoming` (the default), `today`, `following`,
  /// `saved`, `hosting` (events this viewer hosts, drafts included) or `going` (events this
  /// viewer has RSVP'd to); every scope but `upcoming`/`today` needs a signed-in viewer.
  Future<List<StudioEvent>> list({
    String scope = 'upcoming',
    String? category,
    int? limit,
    int? offset,
    DateTime? from,
    DateTime? to,
    String? city,
    String? q,
  }) async {
    final json = await _api.get(
      '/api/events',
      query: {
        'scope': scope,
        if (category != null) 'category': category,
        if (offset != null) 'offset': '$offset',
        ...eventFilterQuery(from: from, to: to, city: city, q: q, limit: limit),
      },
      auth: true,
    );
    final data = _api.extractData(json) as Map<String, dynamic>;
    return (data['events'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(StudioEvent.fromJson)
        .toList();
  }

  Future<StudioEvent> getById(String eventId) async {
    final json = await _api.get('/api/events/$eventId', auth: true);
    return StudioEvent.fromJson(_api.extractData(json) as Map<String, dynamic>);
  }

  /// Bookmark or un-bookmark. Returns the new save count so a list can update in place.
  Future<int> setSaved(String eventId, {required bool saved}) async {
    final json = await _api.post(
      '/api/events/$eventId/save',
      body: {'saved': saved},
      auth: true,
    );
    final data = _api.extractData(json) as Map<String, dynamic>;
    return (data['saveCount'] as num?)?.toInt() ?? 0;
  }

  /// Say you're coming, or take it back.
  ///
  /// Free, and not a ticket — it admits nobody and charges nothing. What it buys is that the
  /// host knows how many to expect and that there is somebody to tell if the event is called
  /// off.
  ///
  /// Throws [ApiException] with 409 when a capped event is full.
  Future<EventRsvpResult> setRsvp(String eventId, {required bool going}) async {
    final json = await _api.post(
      '/api/events/$eventId/rsvp',
      body: {'going': going},
      auth: true,
    );
    return EventRsvpResult.fromJson(_api.extractData(json) as Map<String, dynamic>);
  }

  // --- tickets (BACKEND_CHANGES B22) ------------------------------------------------------

  /// The id [StudioEvent.ticketOptions] gives the made-up General Admission place of an
  /// event with no ticket types. It's an RSVP, never an order item.
  static const rsvpTypeId = 'rsvp';

  static List<Map<String, dynamic>> _items(Map<EventTicketType, int> counts) => [
    for (final e in counts.entries)
      if (e.value > 0 && e.key.id != rsvpTypeId) {'ticketTypeId': e.key.id, 'quantity': e.value},
  ];

  /// The server's price for these tickets: service fee, sales tax and total.
  Future<EventOrderQuote> quoteOrder(String eventId, Map<EventTicketType, int> counts) async {
    final json = await _api.post(
      '/api/events/$eventId/orders/quote',
      body: {'items': _items(counts)},
      auth: true,
    );
    return EventOrderQuote.fromJson(_api.extractData(json) as Map<String, dynamic>);
  }

  /// Places the order and pays for it with Stripe's payment sheet. Throws [ApiException] when
  /// a type sold out or went over its limit in the meantime (409), and
  /// [StripeException] when the buyer closes the payment sheet.
  Future<EventOrder> placeOrder(String eventId, Map<EventTicketType, int> counts) async {
    final json = await _api.post(
      '/api/events/$eventId/orders',
      body: {'items': _items(counts)},
      auth: true,
    );
    final order = EventOrder.fromJson(_api.extractData(json) as Map<String, dynamic>);
    final secret = order.clientSecret;
    if (secret == null) return order;
    if (!StripeSetup.ready) {
      if (kDebugMode) return order;
      throw ApiException('Card payments are not set up in this build yet.');
    }
    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        paymentIntentClientSecret: secret,
        merchantDisplayName: 'Studio 3',
      ),
    );
    await Stripe.instance.presentPaymentSheet();
    return order;
  }

  /// Where an order stands after the payment sheet (`GET …/orders/:orderId`, buyer only).
  /// Poll it until it leaves `pending_payment`: Stripe confirms on the server a second or
  /// two after the sheet closes.
  Future<EventOrderStatus> getOrder(String eventId, String orderId) async {
    final json = await _api.get('/api/events/$eventId/orders/$orderId', auth: true);
    return EventOrderStatus.fromJson(_api.extractData(json) as Map<String, dynamic>);
  }

  /// Refund the buyer's own tickets (`POST …/orders/:orderId/refund`, Phase 4.1): just
  /// [ticketIds], or every unused ticket in the order without them. Throws [ApiException]
  /// with the server's message: 409 when refunds have closed or a ticket was used, 502 when
  /// Stripe failed (it retries on its own).
  Future<EventRefundResult> refundTickets(String eventId, String orderId, {List<String>? ticketIds}) async {
    final json = await _api.post(
      '/api/events/$eventId/orders/$orderId/refund',
      body: {if (ticketIds != null && ticketIds.isNotEmpty) 'ticketIds': ticketIds},
      auth: true,
    );
    return EventRefundResult.fromJson(_api.extractData(json) as Map<String, dynamic>);
  }

  /// Google Wallet's "save" link for an order's live tickets, or for one of them with
  /// [ticketId] (`GET …/orders/:orderId/wallet-pass?platform=google`, B25). Open it outside
  /// the app. 409 not issued yet, 410 no longer valid, 503 not set up on the server.
  Future<String> googleWalletUrl(String eventId, String orderId, {String? ticketId}) async {
    final json = await _api.get(
      '/api/events/$eventId/orders/$orderId/wallet-pass',
      query: {'platform': 'google', 'ticketId': ?ticketId},
      auth: true,
    );
    final data = _api.extractData(json);
    final url = data is Map<String, dynamic> ? data['saveUrl'] as String? : null;
    if (url == null || url.isEmpty) throw ApiException("Google Wallet isn't available right now.");
    return url;
  }

  /// An Apple Wallet pass (`GET …/orders/:orderId/wallet-pass?platform=apple`, B25): with
  /// [ticketId] that ticket's `.pkpass`; without it, one ticket's `.pkpass` or, for several,
  /// a `.pkpasses` bundle. Same errors as [googleWalletUrl].
  Future<Uint8List> appleWalletPass(String eventId, String orderId, {String? ticketId}) {
    return _api.getBytes(
      '/api/events/$eventId/orders/$orderId/wallet-pass',
      query: {'platform': 'apple', 'ticketId': ?ticketId},
    );
  }

  // --- ticket types (host, B22) ------------------------------------------------------------

  static List<EventTicketType> _types(Map<String, dynamic> json, ApiClient api) {
    final data = api.extractData(json);
    final list = data is Map<String, dynamic> ? data['ticketTypes'] : data;
    return (list as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(EventTicketType.fromJson)
        .toList();
  }

  /// The event's ticket types. The host's own view also carries `quantity`, `sold`,
  /// `hostNetCents` and closed types.
  Future<List<EventTicketType>> listTicketTypes(String eventId) async {
    final json = await _api.get('/api/events/$eventId/ticket-types', auth: true);
    return _types(json, _api);
  }

  /// Add a ticket type. Returns the new type's id and the event's types after the change.
  /// A paid type needs the host's seller profile (403 otherwise).
  Future<({String id, List<EventTicketType> ticketTypes})> createTicketType(
    String eventId,
    EventTicketType type,
  ) async {
    final json = await _api.post('/api/events/$eventId/ticket-types', body: type.toJson(), auth: true);
    final data = _api.extractData(json);
    final id = data is Map<String, dynamic> ? data['id'] as String? ?? '' : '';
    return (id: id, ticketTypes: _types(json, _api));
  }

  /// Change a ticket type. A sold type's price can't change, and its quantity can't drop
  /// below what's sold or held (409).
  Future<List<EventTicketType>> updateTicketType(
    String eventId,
    String typeId,
    Map<String, dynamic> changes,
  ) async {
    final json = await _api.patch('/api/events/$eventId/ticket-types/$typeId', body: changes, auth: true);
    return _types(json, _api);
  }

  /// Remove a ticket type: deleted when nobody ever ordered it, otherwise closed (its
  /// tickets stay valid).
  Future<List<EventTicketType>> deleteTicketType(String eventId, String typeId) async {
    final json = await _api.delete('/api/events/$eventId/ticket-types/$typeId', auth: true);
    return _types(json, _api);
  }

  /// The viewer's tickets for one event, each with its own code (`EvTicket`).
  /// Join the waitlist (`EvWaitlistJoin`): how many of each sold-out type the viewer wants.
  /// Free, no card. Returns the event's waitlist as the server now sees it.
  Future<EventWaitlist> joinWaitlist(String eventId, Map<EventTicketType, int> wanted) async {
    final json = await _api.post(
      '/api/events/$eventId/waitlist',
      body: {
        'items': [
          for (final e in wanted.entries)
            if (e.value > 0) {'ticketTypeId': e.key.id, 'quantity': e.value},
        ],
      },
      auth: true,
    );
    return EventWaitlist.fromJson(_api.extractData(json) as Map<String, dynamic>);
  }

  /// Leave the waitlist (tap You're on the waitlist).
  Future<void> leaveWaitlist(String eventId) async {
    await _api.delete('/api/events/$eventId/waitlist', auth: true);
  }

  /// Give up the tickets held for the viewer and keep their place for the other types
  /// (`EvWaitlistHeld` "Keep waiting for [type]").
  Future<EventWaitlist> releaseHold(String eventId) async {
    final json = await _api.post('/api/events/$eventId/waitlist/hold/release', auth: true);
    return EventWaitlist.fromJson(_api.extractData(json) as Map<String, dynamic>);
  }

  Future<List<EventTicket>> myTickets(String eventId) async {
    final json = await _api.get('/api/user/me/tickets?eventId=$eventId', auth: true);
    final data = _api.extractData(json);
    final list = data is Map<String, dynamic> ? data['tickets'] : data;
    return (list as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(EventTicket.fromJson)
        .where((t) => t.code.isNotEmpty)
        .toList();
  }

  // --- check-in at the door (host and co-hosts, Phase 4.3) ---------------------------------

  /// Check one ticket in. [code] is the QR value, the ticket number or the ticket id (the
  /// guest list's check-in by hand). A bad ticket still answers 200 with `invalid`; 409 when
  /// the event isn't checking anyone in.
  Future<CheckInResult> checkIn(String eventId, String code, {DateTime? scannedAt}) async {
    final json = await _api.post(
      '/api/events/$eventId/tickets/${Uri.encodeComponent(code.trim())}/check-in',
      body: {if (scannedAt != null) 'scannedAt': scannedAt.toUtc().toIso8601String()},
      auth: true,
    );
    return CheckInResult.fromJson(_api.extractData(json) as Map<String, dynamic>);
  }

  /// Send scans made offline, at most 500 at a time; results come back in the same order.
  Future<CheckInSyncResult> syncCheckIns(String eventId, List<({String code, DateTime scannedAt})> scans) async {
    final json = await _api.post(
      '/api/events/$eventId/check-in/sync',
      body: {
        'scans': [
          for (final s in scans) {'code': s.code, 'scannedAt': s.scannedAt.toUtc().toIso8601String()},
        ],
      },
      auth: true,
    );
    return CheckInSyncResult.fromJson(_api.extractData(json) as Map<String, dynamic>);
  }

  /// The guest list: live tickets, searchable by name, username or ticket number.
  Future<EventGuestList> guests(String eventId, {String? q, int? limit}) async {
    final search = q?.trim() ?? '';
    final json = await _api.get(
      '/api/events/$eventId/guests',
      query: {if (search.isNotEmpty) 'q': search, if (limit != null) 'limit': '$limit'},
      auth: true,
    );
    return EventGuestList.fromJson(_api.extractData(json) as Map<String, dynamic>);
  }

  /// Everything the scanner needs offline: the public key and every live ticket.
  Future<CheckInManifest> manifest(String eventId) async {
    final json = await _api.get('/api/events/$eventId/check-in/manifest', auth: true);
    return CheckInManifest.fromJson(_api.extractData(json) as Map<String, dynamic>);
  }

  /// Who is coming. Host-only — an attendee list is not public.
  Future<List<EventPerson>> attendees(String eventId) async {
    final json = await _api.get('/api/events/$eventId/attendees', auth: true);
    final data = _api.extractData(json) as Map<String, dynamic>;
    return (data['attendees'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(EventPerson.fromJson)
        .toList();
  }

  // --- hosting --------------------------------------------------------------------------

  /// Create the draft. Nothing is public and nothing is listed until [publish].
  ///
  /// [startsAt] and [endsAt] are sent as UTC; [timezoneName] is the IANA zone the event
  /// actually happens in, so its time reads the same to everyone rather than being shifted
  /// into each reader's own zone.
  Future<StudioEvent> create({
    required String title,
    required DateTime startsAt,
    required DateTime endsAt,
    String? description,
    String? coverMediaUrl,
    String? category,
    String? timezoneName,
    String? venueName,
    String? address,
    double? latitude,
    double? longitude,
    int? capacity,
    String? refundPolicy,
    String? ageLimit,
    String? visibility,
    DateTime? auctionEndsAt,
  }) async {
    final json = await _api.post(
      '/api/events',
      body: {
        'title': title,
        'startsAt': startsAt.toUtc().toIso8601String(),
        'endsAt': endsAt.toUtc().toIso8601String(),
        if (description != null) 'description': description,
        if (coverMediaUrl != null) 'coverMediaUrl': coverMediaUrl,
        if (category != null) 'category': category,
        if (timezoneName != null) 'timezone': timezoneName,
        if (venueName != null) 'venueName': venueName,
        if (address != null) 'address': address,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (capacity != null) 'capacity': capacity,
        if (refundPolicy != null) 'refundPolicy': refundPolicy,
        if (ageLimit != null) 'ageLimit': ageLimit,
        if (visibility != null) 'visibility': visibility,
        if (auctionEndsAt != null) 'auctionEndsAt': auctionEndsAt.toUtc().toIso8601String(),
      },
      auth: true,
    );
    return StudioEvent.fromJson(_api.extractData(json) as Map<String, dynamic>);
  }

  Future<StudioEvent> update(String eventId, Map<String, dynamic> changes) async {
    final json = await _api.patch('/api/events/$eventId', body: changes, auth: true);
    return StudioEvent.fromJson(_api.extractData(json) as Map<String, dynamic>);
  }

  /// Replace the cohost and/or artist lists, by username.
  ///
  /// Usernames rather than ids because that is what every people picker in the app returns
  /// and what the response gives back — taking ids would mean a lookup round trip purely to
  /// satisfy this one call.
  ///
  /// A role that is passed is replaced wholesale, which is what makes removing somebody
  /// possible; a role left null is untouched, so setting artists does not clear cohosts.
  Future<StudioEvent> setPeople(
    String eventId, {
    List<String>? cohostUsernames,
    List<String>? artistUsernames,
  }) async {
    final json = await _api.put(
      '/api/events/$eventId/people',
      body: {
        if (cohostUsernames != null) 'cohostUsernames': cohostUsernames,
        if (artistUsernames != null) 'artistUsernames': artistUsernames,
      },
      auth: true,
    );
    return StudioEvent.fromJson(_api.extractData(json) as Map<String, dynamic>);
  }

  // --- the bill -------------------------------------------------------------------------

  /// What adding this piece would end. Ask before adding anything in `sale` or `bid` mode.
  ///
  /// Tagging a piece for sale closes whatever listing it already had, and if that was a
  /// running auction every bidder is refunded and told. There is no undo, so the host sees
  /// the real numbers first.
  Future<EventTaggingPreview> previewTagging(String eventId, String pieceId) async {
    final json = await _api.get(
      '/api/events/$eventId/pieces/$pieceId/tagging-preview',
      auth: true,
    );
    return EventTaggingPreview.fromJson(_api.extractData(json) as Map<String, dynamic>);
  }

  /// Add a piece to the bill.
  ///
  /// The host and accepted co-hosts can add anyone's piece in any mode (Phase 5.2). Someone
  /// else's piece comes back `waiting` and stays off the event until its artist approves;
  /// approving a `sale` or `bid` entry ends the piece's own listing. An event either sells its
  /// pieces or auctions them, never both (409).
  Future<EventLineupItem> addPiece(
    String eventId, {
    required String pieceId,
    String mode = 'featured',
    int? priceCents,
    String? deliveryMode,
    int? sortOrder,
  }) async {
    final json = await _api.post(
      '/api/events/$eventId/pieces',
      body: {
        'pieceId': pieceId,
        'mode': mode,
        if (priceCents != null) 'priceCents': priceCents,
        if (deliveryMode != null) 'deliveryMode': deliveryMode,
        if (sortOrder != null) 'sortOrder': sortOrder,
      },
      auth: true,
    );
    return EventLineupItem.fromJson(_api.extractData(json) as Map<String, dynamic>);
  }

  Future<void> removePiece(String eventId, String pieceId) async {
    await _api.delete('/api/events/$eventId/pieces/$pieceId', auth: true);
  }

  // --- invites and piece requests (Phase 5) ---------------------------------------------

  /// Say yes to being on the bill: [role] (`cohost` · `artist`), or every invite waiting on
  /// this event without it. 404 when nothing is waiting.
  Future<void> acceptInvite(String eventId, {String? role}) async {
    await _api.post('/api/events/$eventId/invite/accept', body: {'role': ?role}, auth: true);
  }

  /// Say no to being on the bill. Same rules as [acceptInvite].
  Future<void> declineInvite(String eventId, {String? role}) async {
    await _api.post('/api/events/$eventId/invite/decline', body: {'role': ?role}, auth: true);
  }

  /// Invites waiting for the viewer's answer.
  Future<List<EventInviteRequest>> myEventInvites() async {
    final json = await _api.get('/api/user/me/event-invites', auth: true);
    final data = _api.extractData(json);
    final list = data is Map<String, dynamic> ? data['invites'] : data;
    return (list as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .where((i) => i['event'] is Map<String, dynamic>)
        .map(EventInviteRequest.fromJson)
        .toList();
  }

  /// Hosts asking to show, sell or auction the viewer's pieces, waiting for an answer.
  Future<List<EventPieceRequest>> myPieceRequests() async {
    final json = await _api.get('/api/user/me/piece-requests', auth: true);
    final data = _api.extractData(json);
    final list = data is Map<String, dynamic> ? data['requests'] : data;
    return (list as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .where((r) => r['event'] is Map<String, dynamic>)
        .map(EventPieceRequest.fromJson)
        .toList();
  }

  /// The artist approves their piece for the event, optionally at their own [priceCents].
  /// For `sale` or `bid` this ends the piece's own listing or auction. 403 until onboarding
  /// is finished; 409 when already answered or the event stopped being edited.
  Future<EventLineupItem> approvePiece(String eventId, String pieceId, {int? priceCents}) async {
    final json = await _api.post(
      '/api/events/$eventId/pieces/$pieceId/approve',
      body: {'priceCents': ?priceCents},
      auth: true,
    );
    final data = _api.extractData(json);
    return EventLineupItem.fromJson(data is Map<String, dynamic> ? data : const {});
  }

  /// The artist declines having their piece at the event.
  Future<void> declinePiece(String eventId, String pieceId) async {
    await _api.post('/api/events/$eventId/pieces/$pieceId/decline', auth: true);
  }

  /// The printable codes for the room. Host-only.
  ///
  /// The links come from the server so the code on the wall and the link the app resolves
  /// are the same string by construction.
  Future<EventQrCodes> qrCodes(String eventId) async {
    final json = await _api.get('/api/events/$eventId/qr-codes', auth: true);
    return EventQrCodes.fromJson(_api.extractData(json) as Map<String, dynamic>);
  }

  // --- going live -----------------------------------------------------------------------

  /// Publish the event and list everything on its bill.
  ///
  /// Idempotent: publishing an already-published event returns it unchanged rather than
  /// listing the bill twice.
  Future<StudioEvent> publish(String eventId) async {
    final json = await _api.post('/api/events/$eventId/publish', auth: true);
    return StudioEvent.fromJson(_api.extractData(json) as Map<String, dynamic>);
  }

  /// Call it off. Every listing the event created comes down, and any auction it was running
  /// is cancelled properly — holds released, bidders told. Every ticket stops working and paid
  /// orders are refunded in full (Phase 4.5).
  ///
  /// [message] goes to guests with the notice (cut to 500 by the server); [reason] is the
  /// older field, kept as the cancellation note the event shows.
  Future<StudioEvent> cancel(String eventId, {String? reason, String? message}) async {
    final json = await _api.post(
      '/api/events/$eventId/cancel',
      body: {'reason': ?reason, 'message': ?message},
      auth: true,
    );
    return StudioEvent.fromJson(_api.extractData(json) as Map<String, dynamic>);
  }

  /// What cancelling would do: tickets voided, the refund total and the card fees the host
  /// pays (`GET …/cancel-preview`).
  Future<EventCancelPreview> cancelPreview(String eventId) async {
    final json = await _api.get('/api/events/$eventId/cancel-preview', auth: true);
    return EventCancelPreview.fromJson(_api.extractData(json) as Map<String, dynamic>);
  }

  /// Move a published event (`POST …/reschedule`, host only). Everyone with a ticket is told
  /// once, and refunds open until the new start. 409 when it isn't published, has ended, or
  /// bidding has started; 400 for a bad time.
  Future<StudioEvent> reschedule(String eventId, {required DateTime startsAt, required DateTime endsAt, String? message}) async {
    final text = message?.trim() ?? '';
    final json = await _api.post(
      '/api/events/$eventId/reschedule',
      body: {
        'startsAt': startsAt.toUtc().toIso8601String(),
        'endsAt': endsAt.toUtc().toIso8601String(),
        if (text.isNotEmpty) 'message': text,
      },
      auth: true,
    );
    return StudioEvent.fromJson(_api.extractData(json) as Map<String, dynamic>);
  }

  /// Remove a hosted event outright. A draft is deleted with nothing else to do; a published
  /// event is wound down first — listings released, any auction cancelled and refunded,
  /// attendees told — the same as [cancel], before the event itself disappears.
  Future<void> delete(String eventId) async {
    await _api.delete('/api/events/$eventId', auth: true);
  }
}

/// `?from=&to=&city=&q=&limit=` for the Events tab (BACKEND_CHANGES B23); times in UTC.
Map<String, String> eventFilterQuery({DateTime? from, DateTime? to, String? city, String? q, int? limit}) {
  final place = city?.trim();
  final search = q?.trim();
  return {
    if (from != null) 'from': from.toUtc().toIso8601String(),
    if (to != null) 'to': to.toUtc().toIso8601String(),
    if (place != null && place.isNotEmpty) 'city': place,
    if (search != null && search.isNotEmpty) 'q': search,
    if (limit != null) 'limit': '$limit',
  };
}
