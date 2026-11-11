import 'event_order.dart';

/// One admission as the door sees it (Phase 4.3): a scan's `ticket`, a guest list row and a
/// manifest entry all share this shape.
class CheckInTicket {
  const CheckInTicket({
    required this.id,
    this.number,
    this.ticketTypeName,
    this.holderName,
    this.holderUsername,
    this.holderAvatarUrl,
    this.position,
    this.of,
    this.status,
    this.checkedInAt,
  });

  final String id;

  /// "S3-T-8KQ2XM".
  final String? number;
  final String? ticketTypeName;
  final String? holderName;
  final String? holderUsername;
  final String? holderAvatarUrl;

  /// Which ticket of its order it is: "1 of 2".
  final int? position;
  final int? of;

  /// `valid`, `checked_in`, or (in a scan of a dead ticket) `refunded` / `void`.
  final String? status;
  final DateTime? checkedInAt;

  bool get isCheckedIn => status == 'checked_in';

  /// The holder's name, or "Guest" when they have none (the server's word too).
  String get displayName {
    final name = holderName?.trim() ?? '';
    if (name.isNotEmpty) return name;
    final user = holderUsername?.trim() ?? '';
    return user.isNotEmpty ? user : 'Guest';
  }

  CheckInTicket copyWith({String? status, DateTime? checkedInAt}) => CheckInTicket(
    id: id,
    number: number,
    ticketTypeName: ticketTypeName,
    holderName: holderName,
    holderUsername: holderUsername,
    holderAvatarUrl: holderAvatarUrl,
    position: position,
    of: of,
    status: status ?? this.status,
    checkedInAt: checkedInAt ?? this.checkedInAt,
  );

  factory CheckInTicket.fromJson(Map<String, dynamic> json) => CheckInTicket(
    id: json['id'] as String? ?? '',
    number: json['number'] as String?,
    ticketTypeName: json['ticketTypeName'] as String?,
    holderName: json['holderName'] as String?,
    holderUsername: json['holderUsername'] as String?,
    holderAvatarUrl: json['holderAvatarUrl'] as String?,
    position: (json['position'] as num?)?.toInt(),
    of: (json['of'] as num?)?.toInt(),
    status: json['status'] as String?,
    checkedInAt: DateTime.tryParse(json['checkedInAt'] as String? ?? '')?.toLocal(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'number': number,
    'ticketTypeName': ticketTypeName,
    'holderName': holderName,
    'holderUsername': holderUsername,
    'holderAvatarUrl': holderAvatarUrl,
    'position': position,
    'of': of,
    'status': status,
    'checkedInAt': checkedInAt?.toUtc().toIso8601String(),
  };
}

/// What a scan says (`POST …/tickets/:code/check-in`): `checked_in`, `already_checked_in` or
/// `invalid`, with the server's [message] to show as it is.
class CheckInResult {
  const CheckInResult({
    required this.result,
    required this.message,
    this.ticket,
    this.checkedIn,
    this.total,
    this.code,
    this.offline = false,
  });

  static const checkedInResult = 'checked_in';
  static const alreadyResult = 'already_checked_in';
  static const invalidResult = 'invalid';

  final String result;
  final String message;
  final CheckInTicket? ticket;
  final int? checkedIn;
  final int? total;

  /// The scanned code (sync results carry it).
  final String? code;

  /// Decided on this phone without the network; it syncs later.
  final bool offline;

  bool get isCheckedIn => result == checkedInResult;
  bool get isAlready => result == alreadyResult;
  bool get isInvalid => !isCheckedIn && !isAlready;

  factory CheckInResult.fromJson(Map<String, dynamic> json) => CheckInResult(
    result: json['result'] as String? ?? invalidResult,
    message: json['message'] as String? ?? 'Not a valid ticket.',
    ticket: json['ticket'] is Map<String, dynamic>
        ? CheckInTicket.fromJson(json['ticket'] as Map<String, dynamic>)
        : null,
    checkedIn: (json['checkedIn'] as num?)?.toInt(),
    total: (json['total'] as num?)?.toInt(),
    code: json['code'] as String?,
  );
}

/// `POST …/check-in/sync`: one result per scan, in order, and the counts after.
class CheckInSyncResult {
  const CheckInSyncResult({required this.results, this.checkedIn, this.total});

  final List<CheckInResult> results;
  final int? checkedIn;
  final int? total;

  factory CheckInSyncResult.fromJson(Map<String, dynamic> json) => CheckInSyncResult(
    results: [
      for (final r in (json['results'] as List? ?? const []).whereType<Map<String, dynamic>>())
        CheckInResult.fromJson(r),
    ],
    checkedIn: (json['checkedIn'] as num?)?.toInt(),
    total: (json['total'] as num?)?.toInt(),
  );
}

/// `GET …/guests`: live tickets with the counts and the age limit.
class EventGuestList {
  const EventGuestList({required this.guests, this.checkedIn = 0, this.total = 0, this.ageLimit});

  final List<CheckInTicket> guests;
  final int checkedIn;
  final int total;
  final String? ageLimit;

  factory EventGuestList.fromJson(Map<String, dynamic> json) => EventGuestList(
    guests: [
      for (final g in (json['guests'] as List? ?? const []).whereType<Map<String, dynamic>>())
        CheckInTicket.fromJson(g),
    ],
    checkedIn: (json['checkedIn'] as num?)?.toInt() ?? 0,
    total: (json['total'] as num?)?.toInt() ?? 0,
    ageLimit: json['ageLimit'] as String?,
  );
}

/// `GET …/check-in/manifest`: what the scanner needs to work offline — the public key that
/// checks a code's signature and every ticket that still admits someone.
class CheckInManifest {
  const CheckInManifest({
    required this.eventId,
    required this.publicKey,
    this.codePrefix = 'S3T1.',
    this.ageLimit,
    this.generatedAt,
    this.tickets = const [],
    this.checkedIn = 0,
    this.total = 0,
  });

  final String eventId;

  /// Ed25519, standard base64 of the raw 32-byte key.
  final String publicKey;
  final String codePrefix;
  final String? ageLimit;
  final DateTime? generatedAt;
  final List<CheckInTicket> tickets;
  final int checkedIn;
  final int total;

  factory CheckInManifest.fromJson(Map<String, dynamic> json) => CheckInManifest(
    eventId: json['eventId'] as String? ?? '',
    publicKey: json['publicKey'] as String? ?? '',
    codePrefix: json['codePrefix'] as String? ?? 'S3T1.',
    ageLimit: json['ageLimit'] as String?,
    generatedAt: DateTime.tryParse(json['generatedAt'] as String? ?? '')?.toLocal(),
    tickets: [
      for (final t in (json['tickets'] as List? ?? const []).whereType<Map<String, dynamic>>())
        CheckInTicket.fromJson(t),
    ],
    checkedIn: (json['checkedIn'] as num?)?.toInt() ?? 0,
    total: (json['total'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'eventId': eventId,
    'publicKey': publicKey,
    'codePrefix': codePrefix,
    'ageLimit': ageLimit,
    'generatedAt': generatedAt?.toUtc().toIso8601String(),
    'tickets': [for (final t in tickets) t.toJson()],
    'checkedIn': checkedIn,
    'total': total,
  };
}

/// `GET …/cancel-preview`: what cancelling would do, for the host to see first (4.5).
class EventCancelPreview {
  const EventCancelPreview({
    this.ticketsToVoid = 0,
    this.ordersToRefund = 0,
    this.refundTotalCents = 0,
    this.cardFeesCents = 0,
    this.waitlistCount = 0,
    this.guestsToNotify = 0,
  });

  final int ticketsToVoid;
  final int ordersToRefund;
  final int refundTotalCents;

  /// The card processing fees the host pays.
  final int cardFeesCents;
  final int waitlistCount;
  final int guestsToNotify;

  factory EventCancelPreview.fromJson(Map<String, dynamic> json) {
    int n(String k) => (json[k] as num?)?.toInt() ?? 0;
    return EventCancelPreview(
      ticketsToVoid: n('ticketsToVoid'),
      ordersToRefund: n('ordersToRefund'),
      refundTotalCents: n('refundTotalCents'),
      cardFeesCents: n('cardFeesCents'),
      waitlistCount: n('waitlistCount'),
      guestsToNotify: n('guestsToNotify'),
    );
  }
}

/// `POST …/orders/:orderId/refund`: the order after it, plus what was refunded (4.1).
class EventRefundResult {
  const EventRefundResult({required this.order, required this.status, this.amountCents = 0, this.ticketIds = const []});

  final EventOrderStatus order;

  /// `partly_refunded`, `refunded` or `already_refunded`.
  final String status;
  final int amountCents;
  final List<String> ticketIds;

  factory EventRefundResult.fromJson(Map<String, dynamic> json) {
    final refund = json['refund'] is Map<String, dynamic>
        ? json['refund'] as Map<String, dynamic>
        : const <String, dynamic>{};
    return EventRefundResult(
      order: EventOrderStatus.fromJson(json),
      status: refund['status'] as String? ?? json['status'] as String? ?? '',
      amountCents: (refund['amountCents'] as num?)?.toInt() ?? 0,
      ticketIds: [for (final id in (refund['ticketIds'] as List? ?? const [])) '$id'],
    );
  }
}
