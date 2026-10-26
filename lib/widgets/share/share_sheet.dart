import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../studio/studio.dart';

/// Share menu for any text (a series, an event): WhatsApp / Messages / the system share sheet
/// / copy. Generic over the text being shared — content with a real link should already carry
/// it in [shareText] so every channel, the OS sheet included, has it.
///
/// No board: the same sheet as sharing a piece (`PieceShareSheet`): "Share" 22, then
/// `ConvMenu`-style action rows with Ink outline icons. No brand colours (`HandoffRules`).
class ShareSheet extends StatelessWidget {
  const ShareSheet({
    super.key,
    required this.shareText,
    this.copyLabel = 'Copy link',
    this.copiedMessage = 'Link copied',
  });

  final String shareText;
  final String copyLabel;
  final String copiedMessage;

  static Future<void> show(
    BuildContext context, {
    required String shareText,
    String copyLabel = 'Copy link',
    String copiedMessage = 'Link copied',
  }) {
    return showStudioSheet<void>(
      context: context,
      builder: (context) => ShareSheet(shareText: shareText, copyLabel: copyLabel, copiedMessage: copiedMessage),
    );
  }

  Future<void> _shareViaWhatsApp(BuildContext context) async {
    final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(shareText)}');
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) showStudioToast(context, 'WhatsApp is not installed', icon: null);
  }

  Future<void> _shareViaSms(BuildContext context) async {
    final encoded = Uri.encodeComponent(shareText);
    final uri = Uri.parse(Platform.isIOS ? 'sms:&body=$encoded' : 'sms:?body=$encoded');
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) showStudioToast(context, 'Could not open Messages', icon: null);
  }

  Future<void> _shareViaMore(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null ? box.localToGlobal(Offset.zero) & box.size : const Rect.fromLTWH(0, 0, 0, 0);
    await SharePlus.instance.share(ShareParams(text: shareText, sharePositionOrigin: origin));
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: shareText));
    if (context.mounted) showStudioToast(context, copiedMessage);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    // The menu closes first, so messages show on the page underneath.
    final page = Navigator.of(context).context;
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
            _shareViaWhatsApp(page);
          },
        ),
        StudioActionRow(
          icon: StudioIcons.send,
          title: 'Messages',
          onTap: () {
            Navigator.pop(context);
            _shareViaSms(page);
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
          title: copyLabel,
          onTap: () {
            Navigator.pop(context);
            _copy(page);
          },
        ),
      ],
    );
  }
}
