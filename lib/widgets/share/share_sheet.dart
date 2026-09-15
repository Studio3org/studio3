import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/home_feed_tokens.dart';

/// Instagram-style share menu: WhatsApp / SMS / native "more" share / copy.
/// Generic over the text being shared, so the same sheet works for a piece,
/// a series, or an event — just pass the text block to share (and, for
/// content with a real link, that link should already be part of [shareText]
/// so every channel — including the native OS share sheet — carries it).
class ShareSheet extends StatelessWidget {
  const ShareSheet({
    super.key,
    required this.shareText,
    this.copyLabel = 'Copy Link',
    this.copiedMessage = 'Link copied',
  });

  final String shareText;
  final String copyLabel;
  final String copiedMessage;

  static Future<void> show(
    BuildContext context, {
    required String shareText,
    String copyLabel = 'Copy Link',
    String copiedMessage = 'Link copied',
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
        child: ShareSheet(
          shareText: shareText,
          copyLabel: copyLabel,
          copiedMessage: copiedMessage,
        ),
      ),
    );
  }

  Future<void> _shareViaWhatsApp(BuildContext context) async {
    final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(shareText)}');
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('WhatsApp is not installed')),
      );
    }
  }

  Future<void> _shareViaSms(BuildContext context) async {
    final encoded = Uri.encodeComponent(shareText);
    final uri = Uri.parse(
      Platform.isIOS ? 'sms:&body=$encoded' : 'sms:?body=$encoded',
    );
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Messages')),
      );
    }
  }

  Future<void> _shareViaMore(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null
        ? box.localToGlobal(Offset.zero) & box.size
        : const Rect.fromLTWH(0, 0, 0, 0);
    await SharePlus.instance.share(
      ShareParams(text: shareText, sharePositionOrigin: origin),
    );
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: shareText));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(copiedMessage)),
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
                label: copyLabel,
                onTap: () {
                  Navigator.pop(context);
                  _copy(context);
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
