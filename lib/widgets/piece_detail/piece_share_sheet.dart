import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/feed_preview_item.dart';
import '../../theme/studio_colors.dart';
import '../../theme/studio_type.dart';
import '../studio/studio_action_row.dart';
import '../studio/studio_icon.dart';
import '../studio/studio_sheet.dart';
import '../studio/studio_toast.dart';
import 'detail_share.dart';

/// Share menu: WhatsApp / Messages / the system share sheet / copy link. No in-app "share
/// to a user" — no generic DM system exists.
///
/// No board: a board sheet with the `ConvMenu` row pattern (22 px Ink outline icons, 16
/// labels, rules). No brand colors: color is only for status (`HandoffRules`).
class PieceShareSheet extends StatelessWidget {
  const PieceShareSheet({super.key, required this.item, this.imageIndex = 0});

  final FeedPreviewItem item;
  final int imageIndex;

  static Future<void> show(BuildContext context, FeedPreviewItem item, {int imageIndex = 0}) {
    return showStudioSheet<void>(
      context: context,
      builder: (context) => PieceShareSheet(item: item, imageIndex: imageIndex),
    );
  }

  Future<void> _shareViaWhatsApp(BuildContext context) async {
    final text = buildPieceShareText(item, imageIndex: imageIndex);
    final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      showStudioToast(context, 'WhatsApp is not installed', icon: null);
    }
  }

  Future<void> _shareViaSms(BuildContext context) async {
    final text = buildPieceShareText(item, imageIndex: imageIndex);
    final encoded = Uri.encodeComponent(text);
    final uri = Uri.parse(Platform.isIOS ? 'sms:&body=$encoded' : 'sms:?body=$encoded');
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      showStudioToast(context, 'Could not open Messages', icon: null);
    }
  }

  Future<void> _shareViaMore(BuildContext context) async {
    final text = buildPieceShareText(item, imageIndex: imageIndex);
    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null
        ? box.localToGlobal(Offset.zero) & box.size
        : const Rect.fromLTWH(0, 0, 0, 0);
    await SharePlus.instance.share(ShareParams(text: text, sharePositionOrigin: origin));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return StudioSheet(
      horizontalPadding: 24,
      gap: 6,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: Text('Share', style: StudioType.title22(color: c.textPrimary)),
        ),
        StudioActionRow(
          icon: StudioIcons.chat,
          title: 'WhatsApp',
          onTap: () {
            Navigator.pop(context);
            _shareViaWhatsApp(context);
          },
        ),
        StudioActionRow(
          icon: StudioIcons.send,
          title: 'Messages',
          onTap: () {
            Navigator.pop(context);
            _shareViaSms(context);
          },
        ),
        Builder(
          builder: (innerContext) => StudioActionRow(
            icon: StudioIcons.share,
            title: 'More',
            onTap: () {
              Navigator.pop(context);
              _shareViaMore(innerContext);
            },
          ),
        ),
        StudioActionRow(
          icon: StudioIcons.link,
          title: 'Copy link',
          onTap: () {
            Navigator.pop(context);
            shareFeedPreviewItem(context, item, imageIndex: imageIndex);
          },
        ),
      ],
    );
  }
}
