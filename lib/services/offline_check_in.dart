import 'dart:async';
import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

import '../models/event_check_in.dart';
import 'api_exception.dart';
import 'cache_service.dart';
import 'connectivity_service.dart';
import 'event_service.dart';

/// Where the offline scanner keeps its manifest, its own check-ins and the scans still to
/// send. Hive (through [CacheService]) in the app; memory in tests.
abstract class CheckInStore {
  String? read(String key);
  Future<void> write(String key, String value);
}

class _CacheCheckInStore implements CheckInStore {
  const _CacheCheckInStore();

  @override
  String? read(String key) => CacheService.instance.readRaw(key);

  @override
  Future<void> write(String key, String value) => CacheService.instance.writeRaw(key, value);
}

@visibleForTesting
class MemoryCheckInStore implements CheckInStore {
  final values = <String, String>{};

  @override
  String? read(String key) => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

/// A ticket QR code read without the network (handoff 4.3): `S3T1.` then unpadded base64url
/// of 97 bytes — `0x01`, the ticket UUID (16), the event UUID (16) and an Ed25519 signature
/// (64) over the first 33 bytes.
class TicketCode {
  const TicketCode._();

  static const prefix = 'S3T1.';
  static const _length = 97;
  static const _signed = 33;

  /// (ticket id, event id) for a correctly signed code, else null. [publicKey] is standard
  /// base64 of the raw 32-byte Ed25519 key. Never throws on bad input.
  static Future<({String ticketId, String eventId})?> read(
    String code,
    String publicKey, {
    String codePrefix = prefix,
  }) async {
    final value = code.trim();
    if (!value.startsWith(codePrefix)) return null;
    final List<int> raw;
    final List<int> key;
    try {
      raw = base64Url.decode(base64Url.normalize(value.substring(codePrefix.length)));
      key = base64.decode(publicKey.trim());
    } on FormatException {
      return null;
    }
    if (raw.length != _length || raw[0] != 0x01 || key.length != 32) return null;
    final ok = await Ed25519().verify(
      raw.sublist(0, _signed),
      signature: Signature(raw.sublist(_signed), publicKey: SimplePublicKey(key, type: KeyPairType.ed25519)),
    );
    if (!ok) return null;
    return (ticketId: uuidString(raw.sublist(1, 17)), eventId: uuidString(raw.sublist(17, 33)));
  }

  /// 16 bytes as `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`, lower case.
  static String uuidString(List<int> bytes) {
    final hex = [for (final b in bytes) b.toRadixString(16).padLeft(2, '0')].join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}

/// One scan made offline, waiting for `…/check-in/sync`.
class QueuedScan {
  const QueuedScan({required this.code, required this.scannedAt, this.ticketId});

  final String code;
  final DateTime scannedAt;
  final String? ticketId;

  factory QueuedScan.fromJson(Map<String, dynamic> json) => QueuedScan(
    code: json['code'] as String? ?? '',
    scannedAt: DateTime.tryParse(json['scannedAt'] as String? ?? '') ?? DateTime.now(),
    ticketId: json['ticketId'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'code': code,
    'scannedAt': scannedAt.toUtc().toIso8601String(),
    'ticketId': ?ticketId,
  };
}

/// Check-in without the network (handoff 4.3): the manifest downloaded when the scanner
/// opens, codes checked by their signature, a list of tickets this phone let in, and a queue
/// of scans sent in batches of up to 500 once the phone is back online.
class OfflineCheckIn {
  OfflineCheckIn._();
  static final OfflineCheckIn instance = OfflineCheckIn._();

  static const maxBatch = 500;

  CheckInStore _store = const _CacheCheckInStore();
  bool _hooked = false;
  final _syncing = <String, Future<CheckInSyncResult?>>{};

  @visibleForTesting
  set debugStore(CheckInStore store) => _store = store;

  @visibleForTesting
  void debugReset() {
    _store = const _CacheCheckInStore();
    _syncing.clear();
  }

  static String _manifestKey(String eventId) => 'checkin.manifest.$eventId';
  static String _localKey(String eventId) => 'checkin.local.$eventId';
  static String _queueKey(String eventId) => 'checkin.queue.$eventId';
  static const _pendingKey = 'checkin.pending';

  // --- the manifest --------------------------------------------------------------------------

  CheckInManifest? manifest(String eventId) {
    final raw = _store.read(_manifestKey(eventId));
    if (raw == null) return null;
    try {
      return CheckInManifest.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Keep a fresh manifest. Tickets this phone let in that are still waiting to sync stay
  /// counted; the rest are in the manifest now.
  Future<void> saveManifest(CheckInManifest manifest) async {
    await _store.write(_manifestKey(manifest.eventId), jsonEncode(manifest.toJson()));
    final queued = {for (final s in queue(manifest.eventId)) ?s.ticketId};
    final local = _local(manifest.eventId)..removeWhere((id, _) => !queued.contains(id));
    await _saveLocal(manifest.eventId, local);
  }

  /// Download the manifest and keep it. Null when it couldn't be fetched (the cached one,
  /// if any, stays).
  Future<CheckInManifest?> refresh(String eventId) async {
    try {
      final fresh = await EventService.instance.manifest(eventId);
      await saveManifest(fresh);
      return fresh;
    } catch (_) {
      return null;
    }
  }

  // --- what this phone let in ----------------------------------------------------------------

  Map<String, DateTime> _local(String eventId) {
    final raw = _store.read(_localKey(eventId));
    if (raw == null) return {};
    try {
      return {
        for (final e in (jsonDecode(raw) as Map<String, dynamic>).entries) e.key: ?DateTime.tryParse('${e.value}'),
      };
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveLocal(String eventId, Map<String, DateTime> local) => _store.write(
    _localKey(eventId),
    jsonEncode({for (final e in local.entries) e.key: e.value.toUtc().toIso8601String()}),
  );

  /// Note a ticket the server let in (an online scan or a check-in by hand), so a later
  /// offline scan of it reads Already checked in.
  Future<void> noteCheckedIn(String eventId, CheckInTicket ticket) async {
    if (manifest(eventId) == null) return;
    final local = _local(eventId);
    local[ticket.id] = ticket.checkedInAt ?? DateTime.now();
    await _saveLocal(eventId, local);
  }

  /// (checked in, total) as this phone knows them.
  ({int checkedIn, int total})? counts(String eventId) {
    final m = manifest(eventId);
    if (m == null) return null;
    final local = _local(eventId);
    final inManifest = {for (final t in m.tickets) t.id: t};
    final extra = local.keys.where((id) => inManifest[id] != null && !inManifest[id]!.isCheckedIn).length;
    final checked = m.tickets.where((t) => t.isCheckedIn).length + extra;
    return (checkedIn: checked, total: m.tickets.length);
  }

  // --- a scan ---------------------------------------------------------------------------------

  /// Decide a scan on this phone. A checked-in result is queued to sync.
  Future<CheckInResult> scan(String eventId, String code, {DateTime? at}) async {
    final when = at ?? DateTime.now();
    final m = manifest(eventId);
    CheckInResult invalid(String message, {CheckInTicket? ticket}) =>
        CheckInResult(result: CheckInResult.invalidResult, message: message, ticket: ticket, offline: true);
    if (m == null) {
      return invalid("You're offline, and this event's guest list isn't on this phone yet.");
    }
    final value = code.trim();
    CheckInTicket? ticket;
    if (value.startsWith(m.codePrefix)) {
      final read = await TicketCode.read(value, m.publicKey, codePrefix: m.codePrefix);
      if (read == null) return invalid('Not a valid ticket.');
      if (read.eventId != m.eventId.toLowerCase()) return invalid("Not a valid ticket: it's for a different event.");
      ticket = _find(m, (t) => t.id.toLowerCase() == read.ticketId);
      // Signed, but no longer in the list of live tickets: refunded or voided.
      if (ticket == null) return invalid('Not a valid ticket: it was refunded or cancelled.');
    } else {
      final lower = value.toLowerCase();
      ticket = _find(m, (t) => t.id.toLowerCase() == lower || (t.number?.toLowerCase() == lower));
      if (ticket == null) return invalid('Not a valid ticket.');
    }

    final local = _local(eventId);
    final earlier = local[ticket.id] ?? (ticket.isCheckedIn ? ticket.checkedInAt ?? when : null);
    if (earlier != null) {
      final view = ticket.copyWith(status: 'checked_in', checkedInAt: earlier);
      final c = counts(eventId);
      return CheckInResult(
        result: CheckInResult.alreadyResult,
        message: 'Already checked in at ${_clock(earlier.toLocal())}.',
        ticket: view,
        checkedIn: c?.checkedIn,
        total: c?.total,
        code: value,
        offline: true,
      );
    }
    local[ticket.id] = when;
    await _saveLocal(eventId, local);
    await _enqueue(eventId, QueuedScan(code: value, scannedAt: when, ticketId: ticket.id));
    final view = ticket.copyWith(status: 'checked_in', checkedInAt: when);
    final c = counts(eventId);
    final place = view.position != null && view.of != null ? ' (${view.position} of ${view.of})' : '';
    return CheckInResult(
      result: CheckInResult.checkedInResult,
      message: 'Checked in: ${view.displayName}, ${view.ticketTypeName ?? 'Ticket'}$place.',
      ticket: view,
      checkedIn: c?.checkedIn,
      total: c?.total,
      code: value,
      offline: true,
    );
  }

  /// `8:14 PM`.
  static String _clock(DateTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    return '$h:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'AM' : 'PM'}';
  }

  static CheckInTicket? _find(CheckInManifest m, bool Function(CheckInTicket t) test) {
    for (final t in m.tickets) {
      if (test(t)) return t;
    }
    return null;
  }

  // --- the queue ----------------------------------------------------------------------------

  List<QueuedScan> queue(String eventId) {
    final raw = _store.read(_queueKey(eventId));
    if (raw == null) return const [];
    try {
      return [for (final s in (jsonDecode(raw) as List).whereType<Map<String, dynamic>>()) QueuedScan.fromJson(s)];
    } catch (_) {
      return const [];
    }
  }

  int pending(String eventId) => queue(eventId).length;

  Future<void> _saveQueue(String eventId, List<QueuedScan> scans) async {
    await _store.write(_queueKey(eventId), jsonEncode([for (final s in scans) s.toJson()]));
    final events = _pendingEvents();
    scans.isEmpty ? events.remove(eventId) : events.add(eventId);
    await _store.write(_pendingKey, jsonEncode(events.toList()));
  }

  Set<String> _pendingEvents() {
    final raw = _store.read(_pendingKey);
    if (raw == null) return {};
    try {
      return {for (final id in jsonDecode(raw) as List) '$id'};
    } catch (_) {
      return {};
    }
  }

  Future<void> _enqueue(String eventId, QueuedScan scan) async {
    await _saveQueue(eventId, [...queue(eventId), scan]);
    ensureReconnectHook();
  }

  /// Send the event's queued scans, oldest first, in batches of up to [maxBatch]. Null when
  /// there was nothing to send or the network is still away (the queue stays). A request the
  /// server refuses outright (the event stopped checking in, or this phone may not scan it)
  /// drops the scans rather than retrying them forever.
  Future<CheckInSyncResult?> sync(String eventId) {
    return _syncing[eventId] ??= _sync(eventId).whenComplete(() {
      _syncing.remove(eventId);
    });
  }

  Future<CheckInSyncResult?> _sync(String eventId) async {
    CheckInSyncResult? last;
    final results = <CheckInResult>[];
    while (true) {
      final scans = queue(eventId);
      if (scans.isEmpty) break;
      final batch = scans.take(maxBatch).toList();
      try {
        last = await EventService.instance.syncCheckIns(eventId, [
          for (final s in batch) (code: s.code, scannedAt: s.scannedAt),
        ]);
        results.addAll(last.results);
      } on ApiException catch (e) {
        final status = e.statusCode;
        if (status == null || status >= 500 || status == 401 || status == 429) break;
      } catch (_) {
        break;
      }
      await _saveQueue(eventId, queue(eventId).skip(batch.length).toList());
    }
    if (last == null) return null;
    return CheckInSyncResult(results: results, checkedIn: last.checkedIn, total: last.total);
  }

  /// Sync every event with scans waiting.
  Future<void> syncAll() async {
    for (final eventId in _pendingEvents().toList()) {
      await sync(eventId);
    }
  }

  /// Sync on reconnect, once per app run.
  void ensureReconnectHook() {
    if (_hooked) return;
    _hooked = true;
    ConnectivityService.instance.addReconnectHook(syncAll);
  }
}
