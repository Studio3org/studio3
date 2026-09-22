import '../models/event_qr_code.dart';
import '../models/studio_event.dart';
import 'api_client.dart';
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

  Future<EventBrowse> browse() async {
    final json = await _api.get('/api/events/browse', auth: true);
    return EventBrowse.fromJson(_api.extractData(json) as Map<String, dynamic>);
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

  /// One slice of the list. [scope] is `upcoming` (the default), `today`, `following` or
  /// `saved`; the last two need a signed-in viewer.
  Future<List<StudioEvent>> list({
    String scope = 'upcoming',
    String? category,
    int? limit,
    int? offset,
  }) async {
    final json = await _api.get(
      '/api/events',
      query: {
        'scope': scope,
        if (category != null) 'category': category,
        if (limit != null) 'limit': '$limit',
        if (offset != null) 'offset': '$offset',
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
  /// `featured` changes nothing about the piece's own listing. `sale` and `bid` end it, and
  /// only the artist who owns the piece may choose them — a host putting someone else's work
  /// up for sale answers 403.
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
  /// is cancelled properly — holds released, bidders told.
  Future<StudioEvent> cancel(String eventId, {String? reason}) async {
    final json = await _api.post(
      '/api/events/$eventId/cancel',
      body: {if (reason != null) 'reason': reason},
      auth: true,
    );
    return StudioEvent.fromJson(_api.extractData(json) as Map<String, dynamic>);
  }
}
