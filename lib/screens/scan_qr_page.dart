import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../services/permission_service.dart';
import '../utils/app_destination.dart';

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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Scan a code'),
      ),
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
            left: 24,
            right: 24,
            bottom: 48,
            child: Column(
              children: [
                Text(
                  _error ??
                      'Point your camera at the code beside a piece to see it and bid.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _error == null ? Colors.white70 : const Color(0xFFE5837A),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => setState(() => _error = null),
                    child: const Text('Try again'),
                  ),
                ],
              ],
            ),
          ),
        ],
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
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.photo_camera_outlined, color: Colors.white54, size: 40),
              const SizedBox(height: 16),
              Text(
                denied
                    ? 'Studio 3 needs camera access to scan a code.'
                    : 'The camera is unavailable on this device.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
              ),
              if (denied) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: PermissionService.instance.openSettings,
                  child: const Text('Open settings'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ScanReticle extends StatelessWidget {
  const _ScanReticle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 240,
        height: 240,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white70, width: 2),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
