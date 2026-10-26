import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../config/app_link_config.dart';
import '../../utils/qr_image_share.dart';
import '../studio/studio.dart';

/// Piece link and QR code (`HostPieceQR`): a sheet with the piece (42 × 56, title 16/500,
/// "artist · price" 13), the code on a white card (radius 16, a Line, 16 padding), the link
/// in Mono 13 with Copy link, what scanning does, Download QR code (a print-size image) and, once
/// the event exists, "Download all N QR codes".
Future<void> showHostPieceQrSheet(
  BuildContext context, {
  required String pieceId,
  required String title,
  String? artistName,
  String? priceLabel,
  String? imageUrl,
  int? allCount,
  VoidCallback? onDownloadAll,
}) {
  final url = AppLinkConfig.pieceUrl(pieceId);
  return showStudioSheet<void>(
    context: context,
    builder: (sheetContext) {
      final c = sheetContext.studio;
      final line = [?artistName, ?priceLabel].where((p) => p.isNotEmpty).join(' · ');
      return StudioSheet(
        horizontalPadding: StudioSpace.marginForm,
        gap: 10,
        scrollable: true,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 42,
                  height: 56,
                  child: imageUrl == null || imageUrl.isEmpty
                      ? ColoredBox(color: c.surface)
                      : CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => ColoredBox(color: c.surface),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: StudioType.sans(16, weight: StudioType.medium, color: c.textPrimary)),
                    if (line.isNotEmpty) Text(line, style: StudioType.label13(color: c.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: c.line),
              ),
              child: Semantics(
                label: 'QR code for $title',
                image: true,
                child: QrImageView(
                  data: url,
                  size: 180,
                  padding: EdgeInsets.zero,
                  backgroundColor: Colors.white,
                  errorCorrectionLevel: QrErrorCorrectLevel.M,
                  eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: StudioColors.ink),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: StudioColors.ink,
                  ),
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    url.replaceFirst(RegExp(r'^https?://'), ''),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: StudioType.mono(13, color: c.textPrimary),
                  ),
                ),
                const SizedBox(width: 12),
                Semantics(
                  button: true,
                  child: GestureDetector(
                    onTap: () async {
                      await Clipboard.setData(ClipboardData(text: url));
                      if (sheetContext.mounted) showStudioToast(sheetContext, 'Link copied');
                    },
                    behavior: HitTestBehavior.opaque,
                    child: SizedBox(
                      height: 32,
                      child: Center(
                        widthFactor: 1,
                        child: Text(
                          'Copy link',
                          style: StudioType.body14(weight: StudioType.medium, color: c.textPrimary),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Text(
            "Scanning it opens the piece in the app (or the website if they don't have it), where guests can "
            'collect it.',
            style: StudioType.caption12(height: 1.5, color: c.textSecondary),
          ),
          StudioButton(
            label: 'Download QR code',
            onPressed: () async {
              try {
                // iPad anchors the share sheet to the sheet it came from.
                final box = sheetContext.findRenderObject() as RenderBox?;
                await QrImageShare.share(
                  title: title,
                  url: url,
                  origin: box == null || !box.hasSize ? null : box.localToGlobal(Offset.zero) & box.size,
                );
              } catch (_) {
                if (sheetContext.mounted) showStudioToast(sheetContext, 'Could not save that code.', icon: null);
              }
            },
          ),
          if (onDownloadAll != null && (allCount ?? 0) > 1)
            StudioButton(
              label: 'Download all $allCount QR codes',
              variant: StudioButtonVariant.text,
              height: 40,
              onPressed: () {
                Navigator.pop(sheetContext);
                onDownloadAll();
              },
            ),
        ],
      );
    },
  );
}
