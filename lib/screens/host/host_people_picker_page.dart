import 'package:flutter/material.dart';

import '../../models/follow_user_summary.dart';
import '../../services/auth_session.dart';
import '../../services/chat_service.dart';
import '../../services/social_service.dart';
import '../../widgets/create_flow/event_lineup_models.dart';
import '../../widgets/post_picker_search_field.dart';
import '../../widgets/studio/studio.dart';

/// Add a co-host or a featured artist (no board; the `NewMessage` pattern): the top bar, a
/// search field, then people — the ones the host follows until something is typed, search
/// results after. A row is a 40 avatar with the name 15/500 over the handle 13 Graphite; tapping
/// it returns that person.
class HostPeoplePickerPage extends StatefulWidget {
  const HostPeoplePickerPage({super.key, required this.title, this.excludeUsernames = const {}});

  final String title;
  final Set<String> excludeUsernames;

  static Future<EventLineupPerson?> open(
    BuildContext context, {
    required String title,
    Set<String> excludeUsernames = const {},
  }) {
    return Navigator.of(context).push<EventLineupPerson>(
      MaterialPageRoute(builder: (_) => HostPeoplePickerPage(title: title, excludeUsernames: excludeUsernames)),
    );
  }

  @override
  State<HostPeoplePickerPage> createState() => _HostPeoplePickerPageState();
}

class _HostPeoplePickerPageState extends State<HostPeoplePickerPage> {
  final _search = TextEditingController();
  List<EventLineupPerson> _suggestions = const [];
  List<EventLineupPerson> _results = const [];
  bool _loading = true;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Set<String> get _blocked {
    final me = AuthSession.instance.user?.username.toLowerCase();
    return {
      ...widget.excludeUsernames.map((name) => name.toLowerCase()),
      if (me != null && me.isNotEmpty) me,
    };
  }

  EventLineupPerson? _fromFollow(FollowUserSummary user) {
    if (user.username.isEmpty || _blocked.contains(user.username.toLowerCase())) return null;
    return EventLineupPerson(username: user.username, name: user.name, avatarUrl: user.profilePhotoUrl);
  }

  Future<void> _loadSuggestions() async {
    final username = AuthSession.instance.user?.username;
    if (username == null || username.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    try {
      final page = await SocialService.instance.listFollowing(username);
      if (!mounted) return;
      setState(() {
        _suggestions = page.items.map(_fromFollow).whereType<EventLineupPerson>().toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onQuery(String value) async {
    final query = value.trim();
    if (query.isEmpty) {
      setState(() {
        _results = const [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    try {
      final users = await ChatService.instance.searchUsers(query);
      if (!mounted || _search.text.trim() != query) return;
      setState(() {
        _results = users
            .where((u) => u.username.isNotEmpty && !_blocked.contains(u.username.toLowerCase()))
            .map((u) => EventLineupPerson(username: u.username, name: u.displayName, avatarUrl: u.profilePhotoUrl))
            .toList();
        _searching = false;
      });
    } catch (_) {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final typed = _search.text.trim().isNotEmpty;
    final people = typed ? _results : _suggestions;
    final busy = typed ? _searching : _loading;
    return Scaffold(
      backgroundColor: c.background,
      appBar: StudioTopBar(context: context, title: widget.title),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(StudioSpace.marginPage, 6, StudioSpace.marginPage, 40),
        children: [
          PostPickerSearchField(
            controller: _search,
            hintText: 'Search people',
            height: 44,
            onChanged: (v) {
              setState(() {});
              _onQuery(v);
            },
          ),
          Padding(
            padding: const EdgeInsets.only(top: 22, bottom: 6),
            child: Text(
              (typed ? 'Results' : 'People you follow').toUpperCase(),
              style: StudioType.mono(11, weight: StudioType.medium, color: c.textTertiary).copyWith(letterSpacing: 0.5),
            ),
          ),
          if (busy && people.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Center(
                child: SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: c.textSecondary),
                ),
              ),
            )
          else if (people.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                typed ? 'No one by that name.' : 'Search for anyone on Studio 3.',
                style: StudioType.body14(color: c.textSecondary),
              ),
            )
          else
            for (final person in people)
              Semantics(
                button: true,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(person),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
                    child: Row(
                      children: [
                        StudioAvatar(url: person.avatarUrl, size: 40, semanticLabel: person.displayName),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                person.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: StudioType.sans(15, weight: StudioType.medium, color: c.textPrimary),
                              ),
                              Text(person.handle, style: StudioType.label13(color: c.textSecondary)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
