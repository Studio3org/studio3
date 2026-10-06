import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/feed_preview_item.dart';
import '../../theme/home_feed_tokens.dart';
import 'detail_share.dart';

/// Instagram-style share menu: WhatsApp / SMS / native "more" share /
/// copy link. No in-app "share to a user" — no generic DM system exists.
class PieceShareSheet extends StatelessWidget {
  const PieceShareSheet({super.key, required this.item, this.imageIndex = 0});

  final FeedPreviewItem item;
  final int imageIndex;

  static Future<void> show(
    BuildContext context,
    FeedPreviewItem item, {
    int imageIndex = 0,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: HomeFeedTokens.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        top: false,
        child: PieceShareSheet(item: item, imageIndex: imageIndex),
      ),
    );
  }

  Future<void> _shareViaWhatsApp(BuildContext context) async {
    final text = buildPieceShareText(item, imageIndex: imageIndex);
    final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');
    final launched =
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('WhatsApp is not installed')),
      );
    }
  }

  Future<void> _shareViaSms(BuildContext context) async {
    final text = buildPieceShareText(item, imageIndex: imageIndex);
    final encoded = Uri.encodeComponent(text);
    final uri = Uri.parse(
      Platform.isIOS ? 'sms:&body=$encoded' : 'sms:?body=$encoded',
    );
    final launched =
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Messages')),
      );
    }
  }

  Future<void> _shareViaMore(BuildContext context) async {
    final text = buildPieceShareText(item, imageIndex: imageIndex);
    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null
        ? box.localToGlobal(Offset.zero) & box.size
        : const Rect.fromLTWH(0, 0, 0, 0);
    await SharePlus.instance.share(
      ShareParams(text: text, sharePositionOrigin: origin),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: HomeFeedTokens.textSecondary.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(100),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Share',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: HomeFeedTokens.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ShareOption(
                icon: Icons.chat_rounded,
                iconColor: const Color(0xFF25D366),
                label: 'WhatsApp',
                onTap: () {
                  Navigator.pop(context);
                  _shareViaWhatsApp(context);
                },
              ),
              _ShareOption(
                icon: Icons.sms_rounded,
                iconColor: const Color(0xFF34C759),
                label: 'Messages',
                onTap: () {
                  Navigator.pop(context);
                  _shareViaSms(context);
                },
              ),
              Builder(
                builder: (innerContext) => _ShareOption(
                  icon: Icons.more_horiz_rounded,
                  iconColor: HomeFeedTokens.textPrimary,
                  label: 'More',
                  onTap: () {
                    Navigator.pop(context);
                    _shareViaMore(innerContext);
                  },
                ),
              ),
              _ShareOption(
                icon: Icons.link_rounded,
                iconColor: HomeFeedTokens.textPrimary,
                label: 'Copy Link',
                onTap: () {
                  Navigator.pop(context);
                  shareFeedPreviewItem(context, item, imageIndex: imageIndex);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShareOption extends StatelessWidget {
  const _ShareOption({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: HomeFeedTokens.textPrimary.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 26),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: HomeFeedTokens.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
