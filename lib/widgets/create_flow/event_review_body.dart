import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../data/post_location_options.dart';
import '../../data/post_picker_options.dart';
import '../../theme/home_feed_tokens.dart';
import '../profile_avatar.dart';
import 'event_date_sheet.dart';
import 'event_lineup_models.dart';
import 'event_ticket_edit_page.dart';
import '../../theme/app_fonts.dart';

const _editColor = Color(0xFFC4541E);
const _cardBorder = Color(0xFFC4C4C4);
const _hairline = Color(0xFFC8C5BC);

class EventReviewBody extends StatelessWidget {
  const EventReviewBody({
    super.key,
    required this.title,
    required this.isPublic,
    required this.paid,
    required this.tickets,
    required this.cohosts,
    required this.artists,
    required this.pieces,
    required this.onEditStep,
    this.location,
    this.eventDate,
    this.categoryId,
  });

  final String title;
  final bool isPublic;
  final bool? paid;
  final List<EventTicketTier> tickets;
  final List<EventLineupPerson> cohosts;
  final List<EventLineupPerson> artists;
  final List<EventTaggedPiece> pieces;
  final ValueChanged<int> onEditStep;
  final PostLocationOption? location;
  final EventDateSelection? eventDate;
  final String? categoryId;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Column(
        children: [
          _ReviewCard(
            label: 'Details',
            onEdit: () => onEditStep(0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.trim().isEmpty ? 'Untitled event' : title.trim(),
                  style: AppFonts.geist(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: HomeFeedTokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _categoryPublicLine,
                  style: AppFonts.geist(
                    fontSize: 12,
                    color: HomeFeedTokens.textSecondary,
                  ),
                ),
                if (_locationLine != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _locationLine!,
                    style: AppFonts.geist(
                      fontSize: 11,
                      color: HomeFeedTokens.textSecondary,
                    ),
                  ),
                ],
                if (eventDate != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    eventDate!.reviewLine,
                    style: AppFonts.geist(
                      fontSize: 11,
                      color: HomeFeedTokens.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          _ReviewCard(
            label: 'Tickets',
            onEdit: () => onEditStep(1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (paid == false)
                  Text(
                    'Free / RSVP',
                    style: AppFonts.geist(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: HomeFeedTokens.textPrimary,
                    ),
                  )
                else ...[
                  for (final ticket in tickets.where((t) => t.isComplete)) ...[
                    _TicketLine(ticket: ticket),
                    const SizedBox(height: 4),
                  ],
                  if (tickets.any((t) => t.isComplete))
                    Text(
                      'Flexible refund policy',
                      style: AppFonts.geist(
                        fontSize: 10,
                        color: HomeFeedTokens.textSecondary,
                      ),
                    )
                  else
                    Text(
                      'No tickets added',
                      style: AppFonts.geist(
                        fontSize: 13,
                        color: HomeFeedTokens.textSecondary,
                      ),
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          _ReviewCard(
            label: 'Lineup',
            onEdit: () => onEditStep(2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (cohosts.isNotEmpty) ...[
                  Text(
                    'Co-hosts · ${cohosts.length} of ${cohosts.length}',
                    style: AppFonts.geist(
                      fontSize: 12,
                      color: HomeFeedTokens.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      for (final person in cohosts) _NamedAvatar(person: person),
                    ],
                  ),
                ],
                if (artists.isNotEmpty) ...[
                  if (cohosts.isNotEmpty) const SizedBox(height: 16),
                  Text(
                    'Featured artists · ${artists.length}',
                    style: AppFonts.geist(
                      fontSize: 12,
                      color: HomeFeedTokens.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _StackedArtists(people: artists),
                ],
                if (pieces.isNotEmpty) ...[
                  if (cohosts.isNotEmpty || artists.isNotEmpty)
                    const SizedBox(height: 16),
                  Text(
                    'Pieces',
                    style: AppFonts.geist(
                      fontSize: 12,
                      color: HomeFeedTokens.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (var i = 0; i < pieces.length; i++) ...[
                    _ReviewPieceRow(tagged: pieces[i]),
                    if (i != pieces.length - 1)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Divider(
                          height: 0.5,
                          thickness: 0.5,
                          color: _hairline,
                        ),
                      ),
                  ],
                ],
                if (cohosts.isEmpty && artists.isEmpty && pieces.isEmpty)
                  Text(
                    'No lineup added',
                    style: AppFonts.geist(
                      fontSize: 13,
                      color: HomeFeedTokens.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String get _categoryPublicLine {
    final category = categoryId == null
        ? null
        : EventCategoryOptions.byId(categoryId!)?.name;
    final visibility = isPublic ? 'Public' : 'Private';
    if (category == null || category.isEmpty) return visibility;
    return '$category · $visibility';
  }

  String? get _locationLine {
    final loc = location;
    if (loc == null) return null;
    if (loc.subtitle.isNotEmpty && loc.subtitle != loc.name) {
      return '${loc.name} · ${loc.subtitle}';
    }
    return loc.displayName;
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.label,
    required this.onEdit,
    required this.child,
  });

  final String label;
  final VoidCallback onEdit;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: AppFonts.geist(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: HomeFeedTokens.textSecondary,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: onEdit,
                  behavior: HitTestBehavior.opaque,
                  child: Text(
                    'Edit',
                    style: AppFonts.geist(
                      fontSize: 12,
                      color: _editColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _TicketLine extends StatelessWidget {
  const _TicketLine({required this.ticket});

  final EventTicketTier ticket;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '${ticket.name}: ',
            style: AppFonts.geist(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: HomeFeedTokens.textPrimary,
            ),
          ),
          TextSpan(
            text: ticket.reviewDetailLine,
            style: AppFonts.geist(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: HomeFeedTokens.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _NamedAvatar extends StatelessWidget {
  const _NamedAvatar({required this.person});

  final EventLineupPerson person;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ProfileAvatar(url: person.avatarUrl, size: 40),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              person.displayName,
              style: AppFonts.geist(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: HomeFeedTokens.textPrimary,
              ),
            ),
            Text(
              person.handle,
              style: AppFonts.geist(
                fontSize: 10,
                color: HomeFeedTokens.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StackedArtists extends StatelessWidget {
  const _StackedArtists({required this.people});

  final List<EventLineupPerson> people;

  @override
  Widget build(BuildContext context) {
    final shown = people.take(4).toList();
    final names = people.take(3).map((p) {
      final parts = p.displayName.split(RegExp(r'\s+'));
      return parts.isNotEmpty ? parts.first : p.displayName;
    }).join(', ');
    final extra = people.length > 3 ? ' +${people.length - 3} more' : '';

    return Row(
      children: [
        SizedBox(
          width: 40 + (shown.length - 1) * 32,
          height: 40,
          child: Stack(
            children: [
              for (var i = 0; i < shown.length; i++)
                Positioned(
                  left: i * 32.0,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: HomeFeedTokens.background,
                        width: 1,
                      ),
                    ),
                    child: ProfileAvatar(url: shown[i].avatarUrl, size: 40),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '$names$extra',
            style: AppFonts.geist(
              fontSize: 11,
              color: HomeFeedTokens.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _ReviewPieceRow extends StatelessWidget {
  const _ReviewPieceRow({required this.tagged});

  final EventTaggedPiece tagged;

  @override
  Widget build(BuildContext context) {
    final cover = eventPieceCoverUrl(tagged.piece);
    final modeLabel = switch (tagged.mode) {
      EventPieceMode.featured => 'Featured',
      EventPieceMode.sale => 'For sale',
      EventPieceMode.bid => 'For bid',
    };
    final price = _prettyPrice(tagged.price);
    final priceLabel = switch (tagged.mode) {
      EventPieceMode.featured => null,
      EventPieceMode.sale => price,
      EventPieceMode.bid => 'From $price',
    };

    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            width: 52,
            height: 66,
            child: cover.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: cover,
                    fit: BoxFit.cover,
                    errorWidget: (context, url, error) => const ColoredBox(
                      color: HomeFeedTokens.skeletonBase,
                    ),
                  )
                : const ColoredBox(color: HomeFeedTokens.skeletonBase),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            tagged.piece.title.isEmpty ? 'Untitled' : tagged.piece.title,
            style: AppFonts.geist(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: HomeFeedTokens.textPrimary,
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              modeLabel,
              style: AppFonts.geist(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: HomeFeedTokens.textPrimary,
              ),
            ),
            if (priceLabel != null) ...[
              const SizedBox(height: 4),
              Text(
                priceLabel,
                style: AppFonts.geist(
                  fontSize: 11,
                  color: HomeFeedTokens.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

String _prettyPrice(String raw) {
  final value = double.tryParse(raw.trim());
  if (value == null) return raw.startsWith('\$') ? raw : '\$$raw';
  if (value == value.roundToDouble()) return '\$${value.round()}';
  return '\$${value.toStringAsFixed(2)}';
}
