import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../theme/collect_detail_tokens.dart';
import '../../theme/piece_detail_type.dart';

class AvailableCollectBar extends StatelessWidget {
  const AvailableCollectBar({
    super.key,
    required this.priceDisplay,
    this.onCollect,
    this.statusLabel,
    this.onMessage,
  });

  final String priceDisplay;
  final VoidCallback? onCollect;
  final String? statusLabel;
  final VoidCallback? onMessage;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 24, 10, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 24,
            child: Text(
              priceDisplay,
              style: PieceDetailType.price,
              strutStyle: PieceDetailType.priceStrut,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: Material(
                    color: onCollect == null
                        ? CollectDetailTokens.ctaFill.withValues(alpha: 0.5)
                        : CollectDetailTokens.ctaFill,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: onCollect,
                      borderRadius: BorderRadius.circular(8),
                      child: Center(
                        child: Text(
                          statusLabel ?? 'Collect',
                          style: PieceDetailType.collect,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: onMessage,
                child: SvgPicture.asset(
                  'assets/piece/message_btn.svg',
                  width: 40,
                  height: 40,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
