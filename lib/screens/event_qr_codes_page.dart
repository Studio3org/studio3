import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/event_qr_code.dart';
import '../services/api_exception.dart';
import '../services/event_service.dart';
import '../utils/event_qr_pdf.dart';
import '../utils/qr_image_share.dart';
import '../widgets/loading/app_skeletons.dart';
import '../widgets/share/share_sheet.dart';
import '../widgets/studio/studio.dart';

/// The codes a host puts beside each work in the room.
///
/// The link inside each code comes from the server, not from string-building here, so the
/// code on the wall and the link the app resolves can never become two different opinions
/// about what a share URL looks like.
///
/// Worth being explicit about what these codes are: **navigation, not admission**. Scanning
/// one opens the piece so somebody can bid from where they are standing. It proves nothing
/// and lets nobody in — which is exactly why a visitor can photograph it, send it to a
/// friend across the room, and have that work too.
class EventQrCodesPage extends StatefulWidget {
  const EventQrCodesPage({super.key, required this.eventId, required this.eventTitle});

  final String eventId;
  final String eventTitle;

  static Future<void> open(BuildContext context, {required String eventId, required String eventTitle}) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => EventQrCodesPage(eventId: eventId, eventTitle: eventTitle),
      ),
    );
  }

  @override
  State<EventQrCodesPage> createState() => _EventQrCodesPageState();
}

class _EventQrCodesPageState extends State<EventQrCodesPage> {
  EventQrCodes? _codes;
  bool _loading = true;
  bool _buildingPdf = false;
  String? _error;

  /// Hand the host a finished sheet of cards.
  ///
  /// The whole reason this exists: without it a host has to screenshot each code off this
  /// screen, or paste links into somebody else's QR generator — leaving the app to do the
  /// one thing the feature is for.
  ///
  /// `sharePdf` opens the system sheet, which is where "save to Files", "print" and "send
  /// to the print shop" all live, so one action covers every way a host might want it.
  Future<void> _downloadPdf() async {
    final codes = _codes;
    if (codes == null || _buildingPdf) return;
    setState(() => _buildingPdf = true);
    try {
      final bytes = await EventQrPdf.build(eventTitle: widget.eventTitle, codes: codes);
      if (!mounted) return;
      await Printing.sharePdf(bytes: bytes, filename: _filename());
    } catch (_) {
      if (mounted) showStudioToast(context, 'Could not build the PDF. Please try again.', icon: null);
    } finally {
      if (mounted) setState(() => _buildingPdf = false);
    }
  }

  /// A filename a host can find again on a laptop an hour later.
  String _filename() {
    final slug = widget.eventTitle
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return '${slug.isEmpty ? 'event' : slug}-codes.pdf';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final codes = await EventService.instance.qrCodes(widget.eventId);
      if (!mounted) return;
      setState(() {
        _codes = codes;
        _loading = false;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load the codes for this event.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final codes = _codes;
    return Scaffold(
      backgroundColor: c.background,
      appBar: StudioTopBar(context: context, title: 'Codes for the room'),
      // The top bar stays put; only the code list placeholds while it is fetched.
      body: _loading && codes == null
          ? const CardListSkeleton(height: 120)
          : _error != null
          ? Center(
              child: StudioEmptyState(
                title: "The codes didn't load",
                message: _error,
                actionLabel: 'Try again',
                onAction: _load,
              ),
            )
          : codes == null || codes.pieces.isEmpty
          ? const Center(
              child: StudioEmptyState(
                title: 'Nothing on the bill yet',
                message: 'Add work to this event and its codes will appear here.',
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(StudioSpace.marginPage, 8, StudioSpace.marginPage, 40),
              children: [
                Text(
                  'Put one beside each piece. Anyone can scan it to see the work and '
                  'bid — no account needed to look.',
                  style: StudioType.label13(color: c.textSecondary),
                ),
                const SizedBox(height: 14),
                // The primary action on this screen: a finished sheet, ready to print and cut.
                StudioButton(
                  label: _buildingPdf ? 'Building…' : 'Download ${codes.pieces.length + 1} cards as PDF',
                  loading: _buildingPdf,
                  onPressed: _buildingPdf ? null : _downloadPdf,
                ),
                const SizedBox(height: 20),
                _QrCard(title: widget.eventTitle, subtitle: 'The event itself', url: codes.eventUrl),
                for (final piece in codes.pieces) ...[
                  const SizedBox(height: 12),
                  _QrCard(
                    title: piece.title ?? 'Untitled',
                    subtitle: [if (piece.artistName != null) piece.artistName!, piece.modeLabel].join(' · '),
                    url: piece.url,
                  ),
                ],
              ],
            ),
    );
  }
}

/// One code: a Card at radius 14 with a Line, the code on white (it must scan in either theme),
/// the title 15/500, the line 12 Graphite and three 13/500 text actions.
class _QrCard extends StatelessWidget {
  const _QrCard({required this.title, required this.subtitle, required this.url});

  final String title;
  final String subtitle;
  final String url;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(StudioRadius.panel),
        border: Border.all(color: c.line),
      ),
      child: Row(
        children: [
          // White quiet zone around the code: a QR printed flush to a coloured edge is
          // measurably harder for a camera to lock onto.
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(StudioRadius.small),
            ),
            child: QrImageView(
              data: url,
              size: 96,
              version: QrVersions.auto,
              eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: StudioColors.ink),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: StudioColors.ink,
              ),
              // Medium recovery: enough to survive a scuff or a thumbprint on a printed
              // card without making the code denser than a phone can read across a room.
              errorCorrectionLevel: QrErrorCorrectLevel.M,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: StudioType.sans(15, weight: StudioType.medium, color: c.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: StudioType.caption12(color: c.textSecondary)),
                Wrap(
                  spacing: 14,
                  children: [
                    _SmallAction(
                      label: 'Copy link',
                      onTap: () async {
                        await Clipboard.setData(ClipboardData(text: url));
                        if (context.mounted) showStudioToast(context, 'Link copied');
                      },
                    ),
                    _SmallAction(
                      label: 'Share link',
                      onTap: () => ShareSheet.show(
                        context,
                        shareText: '$title\n$url',
                        copyLabel: 'Copy',
                        copiedMessage: 'Copied',
                      ),
                    ),
                    // The other half of the job the PDF does not cover: sending one artist
                    // the code for their own piece, or dropping a single code into a poster.
                    _SmallAction(
                      label: 'Share code',
                      onTap: () async {
                        try {
                          await QrImageShare.share(title: title, url: url);
                        } catch (_) {
                          if (context.mounted) {
                            showStudioToast(context, 'Could not share that code.', icon: null);
                          }
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 13/500 Ink text with a 44 tall tap area.
class _SmallAction extends StatelessWidget {
  const _SmallAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: StudioSize.tapTarget,
          child: Center(
            widthFactor: 1,
            child: Text(
              label,
              style: StudioType.label13(weight: StudioType.medium, color: context.studio.textPrimary),
            ),
          ),
        ),
      ),
    );
  }
}
