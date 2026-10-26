import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/studio_event.dart';
import '../../theme/collect_detail_tokens.dart' show formatMoney;
import '../studio/studio.dart';

/// `Sat, Nov 21`: the When value in the bottom bar (`EvDetail`).
String eventDayLabel(StudioEvent e) {
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final d = e.startsAt;
  return '${weekdays[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}';
}

/// The line under a piece at the event (`EvDetail`): `$3,500` for sale, `Bid $1,300` (the
/// live high bid, else the starting bid) for an auction, `Sold` once it has gone; nothing for
/// work that is only on show.
String? eventPiecePriceLine(EventLineupItem item) {
  if (item.isAuction) {
    final live = item.auction;
    if (live != null && live.isClosed) {
      return live.winningBidCents != null ? 'Sold' : 'Auction ended';
    }
    final cents = item.currentCents;
    return cents == null ? 'Auction' : 'Bid ${formatMoney(cents)}';
  }
  if (item.mode == 'sale') {
    if (item.pieceStatus == 'sold') return 'Sold';
    final cents = item.priceCents;
    return cents == null ? null : formatMoney(cents);
  }
  return null;
}

/// An event flyer or piece image: the photo, or a plain Surface fill while it loads or when
/// there is none.
class EventCover extends StatelessWidget {
  const EventCover({super.key, required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final placeholder = ColoredBox(color: context.studio.surface);
    if (url.isEmpty) return placeholder;
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, _) => placeholder,
      errorWidget: (_, _, _) => placeholder,
    );
  }
}

/// The flyer at the top (`EvDetail`): full width at 390 × 470 with Ink 35 % → 0 over the
/// top quarter and 0 → 70 % over the bottom half; back, save, share and more as white 22 px
/// icons in 44 targets 6 from the edges; category Mono 11, name 28/500, venue 14 and the
/// Mono 12 schedule, 20 from the sides and 18 from the bottom.
class EventHero extends StatelessWidget {
  const EventHero({
    super.key,
    required this.event,
    required this.saved,
    required this.onBack,
    required this.onSave,
    required this.onShare,
    required this.onMore,
  });

  final StudioEvent event;
  final bool saved;
  final VoidCallback onBack;
  final VoidCallback onSave;
  final VoidCallback onShare;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    const white = StudioColors.galleryWhite;
    final top = MediaQuery.paddingOf(context).top;
    return AspectRatio(
      aspectRatio: 390 / 470,
      child: Stack(
        fit: StackFit.expand,
        children: [
          EventCover(url: event.imageUrl),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0, 0.25, 0.5, 1],
                colors: [Color(0x59111111), Color(0x00111111), Color(0x00111111), Color(0xB3111111)],
              ),
            ),
          ),
          Positioned(
            top: top + 6,
            left: 6,
            right: 6,
            child: Row(
              children: [
                StudioTopIcon(icon: StudioIcons.back, size: 22, onTap: onBack, semanticLabel: 'Back'),
                const Spacer(),
                StudioTopIcon(
                  icon: saved ? StudioIcons.saved : StudioIcons.save,
                  size: 22,
                  onTap: onSave,
                  semanticLabel: saved ? 'Saved' : 'Save',
                ),
                StudioTopIcon(icon: StudioIcons.share, size: 22, onTap: onShare, semanticLabel: 'Share'),
                StudioTopIcon(icon: StudioIcons.more, size: 22, onTap: onMore, semanticLabel: 'More'),
              ],
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(event.kicker, style: StudioType.mono(11, color: white).copyWith(letterSpacing: 0.5)),
                const SizedBox(height: 4),
                Text(
                  event.title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: StudioType.sans(
                    28,
                    weight: StudioType.medium,
                    letterSpacing: -0.5,
                    height: 1.25,
                    color: white,
                  ),
                ),
                if (event.venue.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(event.venue, style: StudioType.sans(14, color: white)),
                ],
                const SizedBox(height: 4),
                Text(event.scheduleLine, style: StudioType.mono(12, color: white)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Hosted by (`EvDetail`): 36 avatar, "Hosted by **Name**" 14, the small Follow; 16 above and
/// below with a Line under it. The host sees "Your event" in place of Follow.
class EventHostRow extends StatelessWidget {
  const EventHostRow({
    super.key,
    required this.event,
    required this.followLabel,
    required this.followFilled,
    required this.onFollow,
    required this.onHost,
    this.followBusy = false,
  });

  final StudioEvent event;
  final String followLabel;
  final bool followFilled;
  final bool followBusy;
  final VoidCallback onFollow;
  final VoidCallback onHost;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final name = event.hostName?.isNotEmpty == true ? event.hostName! : (event.hostUsername ?? '');
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: onHost,
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  StudioAvatar(url: event.hostAvatarUrl, size: 36, semanticLabel: name),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        text: 'Hosted by ',
                        children: [
                          TextSpan(
                            text: name,
                            style: const TextStyle(fontWeight: StudioType.medium),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: StudioType.body14(color: c.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          if (event.isHost)
            Text('Your event', style: StudioType.label13(color: c.textSecondary))
          else
            StudioButton(
              label: followLabel,
              variant: StudioButtonVariant.small,
              filled: followFilled,
              loading: followBusy,
              onPressed: followBusy ? null : onFollow,
            ),
        ],
      ),
    );
  }
}

/// A section heading on the event page: 13 Graphite, regular.
class EventDetailHeading extends StatelessWidget {
  const EventDetailHeading(this.text, {super.key, this.top = 28, this.bottom = 12});

  final String text;
  final double top;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: top, bottom: bottom),
      child: Text(text, style: StudioType.label13(color: context.studio.textSecondary)),
    );
  }
}

/// Details (`EvDetail`): 15 at 1.55, cut after 4 lines with an underlined "Show more" 14
/// Graphite 6 below; "Show less" once open. No link when it fits.
class EventDetailsText extends StatefulWidget {
  const EventDetailsText(this.text, {super.key});

  final String text;

  @override
  State<EventDetailsText> createState() => _EventDetailsTextState();
}

class _EventDetailsTextState extends State<EventDetailsText> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final style = StudioType.sans(15, height: 1.55, color: c.textPrimary);
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          maxLines: 4,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        final long = painter.didExceedMaxLines;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.text,
              maxLines: _open ? null : 4,
              overflow: _open ? null : TextOverflow.ellipsis,
              style: style,
            ),
            if (long)
              GestureDetector(
                onTap: () => setState(() => _open = !_open),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _open ? 'Show less' : 'Show more',
                    style: StudioType.body14(
                      color: c.textSecondary,
                    ).copyWith(decoration: TextDecoration.underline, decorationColor: c.textSecondary),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Featured artists (`EvDetail`): 68 avatars in 76 wide columns, 8 apart, name 12 under
/// them 6 below. Each opens the artist's profile.
class EventArtistsRow extends StatelessWidget {
  const EventArtistsRow({super.key, required this.artists, required this.onArtist});

  final List<EventPerson> artists;
  final void Function(EventPerson artist) onArtist;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < artists.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            GestureDetector(
              onTap: () => onArtist(artists[i]),
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                width: 76,
                child: Column(
                  children: [
                    StudioAvatar(url: artists[i].avatarUrl, size: 68, semanticLabel: artists[i].displayName),
                    const SizedBox(height: 6),
                    Text(
                      artists[i].displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: StudioType.caption12(color: c.textPrimary),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Pieces at this event (`EvDetail`): 150 × 200 images at radius 10, 12 apart, running to the
/// screen edge; title 14/500 8 below, then the price line 13 ([eventPiecePriceLine]).
class EventPiecesRow extends StatelessWidget {
  const EventPiecesRow({super.key, required this.items, required this.onPiece});

  final List<EventLineupItem> items;
  final void Function(EventLineupItem item) onPiece;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Semantics(
              button: true,
              child: GestureDetector(
                onTap: () => onPiece(items[i]),
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: 150,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(StudioRadius.card),
                        child: SizedBox(
                          width: 150,
                          height: 200,
                          child: EventCover(url: items[i].mediaUrl ?? ''),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        items[i].title?.isNotEmpty == true ? items[i].title! : 'Untitled',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: StudioType.body14(weight: StudioType.medium, color: c.textPrimary),
                      ),
                      if (eventPiecePriceLine(items[i]) case final line?) ...[
                        const SizedBox(height: 4),
                        Text(line, style: StudioType.label13(color: c.textPrimary)),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The map under the address (`EvDetail`): 180 tall, radius 14, a drawn street plan with a
/// pin, not map tiles (no map provider yet; plan section 0.3). Tapping opens directions.
class EventMapCard extends StatelessWidget {
  const EventMapCard({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ground = dark ? const Color(0xFF242422) : const Color(0xFFEDEBE6);
    final road = dark ? const Color(0xFF34342F) : Colors.white;
    final park = dark ? const Color(0xFF26302A) : const Color(0xFFD7E3DA);
    Widget street({required double top, required double height, required double degrees}) => Positioned(
      left: -20,
      right: -20,
      top: top,
      height: height,
      child: Transform.rotate(
        angle: degrees * 3.1415926535 / 180,
        child: ColoredBox(color: road),
      ),
    );
    return Semantics(
      button: true,
      label: 'Open directions',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(StudioRadius.panel),
          child: SizedBox(
            height: 180,
            child: ColoredBox(
              color: ground,
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  street(top: 70, height: 10, degrees: -8),
                  Positioned(
                    top: -20,
                    bottom: -20,
                    left: 150,
                    width: 10,
                    child: Transform.rotate(
                      angle: 12 * 3.1415926535 / 180,
                      child: ColoredBox(color: road),
                    ),
                  ),
                  street(top: 130, height: 6, degrees: 4),
                  Positioned(
                    left: 0,
                    bottom: 0,
                    width: 140,
                    height: 50,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: park,
                        borderRadius: const BorderRadius.only(topRight: Radius.circular(40)),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 172,
                    top: 72,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: c.textPrimary,
                        shape: BoxShape.circle,
                        border: Border.all(color: c.background, width: 3),
                        boxShadow: const [
                          BoxShadow(color: Color(0x40000000), blurRadius: 6, offset: Offset(0, 2)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One host FAQ (`EvDetail`): question 15 with a chevron that turns, 14 above and below;
/// the answer 14 at 1.5 in Body under it when open; a Line under each.
class EventFaqRow extends StatefulWidget {
  const EventFaqRow({super.key, required this.question, required this.answer});

  final String question;
  final String answer;

  @override
  State<EventFaqRow> createState() => _EventFaqRowState();
}

class _EventFaqRowState extends State<EventFaqRow> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            button: true,
            expanded: _open,
            child: GestureDetector(
              onTap: () => setState(() => _open = !_open),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(widget.question, style: StudioType.body15(color: c.textPrimary)),
                    ),
                    AnimatedRotation(
                      turns: _open ? 0.5 : 0,
                      duration: StudioMotion.quick,
                      child: StudioIcon(StudioIcons.chevronDown, size: 18, color: c.textTertiary),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_open)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(widget.answer, style: StudioType.sans(14, height: 1.5, color: c.textBody)),
            ),
        ],
      ),
    );
  }
}
