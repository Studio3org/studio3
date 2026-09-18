import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/post_media_assets.dart';
import '../../theme/home_feed_tokens.dart';
import '../profile_avatar.dart';
import 'event_lineup_models.dart';
import 'event_relist_dialog.dart';

const _hairline = Color(0xFFC8C5BC);
const _cardBorder = Color(0xFFC4C4C4);

class EventLineupBody extends StatelessWidget {
  const EventLineupBody({
    super.key,
    required this.cohosts,
    required this.artists,
    required this.pieces,
    required this.onAddCohost,
    required this.onRemoveCohost,
    required this.onAddArtist,
    required this.onRemoveArtist,
    required this.onPieceChanged,
    required this.onTagPiece,
  });

  final List<EventLineupPerson> cohosts;
  final List<EventLineupPerson> artists;
  final List<EventTaggedPiece> pieces;
  final VoidCallback onAddCohost;
  final ValueChanged<EventLineupPerson> onRemoveCohost;
  final VoidCallback onAddArtist;
  final ValueChanged<EventLineupPerson> onRemoveArtist;
  final ValueChanged<EventTaggedPiece> onPieceChanged;
  final VoidCallback onTagPiece;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PeopleSection(
          label: 'Co-hosts',
          people: cohosts,
          onAdd: onAddCohost,
          onRemove: onRemoveCohost,
        ),
        _PeopleSection(
          label: 'Featured Artist',
          people: artists,
          onAdd: onAddArtist,
          onRemove: onRemoveArtist,
          extraTop: 7,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pieces',
                style: GoogleFonts.geist(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: HomeFeedTokens.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                pieces.isEmpty
                    ? 'Tag pieces being shown, sold, or auctioned at this event'
                    : 'Off shows this only to people you share it with',
                style: GoogleFonts.geist(
                  fontSize: 11,
                  color: HomeFeedTokens.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < pieces.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                EventTaggedPieceCard(
                  tagged: pieces[i],
                  onChanged: onPieceChanged,
                ),
              ],
              const SizedBox(height: 12),
              GestureDetector(
                onTap: onTagPiece,
                behavior: HitTestBehavior.opaque,
                child: Text(
                  '+ Tag a piece',
                  style: GoogleFonts.geist(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: HomeFeedTokens.textPrimary,
                    decoration: TextDecoration.underline,
                    decorationColor: HomeFeedTokens.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PeopleSection extends StatelessWidget {
  const _PeopleSection({
    required this.label,
    required this.people,
    required this.onAdd,
    required this.onRemove,
    this.extraTop = 0,
  });

  final String label;
  final List<EventLineupPerson> people;
  final VoidCallback onAdd;
  final ValueChanged<EventLineupPerson> onRemove;
  final double extraTop;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: _hairline)),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 16 + extraTop, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.geist(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: HomeFeedTokens.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final person in people) ...[
                      _PersonChip(
                        person: person,
                        onTap: () => onRemove(person),
                      ),
                      const SizedBox(width: 10),
                    ],
                    EventAddPersonButton(onTap: onAdd),
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

class _PersonChip extends StatelessWidget {
  const _PersonChip({required this.person, required this.onTap});

  final EventLineupPerson person;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 82,
        child: Column(
          children: [
            ProfileAvatar(url: person.avatarUrl, size: 58),
            const SizedBox(height: 2),
            Text(
              person.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.geist(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: HomeFeedTokens.textPrimary,
              ),
            ),
            Text(
              person.handle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.geist(
                fontSize: 11,
                color: HomeFeedTokens.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EventAddPersonButton extends StatelessWidget {
  const EventAddPersonButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: const _DashedCirclePainter(color: _hairline),
        child: SizedBox(
          width: 58,
          height: 58,
          child: Center(
            child: SvgPicture.asset(
              PostMediaAssets.addPlusIcon,
              width: 14,
              height: 14,
              colorFilter: const ColorFilter.mode(
                HomeFeedTokens.textPrimary,
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  const _DashedCirclePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final rect = Rect.fromLTWH(0.5, 0.5, size.width - 1, size.height - 1);
    const dash = 4.0;
    const gap = 3.0;
    final path = Path()..addOval(rect);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = (distance + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter oldDelegate) =>
      oldDelegate.color != color;
}

class EventTaggedPieceCard extends StatefulWidget {
  const EventTaggedPieceCard({
    super.key,
    required this.tagged,
    required this.onChanged,
  });

  final EventTaggedPiece tagged;
  final ValueChanged<EventTaggedPiece> onChanged;

  @override
  State<EventTaggedPieceCard> createState() => _EventTaggedPieceCardState();
}

class _EventTaggedPieceCardState extends State<EventTaggedPieceCard> {
  late final TextEditingController _price;

  @override
  void initState() {
    super.initState();
    _price = TextEditingController(text: widget.tagged.price);
  }

  @override
  void didUpdateWidget(covariant EventTaggedPieceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tagged.piece.id != widget.tagged.piece.id) {
      _price.text = widget.tagged.price;
    } else if (_price.text != widget.tagged.price) {
      _price.text = widget.tagged.price;
    }
  }

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  Future<void> _selectMode(EventPieceMode mode) async {
    if (mode == widget.tagged.mode) return;
    if (mode == EventPieceMode.sale && widget.tagged.needsRelistForSale) {
      final ok = await showEventRelistDialog(
        context,
        title: 'This will end its current listing',
        body:
            '${widget.tagged.piece.title} is already listed for sale outside this event. Confirming will close that out and create a new listing just for this event\'s roster.',
      );
      if (!ok || !mounted) return;
    }
    if (mode == EventPieceMode.bid && widget.tagged.needsRelistForBid) {
      final ok = await showEventRelistDialog(
        context,
        title: 'This will end its current auction',
        body:
            '${widget.tagged.piece.title} is currently up for auction outside this event. Confirming will close that out and start a new one tied to this event.',
      );
      if (!ok || !mounted) return;
    }
    if (mode == EventPieceMode.sale && widget.tagged.needsRelistForBid) {
      final ok = await showEventRelistDialog(
        context,
        title: 'This will end its current auction',
        body:
            '${widget.tagged.piece.title} is currently up for auction outside this event. Confirming will close that out and start a new one tied to this event.',
      );
      if (!ok || !mounted) return;
    }
    if (mode == EventPieceMode.bid && widget.tagged.needsRelistForSale) {
      final ok = await showEventRelistDialog(
        context,
        title: 'This will end its current listing',
        body:
            '${widget.tagged.piece.title} is already listed for sale outside this event. Confirming will close that out and create a new listing just for this event\'s roster.',
      );
      if (!ok || !mounted) return;
    }
    if (!mounted) return;
    widget.onChanged(widget.tagged.copyWith(mode: mode));
  }

  @override
  Widget build(BuildContext context) {
    final tagged = widget.tagged;
    final cover = eventPieceCoverUrl(tagged.piece);
    final artist = tagged.piece.authorName?.trim().isNotEmpty == true
        ? tagged.piece.authorName!
        : (tagged.piece.authorUsername ?? '');
    final showOffer = tagged.mode != EventPieceMode.featured;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 74,
                  height: 94,
                  child: cover.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: cover,
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) =>
                              const ColoredBox(
                            color: HomeFeedTokens.skeletonBase,
                          ),
                        )
                      : const ColoredBox(color: HomeFeedTokens.skeletonBase),
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tagged.piece.title.isEmpty
                            ? 'Untitled'
                            : tagged.piece.title,
                        style: GoogleFonts.geist(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: HomeFeedTokens.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        artist,
                        style: GoogleFonts.geist(
                          fontSize: 10,
                          color: HomeFeedTokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _ModeChip(
                label: 'Featured',
                selected: tagged.mode == EventPieceMode.featured,
                onTap: () => _selectMode(EventPieceMode.featured),
              ),
              const SizedBox(width: 5),
              _ModeChip(
                label: 'For sale',
                selected: tagged.mode == EventPieceMode.sale,
                onTap: () => _selectMode(EventPieceMode.sale),
              ),
              const SizedBox(width: 5),
              _ModeChip(
                label: 'For bid',
                selected: tagged.mode == EventPieceMode.bid,
                onTap: () => _selectMode(EventPieceMode.bid),
              ),
            ],
          ),
          if (showOffer) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _LabeledBlock(
                    label: tagged.mode == EventPieceMode.bid
                        ? 'Starting bid'
                        : 'Price',
                    child: _PriceField(
                      controller: _price,
                      onChanged: (value) =>
                          widget.onChanged(tagged.copyWith(price: value)),
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: _LabeledBlock(
                    label: tagged.mode == EventPieceMode.bid
                        ? 'If won'
                        : 'If sold',
                    child: Row(
                      children: [
                        _FulfillChip(
                          label: 'Ship',
                          selected:
                              tagged.fulfillment == EventFulfillment.ship,
                          onTap: () => widget.onChanged(
                            tagged.copyWith(
                              fulfillment: EventFulfillment.ship,
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        _FulfillChip(
                          label: 'Pickup',
                          selected:
                              tagged.fulfillment == EventFulfillment.pickup,
                          onTap: () => widget.onChanged(
                            tagged.copyWith(
                              fulfillment: EventFulfillment.pickup,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _LabeledBlock extends StatelessWidget {
  const _LabeledBlock({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.geist(
            fontSize: 11,
            color: HomeFeedTokens.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        child,
      ],
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 31,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? HomeFeedTokens.neutral800 : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? HomeFeedTokens.textPrimary : _hairline,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.geist(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
              color: selected
                  ? HomeFeedTokens.textInverse
                  : HomeFeedTokens.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _FulfillChip extends StatelessWidget {
  const _FulfillChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 31,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? HomeFeedTokens.textPrimary : _hairline,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.geist(
              fontSize: 13,
              color: selected
                  ? HomeFeedTokens.textPrimary
                  : HomeFeedTokens.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _PriceField extends StatelessWidget {
  const _PriceField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 31,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _hairline),
      ),
      child: Row(
        children: [
          Text(
            '\$',
            style: GoogleFonts.geist(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: HomeFeedTokens.textSecondary,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              onChanged: onChanged,
              cursorColor: HomeFeedTokens.textPrimary,
              style: GoogleFonts.geist(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: HomeFeedTokens.textPrimary,
              ),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.only(bottom: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
