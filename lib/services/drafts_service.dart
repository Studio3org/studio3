import 'package:shared_preferences/shared_preferences.dart';

import '../models/piece_summary.dart';
import '../models/post_summary.dart';
import 'api_client.dart';
import 'api_exception.dart';
import 'auth_session.dart';
import 'piece_service.dart';
import 'post_service.dart';

/// One row of `Drafts`: a piece or a Scene someone started but didn't post.
class DraftEntry {
  const DraftEntry.piece(PieceSummary this.piece, {this.failed = false}) : scene = null;

  const DraftEntry.scene(PostSummary this.scene, {this.failed = false}) : piece = null;

  final PieceSummary? piece;
  final PostSummary? scene;

  /// Saved, then going live failed: "Didn't publish. Tap to try again."
  final bool failed;

  bool get isScene => scene != null;

  String get id => piece?.id ?? scene!.id;

  /// The last edit when the server sends it, otherwise when it was first saved.
  DateTime? get editedAt => piece != null
      ? (piece!.updatedAt ?? piece!.createdAt)
      : (scene!.updatedAt ?? scene!.createdAt);

  DraftEntry withFailed(bool value) =>
      piece != null ? DraftEntry.piece(piece!, failed: value) : DraftEntry.scene(scene!, failed: value);
}

/// The person's unposted work (`Drafts`): pieces and Scenes saved as drafts on the server,
/// newest edit first, from `GET /api/user/me/drafts` (BACKEND_CHANGES B33). A server without
/// that list gives piece drafts only, from the profile's pieces.
///
/// A draft whose publish failed says so on every device when the server keeps the flag (B33);
/// it is also remembered on this device, so the red line shows even when telling the server
/// failed too (or the server doesn't keep it).
class DraftsService {
  DraftsService._();
  static final DraftsService instance = DraftsService._();

  static const _failedKey = 'drafts.failed';

  final _api = ApiClient.instance;

  /// Every draft, newest edit first.
  Future<List<DraftEntry>> all() async {
    final local = await failedIds();
    List<DraftEntry> entries;
    try {
      final json = await _api.get('/api/user/me/drafts', auth: true);
      final data = _api.extractData(json);
      final items = data is Map ? (data['items'] as List? ?? const []) : const [];
      entries = [
        for (final item in items.whereType<Map<String, dynamic>>())
          if (item['type'] == 'post')
            DraftEntry.scene(PostSummary.fromJson(item))
          else
            DraftEntry.piece(PieceSummary.fromJson(item)),
      ];
    } on ApiException catch (e) {
      if (e.statusCode != 404) rethrow;
      // An older server: piece drafts from the profile.
      entries = [for (final p in await pieces()) DraftEntry.piece(p)];
    }
    return [
      for (final e in entries)
        e.withFailed(local.contains(e.id) || (e.piece?.publishFailed ?? e.scene!.publishFailed)),
    ];
  }

  /// Piece drafts from the profile, newest first (a server without the drafts list).
  Future<List<PieceSummary>> pieces() async {
    final username = AuthSession.instance.user?.username;
    if (username == null || username.isEmpty) return const [];
    final all = await PieceService.instance.getUserPieces(username);
    return all.where((p) => p.status == 'draft').toList();
  }

  Future<Set<String>> failedIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getStringList(_failedKey) ?? const []).toSet();
    } catch (_) {
      return const {};
    }
  }

  /// Publishing [id] failed after it was saved, on this device only.
  Future<void> markFailed(String id) => _edit((ids) => ids.add(id));

  /// Publishing [id] (a piece, or a Scene with [scene]) failed after it was saved: remembered
  /// here and, best effort, told to the server so their other devices show it too (B33).
  Future<void> publishFailed(String id, {bool scene = false}) async {
    await markFailed(id);
    try {
      if (scene) {
        await PostService.instance.update(id, {'publishFailed': true});
      } else {
        await PieceService.instance.update(id, {'publishFailed': true});
      }
    } catch (_) {
      // Offline, most likely: this device still shows it.
    }
  }

  Future<void> clearFailed(String id) => _edit((ids) => ids.remove(id));

  /// "Tap to try again": takes the piece draft live.
  Future<PieceSummary> publish(String pieceId) async {
    final live = await PieceService.instance.update(pieceId, {'status': 'live'});
    await clearFailed(pieceId);
    return live;
  }

  /// Takes a Scene draft live.
  Future<PostSummary> publishScene(String postId) async {
    final live = await PostService.instance.update(postId, {'status': 'live'});
    await clearFailed(postId);
    return live;
  }

  Future<void> delete(DraftEntry draft) async {
    if (draft.isScene) {
      await PostService.instance.delete(draft.id);
    } else {
      await PieceService.instance.delete(draft.id);
    }
    await clearFailed(draft.id);
  }

  /// Best effort: losing the red line never stands in the way of posting.
  Future<void> _edit(void Function(Set<String> ids) change) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = (prefs.getStringList(_failedKey) ?? const []).toSet();
      change(ids);
      await prefs.setStringList(_failedKey, ids.toList());
    } catch (_) {}
  }
}
