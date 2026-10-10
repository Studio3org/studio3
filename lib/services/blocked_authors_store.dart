import 'package:flutter/foundation.dart';

/// Usernames blocked during this session, so feeds already on screen can drop
/// that account's pieces, scenes, and comments the moment the block lands
/// (App Store guideline 1.2) instead of waiting for their next refresh — the
/// backend filters blocked accounts out of every fresh fetch from then on.
class BlockedAuthorsStore extends ChangeNotifier {
  BlockedAuthorsStore._();
  static final BlockedAuthorsStore instance = BlockedAuthorsStore._();

  final Set<String> _usernames = {};

  bool isBlocked(String? username) =>
      username != null && _usernames.contains(username.toLowerCase());

  void add(String username) {
    if (_usernames.add(username.toLowerCase())) notifyListeners();
  }

  void remove(String username) {
    if (_usernames.remove(username.toLowerCase())) notifyListeners();
  }

  void clear() => _usernames.clear();
}
