import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../data/event_dummy_data.dart';
import '../services/saved_content_store.dart';
import '../theme/home_feed_tokens.dart';
import '../widgets/events/event_feed_widgets.dart';
import '../widgets/home_feed/home_feed_widgets.dart';
import '../widgets/profile_avatar.dart';

void openEventDetail(BuildContext context, DummyEvent event) {
  Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => EventDetailPage(event: event),
    ),
  );
}

/// Event detail — Figma `2783:13329`.
class EventDetailPage extends StatefulWidget {
  const EventDetailPage({super.key, required this.event});

  final DummyEvent event;

  @override
  State<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends State<EventDetailPage> {
  final _store = SavedContentStore.instance;
  bool _detailsExpanded = false;
  bool _followingHost = false;
  int? _openFaq;

  DummyEvent get _event => widget.event;

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStore);
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
    return SharePlus.instance.share(
      ShareParams(
        text: '${_event.title} · ${_event.venue}\n${_event.scheduleLine}',
        subject: _event.title,
      ),
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
                                  onTap: () => _store.toggleEvent(_event),
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
                                    url: _event.artists[i].avatarUrl,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _event.artists[i].name,
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
                      Text(_event.address, style: _geist(size: 16)),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: double.infinity,
                            height: 228,
                            child: FeedPicsumImage(url: _event.mapImageUrl),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'FAQs',
                        style: _geist(
                          size: 13,
                          weight: FontWeight.w500,
                          color: HomeFeedTokens.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 13),
                      for (var i = 0; i < _event.faqs.length; i++)
                        _FaqRow(
                          faq: _event.faqs[i],
                          expanded: _openFaq == i,
                          showDivider: i != _event.faqs.length - 1,
                          onTap: () => setState(
                            () => _openFaq = _openFaq == i ? null : i,
                          ),
                        ),
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
                    'From',
                    style: _geist(
                      size: 13,
                      color: HomeFeedTokens.textSecondary,
                    ),
                  ),
                  Text(_event.priceLabel, style: _geist(size: 20)),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: FilledButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Ticketing coming soon'),
                          ),
                        );
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: HomeFeedTokens.neutral800,
                        foregroundColor: HomeFeedTokens.textInverse,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Get tickets',
                        style: _geist(
                          size: 16,
                          color: HomeFeedTokens.textInverse,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FaqRow extends StatelessWidget {
  const _FaqRow({
    required this.faq,
    required this.expanded,
    required this.showDivider,
    required this.onTap,
  });

  final DummyEventFaq faq;
  final bool expanded;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: showDivider
              ? const Border(
                  bottom: BorderSide(color: EventTokens.hairline),
                )
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 28,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        faq.question,
                        style: GoogleFonts.geist(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: HomeFeedTokens.textPrimary,
                        ),
                      ),
                    ),
                    Transform.rotate(
                      angle: expanded ? 3.14159 : 0,
                      child: SvgPicture.asset(
                        'assets/piece/details_chevron.svg',
                        width: 8,
                        height: 4,
                      ),
                    ),
                  ],
                ),
              ),
              if (expanded) ...[
                const SizedBox(height: 8),
                Text(
                  faq.answer,
                  style: GoogleFonts.geist(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: HomeFeedTokens.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
