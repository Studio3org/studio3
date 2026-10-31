import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../services/permission_service.dart';
import '../utils/app_destination.dart';
import '../widgets/studio/studio.dart';

/// Scanning the code beside a work in the room.
///
/// The code carries a **link, not a token**. It is navigation — it opens the piece so
/// somebody can bid from where they are standing — and it admits nobody and proves nothing.
/// That is deliberate: a visitor can photograph it, send it to a friend, and have that work
/// too, which a token-based code would break.
///
/// Because it is only a link, this screen does not need to understand events at all. It
/// resolves whatever it scanned through the same resolver that handles shared links and
/// notification taps, so a code pointing at a piece, an event or a series all work without
/// this file knowing the difference.
class ScanQrPage extends StatefulWidget {
  const ScanQrPage({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const ScanQrPage()),
    );
  }

  @override
  State<ScanQrPage> createState() => _ScanQrPageState();

  /// Read a scanned string as a destination.
  ///
  /// Handles both shapes a code can carry: the `https://host/share/piece/<id>` link the
  /// backend prints, and the `studio3://piece/<id>` custom scheme, which needs no domain
  /// verification and therefore works before any domain is pointed anywhere.
  ///
  /// Host-agnostic on purpose. The staging backend and the production domain both serve the
  /// same links, and a scanner that only recognised one would stop working the day the
  /// domain is switched.
  @visibleForTesting
  static AppDestination destinationFor(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null) return const AppDestination(AppDestinationType.unknown);
    var segments = uri.scheme == 'studio3'
        ? [uri.host, ...uri.pathSegments]
        : uri.pathSegments;
    if (segments.isNotEmpty && segments.first == 'share') {
      segments = segments.sublist(1);
    }
    return AppDestination.fromSegments(segments);
  }
}

class _ScanQrPageState extends State<ScanQrPage> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );

  /// Set the moment a usable code is seen.
  ///
  /// The camera keeps delivering frames while the piece is being fetched, and without this
  /// a single code scanned once would push the same screen several times.
  bool _handled = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handled) return;
    final raw = capture.barcodes
        .map((b) => b.rawValue)
        .firstWhere((v) => v != null && v.isNotEmpty, orElse: () => null);
    if (raw == null) return;

    final destination = ScanQrPage.destinationFor(raw);
    if (!destination.isKnown) {
      // Somebody else's QR code. Say so rather than silently doing nothing, which reads as
      // a broken camera.
      if (mounted) setState(() => _error = "That code isn't a Studio 3 link.");
      return;
    }

    _handled = true;
    await _controller.stop();
    if (!mounted) return;
    // Replace rather than stack: coming back from the piece should return to wherever the
    // scanner was opened from, not to a live camera pointed at the same code.
    Navigator.pop(context);
    await openDestination(context, destination);
  }

  @override
  Widget build(BuildContext context) {
    // A camera screen: Ink in both themes, white type (like the dark edit screens).
    const white = StudioColors.galleryWhite;
    final alert = StudioColors.dark.alert;
    return Scaffold(
      backgroundColor: StudioColors.ink,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => _CameraUnavailable(error: error),
          ),
          const _ScanReticle(),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 8, 6, 0),
                child: Row(
                  children: [
                    StudioTopIcon(
                      icon: StudioIcons.back,
                      onTap: () => Navigator.of(context).maybePop(),
                      semanticLabel: 'Back',
                    ),
                    Expanded(
                      child: Text(
                        'Scan a code',
                        textAlign: TextAlign.center,
                        style: StudioType.sans(16, weight: StudioType.medium, color: white),
                      ),
                    ),
                    const SizedBox(width: 44),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 48,
            child: Column(
              children: [
                Text(
                  _error ?? 'Point your camera at the code beside a piece to see it and bid.',
                  textAlign: TextAlign.center,
                  style: StudioType.body14(color: _error == null ? StudioColors.onDarkSecondary : alert),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  _DarkTextButton(label: 'Try again', onTap: () => setState(() => _error = null)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A plain white 14/500 text button with a 44 tap area, for the dark camera screen.
class _DarkTextButton extends StatelessWidget {
  const _DarkTextButton({required this.label, required this.onTap});

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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                label,
                style: StudioType.body14(weight: StudioType.medium, color: StudioColors.galleryWhite),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown when the camera cannot start — most often because permission was declined.
class _CameraUnavailable extends StatelessWidget {
  const _CameraUnavailable({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    return ColoredBox(
      color: StudioColors.ink,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StudioIcon(StudioIcons.camera, size: 32, color: StudioColors.onDarkSecondary),
              const SizedBox(height: 16),
              Text(
                denied
                    ? 'Studio 3 needs camera access to scan a code.'
                    : 'The camera is unavailable on this device.',
                textAlign: TextAlign.center,
                style: StudioType.body14(color: StudioColors.onDarkSecondary),
              ),
              if (denied) ...[
                const SizedBox(height: 12),
                _DarkTextButton(label: 'Open settings', onTap: PermissionService.instance.openSettings),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 240 square at radius 16, a 2 px white line at 70 %.
class _ScanReticle extends StatelessWidget {
  const _ScanReticle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 240,
        height: 240,
        decoration: BoxDecoration(
          border: Border.all(color: StudioColors.galleryWhite.withValues(alpha: 0.7), width: 2),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
