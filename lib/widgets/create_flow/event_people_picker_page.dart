import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/follow_user_summary.dart';
import '../../services/auth_session.dart';
import '../../services/chat_service.dart';
import '../../services/social_service.dart';
import '../../theme/home_feed_tokens.dart';
import '../post_picker_search_field.dart';
import '../profile_avatar.dart';
import 'create_flow_widgets.dart';
import 'event_lineup_models.dart';
import '../loading/app_skeletons.dart';

/// Search/select a person for event co-hosts or featured artists.
class EventPeoplePickerPage extends StatefulWidget {
  const EventPeoplePickerPage({
    super.key,
    required this.title,
    required this.excludeUsernames,
  });

  final String title;
  final Set<String> excludeUsernames;

  static Future<EventLineupPerson?> open(
    BuildContext context, {
    required String title,
    required Set<String> excludeUsernames,
  }) {
    return Navigator.of(context).push<EventLineupPerson>(
      MaterialPageRoute(
        builder: (_) => EventPeoplePickerPage(
          title: title,
          excludeUsernames: excludeUsernames,
        ),
      ),
    );
  }

  @override
  State<EventPeoplePickerPage> createState() => _EventPeoplePickerPageState();
}

class _EventPeoplePickerPageState extends State<EventPeoplePickerPage> {
  final _search = TextEditingController();
  List<EventLineupPerson> _suggestions = [];
  List<EventLineupPerson> _results = [];
  bool _loadingSuggestions = true;
  bool _searching = false;
  String _query = '';

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

  EventLineupPerson? _mapFollow(FollowUserSummary user) {
    if (user.username.isEmpty) return null;
    if (_blocked.contains(user.username.toLowerCase())) return null;
    return EventLineupPerson(
      username: user.username,
      name: user.name,
      avatarUrl: user.profilePhotoUrl,
    );
  }

  Future<void> _loadSuggestions() async {
    final username = AuthSession.instance.user?.username;
    if (username == null || username.isEmpty) {
      setState(() => _loadingSuggestions = false);
      return;
    }
    try {
      final page = await SocialService.instance.listFollowing(username);
      if (!mounted) return;
      setState(() {
        _suggestions = page.items
            .map(_mapFollow)
            .whereType<EventLineupPerson>()
            .toList();
        _loadingSuggestions = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingSuggestions = false);
    }
  }

  Future<void> _onQuery(String value) async {
    final query = value.trim();
    setState(() => _query = query);
    if (query.isEmpty) {
      setState(() {
        _results = [];
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
            .where(
              (user) =>
                  user.username.isNotEmpty &&
                  !_blocked.contains(user.username.toLowerCase()),
            )
            .map(
              (user) => EventLineupPerson(
                username: user.username,
                name: user.displayName,
                avatarUrl: user.profilePhotoUrl,
              ),
            )
            .toList();
        _searching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final searching = _query.isNotEmpty;
    final people = searching ? _results : _suggestions;
    final loading = searching ? _searching : _loadingSuggestions;

    return Scaffold(
      backgroundColor: HomeFeedTokens.background,
      body: Column(
        children: [
          CreateFlowBanner(
            topInset: topInset,
            title: widget.title,
            onClose: () => Navigator.pop(context),
            useBackChevron: true,
            height: 53,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: PostPickerSearchField(
              controller: _search,
              hintText: 'Search people',
              onChanged: _onQuery,
            ),
          ),
          Expanded(
            child: loading && people.isEmpty
                ? const UserListSkeleton(padding: EdgeInsets.fromLTRB(24, 0, 24, 16))
                : people.isEmpty
                    ? Center(
                        child: Text(
                          searching
                              ? 'No people found'
                              : 'Follow artists to add them here, or search.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.geist(
                            fontSize: 13,
                            color: HomeFeedTokens.textSecondary,
                          ),
                        ),
                      )
                    : ListView.separated(
                        primary: false,
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                        itemCount: people.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          final person = people[index];
                          return GestureDetector(
                            onTap: () => Navigator.pop(context, person),
                            behavior: HitTestBehavior.opaque,
                            child: Row(
                              children: [
                                ProfileAvatar(
                                  url: person.avatarUrl,
                                  size: 48,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        person.displayName,
                                        style: GoogleFonts.geist(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: HomeFeedTokens.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        person.handle,
                                        style: GoogleFonts.geist(
                                          fontSize: 12,
                                          color: HomeFeedTokens.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
