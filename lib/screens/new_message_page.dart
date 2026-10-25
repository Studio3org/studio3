import 'dart:async';

import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../services/auth_session.dart';
import '../services/chat_service.dart';
import '../services/social_service.dart';
import '../theme/studio_colors.dart';
import '../theme/studio_type.dart';
import '../widgets/post_picker_search_field.dart';
import '../widgets/studio/studio_avatar.dart';
import 'conversation_thread_page.dart';

/// A person to message.
class MessageContact {
  const MessageContact({required this.username, required this.name, this.avatarUrl});

  final String username;
  final String name;
  final String? avatarUrl;
}

/// New message (`NewMessage`): opened from the + on the Messages tab.
///
/// Cancel and "New message"; a search of artists and collectors by name or handle (the
/// server's people search); before typing, "Artists you follow" then "Recent" (people
/// messaged lately). Rows: 44 avatar, name 15/500, "@handle" 12 Graphite. Tapping a person
/// opens the chat with them; nothing is attached.
class NewMessagePage extends StatefulWidget {
  const NewMessagePage({
    super.key,
    this.recent = const [],
    this.debugFollowing,
    this.debugSearch,
  });

  /// People from the inbox, newest first.
  final List<MessageContact> recent;

  /// For tests: who you follow, instead of loading it.
  @visibleForTesting
  final List<MessageContact>? debugFollowing;

  /// For tests: the people search.
  @visibleForTesting
  final Future<List<MessageContact>> Function(String query)? debugSearch;

  @override
  State<NewMessagePage> createState() => _NewMessagePageState();
}

class _NewMessagePageState extends State<NewMessagePage> {
  final _search = TextEditingController();
  Timer? _debounce;
  List<MessageContact> _following = const [];
  List<MessageContact>? _results;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    final given = widget.debugFollowing;
    if (given != null) {
      _following = given;
    } else {
      _loadFollowing();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadFollowing() async {
    final me = AuthSession.instance.user?.username;
    if (me == null || me.isEmpty) return;
    try {
      final page = await SocialService.instance.listFollowing(me);
      if (!mounted) return;
      setState(() {
        _following = [
          for (final u in page.items)
            MessageContact(username: u.username, name: u.name, avatarUrl: u.profilePhotoUrl),
        ];
      });
    } catch (_) {}
  }

  Future<List<MessageContact>> _searchPeople(String query) async {
    final search = widget.debugSearch;
    if (search != null) return search(query);
    final users = await ChatService.instance.searchUsers(query);
    final me = AuthSession.instance.user?.username;
    return [
      for (final MessageableUser u in users)
        if (u.username != me)
          MessageContact(username: u.username, name: u.name, avatarUrl: u.profilePhotoUrl),
    ];
  }

  void _onQuery(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.isEmpty) {
      setState(() => _results = null);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      final request = ++_request;
      List<MessageContact> found;
      try {
        found = await _searchPeople(query);
      } catch (_) {
        found = const [];
      }
      if (mounted && request == _request) setState(() => _results = found);
    });
  }

  Future<void> _open(MessageContact person) async {
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => ConversationThreadPage(
          otherPartyUsername: person.username,
          otherPartyName: person.name,
          otherPartyAvatarUrl: person.avatarUrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final results = _results;
    final followingNames = _following.map((p) => p.username).toSet();
    final recent = widget.recent.where((p) => !followingNames.contains(p.username)).toList();
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
              child: SizedBox(
                height: 44,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(
                      'New message',
                      style: StudioType.sans(16, weight: StudioType.medium, color: c.textPrimary),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Semantics(
                        button: true,
                        child: GestureDetector(
                          onTap: () => Navigator.maybePop(context),
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                            child: Text(
                              'Cancel',
                              style: StudioType.sans(15, color: c.textPrimary),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: PostPickerSearchField(
                controller: _search,
                hintText: 'Search artists and collectors',
                autofocus: false,
                onChanged: _onQuery,
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children: [
                  if (results != null) ...[
                    if (results.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 24),
                        child: Text(
                          'No one by that name',
                          style: StudioType.body14(color: c.textSecondary),
                        ),
                      ),
                    for (final p in results) _PersonRow(person: p, onTap: () => _open(p)),
                  ] else ...[
                    if (_following.isNotEmpty) ...[
                      const _Label('Artists you follow'),
                      for (final p in _following) _PersonRow(person: p, onTap: () => _open(p)),
                    ],
                    if (recent.isNotEmpty) ...[
                      const _Label('Recent'),
                      for (final p in recent) _PersonRow(person: p, onTap: () => _open(p)),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mono 11/500 Tertiary caps label, 16 above and 2 below.
class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 2),
      child: Text(
        text.toUpperCase(),
        style: StudioType.mono(
          11,
          weight: StudioType.medium,
          color: context.studio.textTertiary,
        ).copyWith(letterSpacing: 0.5),
      ),
    );
  }
}

/// 44 avatar, 12 gap, name 15/500 over "@handle" 12 Graphite; 10 vertical padding.
class _PersonRow extends StatelessWidget {
  const _PersonRow({required this.person, required this.onTap});

  final MessageContact person;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              StudioAvatar(url: person.avatarUrl, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      person.name.isEmpty ? person.username : person.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: StudioType.sans(15, weight: StudioType.medium, color: c.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@${person.username}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: StudioType.caption12(color: c.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
