import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../models/event_check_in.dart';
import '../../models/studio_event.dart';
import '../../services/api_exception.dart';
import '../../services/connectivity_service.dart';
import '../../services/event_service.dart';
import '../../services/offline_check_in.dart';
import '../../services/permission_service.dart';
import '../../widgets/studio/studio.dart';
import 'host_guest_list_page.dart';

/// Check in guests (`HostScanner`, Phase 4.3): the camera reads each ticket's QR code and the
/// result shows over it — the server's message, green for checked in, red for already in or
/// not valid. The live count and the age limit sit at the top; Enter code and Guest list at
/// the bottom. Without the network it checks codes on the phone against the manifest
/// downloaded when it opened, and the scans sync once the phone is back online.
///
/// The camera chrome is copied from `ScanQrPage` (the piece scanner), which stays as it is.
class HostScannerPage extends StatefulWidget {
  const HostScannerPage({super.key, required this.event, this.debugCamera});

  final StudioEvent event;

  /// For tests: drawn in place of the camera, which tests don't have.
  @visibleForTesting
  final Widget? debugCamera;

  /// For tests that reach the page through Manage event: the same, for every scanner opened.
  @visibleForTesting
  static Widget? debugCameraOverride;

  static Future<void> open(BuildContext context, StudioEvent event) {
    return Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => HostScannerPage(event: event)));
  }

  @override
  State<HostScannerPage> createState() => HostScannerPageState();
}

class HostScannerPageState extends State<HostScannerPage> {
  /// The same code again within this long is the camera seeing it twice, not a second scan.
  static const _repeat = Duration(seconds: 3);

  MobileScannerController? _controller;
  final _offline = OfflineCheckIn.instance;
  final _connectivity = ConnectivityService.instance;

  CheckInResult? _result;
  int? _checkedIn;
  int? _total;
  String? _ageLimit;
  int _pending = 0;
  bool _busy = false;
  String? _lastCode;
  DateTime? _lastAt;
  bool _wasOnline = true;

  String get _eventId => widget.event.id;
  Widget? get _debugCamera => widget.debugCamera ?? HostScannerPage.debugCameraOverride;

  @override
  void initState() {
    super.initState();
    if (_debugCamera == null) {
      _controller = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
    }
    _ageLimit = widget.event.ageLimit;
    _wasOnline = _connectivity.isOnline;
    _connectivity.addListener(_onConnectivity);
    _fromCache();
    _prepare();
  }

  @override
  void dispose() {
    _connectivity.removeListener(_onConnectivity);
    _controller?.dispose();
    super.dispose();
  }

  void _fromCache() {
    final m = _offline.manifest(_eventId);
    final counts = _offline.counts(_eventId);
    _pending = _offline.pending(_eventId);
    if (m != null) _ageLimit = m.ageLimit ?? _ageLimit;
    if (counts != null) {
      _checkedIn = counts.checkedIn;
      _total = counts.total;
    }
  }

  /// Send anything left from last time, then download the manifest for working offline.
  Future<void> _prepare() async {
    if (_pending > 0) await _sync();
    final fresh = await _offline.refresh(_eventId);
    if (!mounted || fresh == null) return;
    setState(() {
      _ageLimit = fresh.ageLimit ?? _ageLimit;
      final counts = _offline.counts(_eventId);
      _checkedIn = counts?.checkedIn ?? fresh.checkedIn;
      _total = counts?.total ?? fresh.total;
      _pending = _offline.pending(_eventId);
    });
  }

  void _onConnectivity() {
    final online = _connectivity.isOnline;
    if (online && !_wasOnline) _prepare();
    _wasOnline = online;
    if (mounted) setState(() {});
  }

  Future<void> _sync() async {
    final synced = await _offline.sync(_eventId);
    if (!mounted) return;
    setState(() {
      _pending = _offline.pending(_eventId);
      if (synced != null) {
        _checkedIn = synced.checkedIn ?? _checkedIn;
        _total = synced.total ?? _total;
      }
    });
  }

  void _onDetect(BarcodeCapture capture) {
    final raw = capture.barcodes
        .map((b) => b.rawValue)
        .firstWhere((v) => v != null && v.trim().isNotEmpty, orElse: () => null);
    if (raw != null) scan(raw);
  }

  /// Check [code] in: on the server, or on this phone when the network is away.
  Future<void> scan(String code, {bool typed = false}) async {
    final value = code.trim();
    if (value.isEmpty || _busy) return;
    final now = DateTime.now();
    if (!typed && value == _lastCode && _lastAt != null && now.difference(_lastAt!) < _repeat) return;
    _busy = true;
    _lastCode = value;
    _lastAt = now;
    CheckInResult result;
    try {
      if (!_connectivity.isOnline) {
        result = await _offline.scan(_eventId, value, at: now);
      } else {
        try {
          result = await EventService.instance.checkIn(_eventId, value);
          final ticket = result.ticket;
          if (ticket != null && !result.isInvalid) await _offline.noteCheckedIn(_eventId, ticket);
        } on ApiException catch (e) {
          // No answer at all is the network; anything else is the server's word.
          result = e.statusCode == null
              ? await _offline.scan(_eventId, value, at: now)
              : CheckInResult(result: CheckInResult.invalidResult, message: e.message);
        }
      }
    } catch (_) {
      result = await _offline.scan(_eventId, value, at: now);
    }
    if (!mounted) return;
    unawaited(HapticFeedback.mediumImpact());
    final counts = result.offline ? _offline.counts(_eventId) : null;
    setState(() {
      _busy = false;
      _result = result;
      _checkedIn = result.checkedIn ?? counts?.checkedIn ?? _checkedIn;
      _total = result.total ?? counts?.total ?? _total;
      _pending = _offline.pending(_eventId);
    });
    // Back online with scans waiting: send them now.
    if (!result.offline && _pending > 0) unawaited(_sync());
  }

  Future<void> _enterCode() async {
    final code = await showStudioSheet<String>(context: context, builder: (_) => const _EnterCodeSheet());
    if (code != null && code.trim().isNotEmpty && mounted) await scan(code, typed: true);
  }

  Future<void> _openGuests() async {
    await _controller?.stop();
    if (!mounted) return;
    await HostGuestListPage.open(context, widget.event);
    if (!mounted) return;
    unawaited(_controller?.start());
    _fromCache();
    setState(() {});
    unawaited(_prepare());
  }

  static String? _ageReminder(String? age) => switch (age) {
    '18' => '18+ event: check ID at the door.',
    '21' => '21+ event: check ID at the door.',
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    const white = StudioColors.galleryWhite;
    final dark = StudioColors.dark;
    final age = _ageReminder(_ageLimit);
    final offline = !_connectivity.isOnline;
    final counts = _checkedIn != null && _total != null ? '$_checkedIn/$_total checked in' : null;
    final status = [
      if (offline) 'Offline',
      if (_pending > 0) _pending == 1 ? '1 scan to sync' : '$_pending scans to sync',
    ].join(' · ');
    final result = _result;
    return Scaffold(
      backgroundColor: StudioColors.ink,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _debugCamera ??
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
                child: Column(
                  children: [
                    Row(
                      children: [
                        StudioTopIcon(
                          icon: StudioIcons.back,
                          onTap: () => Navigator.of(context).maybePop(),
                          semanticLabel: 'Back',
                        ),
                        Expanded(
                          child: Text(
                            'Check in guests',
                            textAlign: TextAlign.center,
                            style: StudioType.sans(16, weight: StudioType.medium, color: white),
                          ),
                        ),
                        const SizedBox(width: 44),
                      ],
                    ),
                    if (counts != null) ...[
                      const SizedBox(height: 4),
                      Text(counts, style: StudioType.mono(14, color: white)),
                    ],
                    if (age != null) ...[
                      const SizedBox(height: 4),
                      Text(age, style: StudioType.label13(color: StudioColors.onDarkSecondary)),
                    ],
                    if (status.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(status, style: StudioType.caption12(color: StudioColors.onDarkSecondary)),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 32,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (result == null)
                    Text(
                      "Point your camera at a guest's ticket.",
                      textAlign: TextAlign.center,
                      style: StudioType.body14(color: StudioColors.onDarkSecondary),
                    )
                  else
                    _ResultBanner(key: const ValueKey('check-in-result'), result: result, colors: dark),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _DarkTextButton(label: 'Enter code', onTap: _enterCode),
                      const SizedBox(width: 12),
                      _DarkTextButton(label: 'Guest list', onTap: _openGuests),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The last scan: what happened in green (checked in) or red (already in, not valid), and
/// the server's message under it.
class _ResultBanner extends StatelessWidget {
  const _ResultBanner({super.key, required this.result, required this.colors});

  final CheckInResult result;
  final StudioColors colors;

  @override
  Widget build(BuildContext context) {
    final ok = result.isCheckedIn;
    final tone = ok ? colors.positive : colors.alert;
    final title = ok ? 'Checked in' : (result.isAlready ? 'Already checked in' : 'Not valid');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: ok ? colors.positiveBg : colors.alertBg,
        borderRadius: BorderRadius.circular(StudioRadius.panel),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: StudioType.sans(15, weight: StudioType.medium, color: tone),
          ),
          const SizedBox(height: 2),
          Text(result.message, style: StudioType.body14(color: StudioColors.galleryWhite)),
          if (result.offline && ok) ...[
            const SizedBox(height: 4),
            Text(
              "Saved on this phone. It syncs when you're back online.",
              style: StudioType.caption12(color: StudioColors.onDarkSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

/// Enter code: the ticket number under the QR, for a code that won't scan.
class _EnterCodeSheet extends StatefulWidget {
  const _EnterCodeSheet();

  @override
  State<_EnterCodeSheet> createState() => _EnterCodeSheetState();
}

class _EnterCodeSheetState extends State<_EnterCodeSheet> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StudioSheet(
      horizontalPadding: StudioSpace.marginForm,
      gap: 16,
      children: [
        Text('Enter code', style: StudioType.title22(color: context.studio.textPrimary)),
        StudioUnderlineField(
          label: 'Ticket number',
          controller: _code,
          hint: 'S3-T-8KQ2XM',
          mono: true,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.done,
          onSubmitted: (v) => Navigator.pop(context, v.trim()),
        ),
        StudioButton(label: 'Check in', onPressed: () => Navigator.pop(context, _code.text.trim())),
      ],
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
                    ? 'Studio 3 needs camera access to scan tickets. You can still enter codes.'
                    : 'The camera is unavailable on this device. You can still enter codes.',
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
