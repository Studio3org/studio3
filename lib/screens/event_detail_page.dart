import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/studio_event.dart';
import '../services/api_exception.dart';
import '../services/event_service.dart';
import '../services/saved_content_store.dart';
import '../theme/home_feed_tokens.dart';
import '../widgets/home_feed/home_feed_widgets.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/share/share_sheet.dart';

void openEventDetail(BuildContext context, StudioEvent event) {
  Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => EventDetailPage(event: event),
    ),
  );
}

/// Event detail — Figma `2783:13329`.
class EventDetailPage extends StatefulWidget {
  const EventDetailPage({super.key, required this.event});

  final StudioEvent event;

  @override
  State<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends State<EventDetailPage> {
  final _store = SavedContentStore.instance;
  bool _detailsExpanded = false;
  bool _followingHost = false;

  /// The full event, once fetched.
  ///
  /// The card that opened this page carries no bill, no cohosts and no description — those
  /// only come with the detail payload. Rendering the card first and filling in behind it
  /// means the header, title and time are on screen immediately instead of behind a spinner.
  StudioEvent? _detail;

  StudioEvent get _event => _detail ?? widget.event;

  bool _rsvping = false;

  /// Say you're coming, or take it back.
  ///
  /// The response carries the fresh counts, so the button and the "12 going" line update
  /// from what the server actually recorded rather than from an optimistic guess that a
  /// full event would get wrong.
  Future<void> _toggleRsvp() async {
    final going = !_event.viewerIsGoing;
    setState(() => _rsvping = true);
    try {
      final result = await EventService.instance.setRsvp(_event.id, going: going);
      if (!mounted) return;
      setState(() {
        _rsvping = false;
        _detail = _event.copyWith(
          viewerIsGoing: result.going,
          rsvpCount: result.rsvpCount,
          spotsLeft: result.spotsLeft,
          isFull: result.isFull,
        );
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _rsvping = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      // A 409 means somebody took the last place while this screen was open, so the counts
      // on it are already wrong.
      await _loadDetail();
    } catch (_) {
      if (!mounted) return;
      setState(() => _rsvping = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update your RSVP.')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStore);
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    try {
      final full = await EventService.instance.getById(widget.event.id);
      if (!mounted) return;
      setState(() => _detail = full);
    } catch (_) {
      // The card's own fields still render. A failed refresh is not worth an error screen
      // over content that is already on the page.
    }
  }

  /// Save on the server, then mirror locally so the Saved tab updates without a round trip.
  Future<void> _toggleSaved() async {
    final wasSaved = _store.isSaved(_event.id);
    try {
      await EventService.instance.setSaved(_event.id, saved: !wasSaved);
      if (!mounted) return;
      _store.toggleEvent(_event);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save that event.')),
      );
    }
  }

  @override
  void dispose() {
    _store.removeListener(_onStore);
    super.dispose();
  }

  void _onStore() {
    if (mounted) setState(() {});
  }

  TextStyle _geist({
    required double size,
    FontWeight weight = FontWeight.w400,
    Color color = HomeFeedTokens.textPrimary,
  }) {
    return GoogleFonts.geist(
      fontSize: size,
      fontWeight: weight,
      color: color,
    );
  }

  Future<void> _share() {
    // The custom-scheme link works today and needs no domain verification, which the
    // https:// one still does — see AppLinkConfig. Someone without the app installed gets
    // the details as text, which is the useful half of the message anyway.
    return ShareSheet.show(
      context,
      shareText: '${_event.title} · ${_event.venue}\n${_event.scheduleLine}\n'
          'studio3://event/${_event.id}',
      copyLabel: 'Copy',
      copiedMessage: 'Copied',
    );
  }

  @override
  Widget build(BuildContext context) {
    final saved = _store.isSaved(_event.id);
    final bottomInset = MediaQuery.paddingOf(context).bottom + 88;
    final width = MediaQuery.sizeOf(context).width;
    final heroHeight = width * (519 / 390);
    const scrim = Color(0xCC231F1B);
    final details = _event.details;
    final collapsed =
        details.length > 180 ? '${details.substring(0, 180).trim()}...' : details;

    return Scaffold(
      backgroundColor: HomeFeedTokens.detailBackground,
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                SizedBox(
                  height: heroHeight,
                  width: width,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      FeedPicsumImage(url: _event.imageUrl),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.center,
                            colors: [scrim, Color(0x00000000)],
                          ),
                        ),
                      ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.center,
                            colors: [scrim, Color(0x00000000)],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: SafeArea(
                          bottom: false,
                          child: SizedBox(
                            height: 56,
                            child: Row(
                              children: [
                                const SizedBox(width: 10),
                                GestureDetector(
                                  onTap: () => Navigator.of(context).pop(),
                                  behavior: HitTestBehavior.opaque,
                                  child: SvgPicture.asset(
                                    'assets/piece/hero_back.svg',
                                    width: 11,
                                    height: 20,
                                  ),
                                ),
                                const Spacer(),
                                GestureDetector(
                                  onTap: _toggleSaved,
                                  behavior: HitTestBehavior.opaque,
                                  child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: SvgPicture.asset(
                                      saved
                                          ? 'assets/piece/hero_bookmark_fill.svg'
                                          : 'assets/piece/hero_bookmark.svg',
                                      width: 16,
                                      height: 20,
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: _share,
                                  behavior: HitTestBehavior.opaque,
                                  child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: SvgPicture.asset(
                                      'assets/piece/hero_share.svg',
                                      width: 18,
                                      height: 22,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 17,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _event.kicker,
                              style: _geist(
                                size: 10,
                                color: HomeFeedTokens.textInverse,
                              ),
                            ),
                            Text(
                              _event.title,
                              style: _geist(
                                size: 24,
                                weight: FontWeight.w700,
                                color: HomeFeedTokens.textInverse,
                              ),
                            ),
                            Opacity(
                              opacity: 0.85,
                              child: Text(
                                _event.venue,
                                style: _geist(
                                  size: 13,
                                  color: HomeFeedTokens.textInverse,
                                ),
                              ),
                            ),
                            Opacity(
                              opacity: 0.85,
                              child: Text(
                                _event.scheduleLine,
                                style: _geist(
                                  size: 13,
                                  color: HomeFeedTokens.textInverse,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                DecoratedBox(
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFC4C4C4)),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 16, 10, 16),
                    child: Row(
                      children: [
                        ProfileAvatar(
                          url: _event.hostAvatarUrl,
                          size: 28,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Hosted by ${_event.hostName}',
                            style: _geist(size: 12),
                          ),
                        ),
                        GestureDetector(
                          onTap: () =>
                              setState(() => _followingHost = !_followingHost),
                          child: Container(
                            width: 96,
                            height: 28,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _followingHost
                                  ? HomeFeedTokens.neutral800
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: HomeFeedTokens.neutral800,
                              ),
                            ),
                            child: Text(
                              _followingHost ? 'Following' : 'Follow',
                              style: _geist(
                                size: 12,
                                color: _followingHost
                                    ? HomeFeedTokens.textInverse
                                    : HomeFeedTokens.neutral800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 24, 10, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Details',
                        style: _geist(
                          size: 13,
                          weight: FontWeight.w500,
                          color: HomeFeedTokens.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _detailsExpanded ? details : collapsed,
                        style: _geist(size: 16),
                      ),
                      if (details.length > 180) ...[
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: () => setState(
                            () => _detailsExpanded = !_detailsExpanded,
                          ),
                          child: Text(
                            _detailsExpanded ? 'Show less' : 'Show more',
                            style: _geist(
                              size: 13,
                              color: HomeFeedTokens.textSecondary,
                            ).copyWith(
                              decoration: TextDecoration.underline,
                              decorationColor: HomeFeedTokens.textSecondary,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 32),
                      Text(
                        'Featured artists',
                        style: _geist(
                          size: 13,
                          weight: FontWeight.w500,
                          color: HomeFeedTokens.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(26, 0, 10, 0),
                  child: Row(
                    children: [
                      for (var i = 0; i < _event.artists.length; i++) ...[
                        if (i > 0) const SizedBox(width: 16),
                        SizedBox(
                          width: 79,
                          child: Column(
                            children: [
                              ClipOval(
                                child: SizedBox(
                                  width: 79,
                                  height: 79,
                                  child: FeedPicsumImage(
                                    url: _event.artists[i].avatarUrl ?? '',
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _event.artists[i].displayName,
                                textAlign: TextAlign.center,
                                style: _geist(size: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 32, 10, 0),
                  child: Text(
                    'Pieces at this event',
                    style: _geist(
                      size: 13,
                      weight: FontWeight.w500,
                      color: HomeFeedTokens.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(26, 0, 10, 0),
                  child: Row(
                    children: [
                      for (var i = 0; i < _event.pieceImageUrls.length; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: i == 2 ? 128 : 180,
                            height: 228,
                            child: FeedPicsumImage(
                              url: _event.pieceImageUrls[i],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 32, 10, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Location',
                        style: _geist(
                          size: 13,
                          weight: FontWeight.w500,
                          color: HomeFeedTokens.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(_event.address ?? 'Location to be announced', style: _geist(size: 16)),
                      // The map image and the FAQ list are deliberately absent rather than
                      // faked. Neither has a backend field yet: a map needs a tile provider
                      // nobody has chosen, and FAQs need a column and an editor in the
                      // create flow. Showing a stock map of the wrong place, or somebody
                      // else's answers, would be worse than showing the address alone.
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
          ColoredBox(
            color: HomeFeedTokens.detailBackground,
            child: Padding(
              padding: EdgeInsets.fromLTRB(10, 16, 10, bottomInset),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Entry',
                    style: _geist(
                      size: 13,
                      color: HomeFeedTokens.textSecondary,
                    ),
                  ),
                  Text(_event.priceLabel, style: _geist(size: 20)),
                  const SizedBox(height: 2),
                  Text(
                    _event.rsvpSummary,
                    style: _geist(size: 13, color: HomeFeedTokens.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: FilledButton(
                      // A full event the viewer is not already on keeps its button, disabled
                      // — so "full" reads as a fact about the event rather than as a missing
                      // control.
                      onPressed:
                          _event.canRsvp && !_rsvping ? _toggleRsvp : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: _event.viewerIsGoing
                            ? HomeFeedTokens.skeletonBase
                            : HomeFeedTokens.neutral800,
                        foregroundColor: _event.viewerIsGoing
                            ? HomeFeedTokens.textPrimary
                            : HomeFeedTokens.textInverse,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _rsvping
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              _event.rsvpCtaLabel,
                              style: _geist(
                                size: 16,
                                color: _event.viewerIsGoing
                                    ? HomeFeedTokens.textPrimary
                                    : HomeFeedTokens.textInverse,
                              ),
                            ),
                    ),
                  ),
                  if (_event.viewerIsGoing) ...[
                    const SizedBox(height: 6),
                    Center(
                      child: TextButton(
                        onPressed: _rsvping ? null : _toggleRsvp,
                        child: Text(
                          "Can't make it",
                          style: _geist(
                            size: 13,
                            color: HomeFeedTokens.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

