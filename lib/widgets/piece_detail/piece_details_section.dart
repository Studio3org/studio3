import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../theme/collect_detail_tokens.dart';
import '../../theme/piece_detail_type.dart';

class PieceDetailsSection extends StatefulWidget {
  const PieceDetailsSection({
    super.key,
    required this.year,
    this.location,
    this.framingNote,
    this.shippingRegion,
    this.handlingNotes,
  });

  final int year;
  final String? location;
  final String? framingNote;
  final String? shippingRegion;
  final String? handlingNotes;

  @override
  State<PieceDetailsSection> createState() => _PieceDetailsSectionState();
}

class _PieceDetailsSectionState extends State<PieceDetailsSection> {
  bool _expanded = true;

  String _orDash(String? value) {
    final text = value?.trim() ?? '';
    return text.isEmpty ? '—' : text;
  }

  String get _shippingValue {
    final location = widget.location?.trim() ?? '';
    if (location.isNotEmpty) return 'Ships from $location';
    return _orDash(widget.shippingRegion);
  }

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      ('Location', _orDash(widget.location)),
      ('Year created', '${widget.year}'),
      ('Framing/mounting', _orDash(widget.framingNote)),
      ('Shipping', _shippingValue),
      ('Handling', _orDash(widget.handlingNotes)),
    ];

    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: CollectDetailTokens.hairline, width: 1),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 16, 10, 16),
        child: Column(
          children: [
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                height: 28,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Details',
                        style: PieceDetailType.detailsHeader,
                        strutStyle: PieceDetailType.detailsHeaderStrut,
                      ),
                    ),
                    Transform.rotate(
                      angle: _expanded ? 3.1415926535 : 0,
                      child: SvgPicture.asset(
                        'assets/piece/details_chevron.svg',
                        width: 8,
                        height: 4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_expanded)
              for (final row in rows) ...[
                const SizedBox(height: 8),
                _DetailRow(label: row.$1, value: row.$2),
              ],
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: Row(
        children: [
          Text(
            label,
            style: PieceDetailType.detailsLabel,
            strutStyle: PieceDetailType.detailsRowStrut,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: PieceDetailType.detailsValue,
              strutStyle: PieceDetailType.detailsRowStrut,
            ),
          ),
        ],
      ),
    );
  }
}
