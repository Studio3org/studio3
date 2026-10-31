import 'package:shared_preferences/shared_preferences.dart';

import '../models/piece_summary.dart';
import 'auth_session.dart';
import 'piece_service.dart';

/// The person's unposted work (`Drafts`): pieces saved as drafts on the server. Scenes are
/// not stored until they post (BACKEND_CHANGES B33), so there are no Scene drafts yet.
///
/// A piece whose photos saved but which then failed to go live is remembered on this device,
/// so its row can say "Didn't publish. Tap to try again."
class DraftsService {
  DraftsService._();
  static final DraftsService instance = DraftsService._();

  static const _failedKey = 'drafts.failed';

  /// Newest first (the server's order).
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

  /// Publishing [pieceId] failed after it was saved.
  Future<void> markFailed(String pieceId) => _edit((ids) => ids.add(pieceId));

  Future<void> clearFailed(String pieceId) => _edit((ids) => ids.remove(pieceId));

  /// "Tap to try again": takes the draft live.
  Future<PieceSummary> publish(String pieceId) async {
    final live = await PieceService.instance.update(pieceId, {'status': 'live'});
    await clearFailed(pieceId);
    return live;
  }

  Future<void> delete(String pieceId) async {
    await PieceService.instance.delete(pieceId);
    await clearFailed(pieceId);
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
