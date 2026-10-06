import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/event_qr_code.dart';
import '../services/api_exception.dart';
import '../services/event_service.dart';
import '../theme/home_feed_tokens.dart';
import '../utils/event_qr_pdf.dart';
import '../utils/qr_image_share.dart';
import '../widgets/share/share_sheet.dart';
import '../widgets/loading/app_skeletons.dart';
import '../theme/app_fonts.dart';

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

  static Future<void> open(
    BuildContext context, {
    required String eventId,
    required String eventTitle,
  }) {
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
      final bytes = await EventQrPdf.build(
        eventTitle: widget.eventTitle,
        codes: codes,
      );
      if (!mounted) return;
      await Printing.sharePdf(bytes: bytes, filename: _filename());
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not build the PDF. Please try again.')),
      );
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
    final codes = _codes;
    return Scaffold(
      backgroundColor: HomeFeedTokens.background,
      appBar: AppBar(
        backgroundColor: HomeFeedTokens.background,
        elevation: 0,
        title: Text(
          'Codes for the room',
          style: AppFonts.inter(fontSize: 17, fontWeight: FontWeight.w500),
        ),
        actions: [
          if (_codes != null)
            IconButton(
              tooltip: 'Download as PDF',
              onPressed: _buildingPdf ? null : _downloadPdf,
              icon: _buildingPdf
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.picture_as_pdf_outlined),
            ),
        ],
      ),
      // App bar and its export action stay put; only the code list
      // placeholds while it is fetched.
      body: _loading && codes == null
          ? const CardListSkeleton(height: 120)
          : _error != null
              ? _Message(text: _error!, onRetry: _load)
              : codes == null || codes.pieces.isEmpty
                  ? const _Message(
                      text: 'Nothing on the bill yet. Add work to this event and its codes '
                          'will appear here.',
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                      children: [
                        Text(
                          'Put one beside each piece. Anyone can scan it to see the work and '
                          'bid — no account needed to look.',
                          style: AppFonts.inter(
                            fontSize: 13,
                            height: 1.4,
                            color: HomeFeedTokens.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _DownloadButton(
                          loading: _buildingPdf,
                          onTap: _downloadPdf,
                          count: codes.pieces.length + 1,
                        ),
                        const SizedBox(height: 20),
                        _QrCard(
                          title: widget.eventTitle,
                          subtitle: 'The event itself',
                          url: codes.eventUrl,
                        ),
                        const SizedBox(height: 12),
                        for (final piece in codes.pieces) ...[
                          _QrCard(
                            title: piece.title ?? 'Untitled',
                            subtitle: [
                              if (piece.artistName != null) piece.artistName!,
                              piece.modeLabel,
                            ].join(' · '),
                            url: piece.url,
                          ),
                          const SizedBox(height: 12),
                        ],
                      ],
                    ),
    );
  }
}

class _QrCard extends StatelessWidget {
  const _QrCard({required this.title, required this.subtitle, required this.url});

  final String title;
  final String subtitle;
  final String url;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HomeFeedTokens.skeletonBase),
      ),
      child: Row(
        children: [
          // White quiet zone around the code: a QR printed flush to a coloured edge is
          // measurably harder for a camera to lock onto.
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.white,
            child: QrImageView(
              data: url,
              size: 96,
              version: QrVersions.auto,
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
                  style: AppFonts.inter(fontSize: 15, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppFonts.inter(
                    fontSize: 12,
                    color: HomeFeedTokens.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _SmallAction(
                      label: 'Copy link',
                      onTap: () async {
                        await Clipboard.setData(ClipboardData(text: url));
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Link copied')),
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    _SmallAction(
                      label: 'Share link',
                      onTap: () => ShareSheet.show(
                        context,
                        shareText: '$title\n$url',
                        copyLabel: 'Copy',
                        copiedMessage: 'Copied',
                      ),
                    ),
                    const SizedBox(width: 12),
                    // The other half of the job the PDF does not cover: sending one artist
                    // the code for their own piece, or dropping a single code into a poster.
                    _SmallAction(
                      label: 'Share code',
                      onTap: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          await QrImageShare.share(title: title, url: url);
                        } catch (_) {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Could not share that code.'),
                            ),
                          );
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

class _SmallAction extends StatelessWidget {
  const _SmallAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Text(
        label,
        style: AppFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: HomeFeedTokens.textPrimary,
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.onRetry});

  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: AppFonts.inter(fontSize: 14, height: 1.4),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              TextButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ],
        ),
      ),
    );
  }
}


/// The primary action on this screen: a finished sheet, ready to print and cut.
class _DownloadButton extends StatelessWidget {
  const _DownloadButton({
    required this.loading,
    required this.onTap,
    required this.count,
  });

  final bool loading;
  final VoidCallback onTap;
  final int count;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: FilledButton.icon(
        onPressed: loading ? null : onTap,
        style: FilledButton.styleFrom(
          backgroundColor: HomeFeedTokens.neutral800,
          foregroundColor: HomeFeedTokens.textInverse,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: loading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.download_outlined, size: 18),
        label: Text(
          loading ? 'Building…' : 'Download $count cards as PDF',
          style: AppFonts.inter(fontSize: 15, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}
