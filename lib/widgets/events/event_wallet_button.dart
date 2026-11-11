import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_wallet_card/core/ios_wallet_platform.dart';
import 'package:flutter_wallet_card/core/wallet_platform.dart' show WalletException;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/event_order.dart';
import '../../services/api_exception.dart';
import '../../services/event_service.dart';
import '../studio/studio.dart';

/// Why the Apple Wallet sheet didn't open, from the native side.
class EventWalletAddError implements Exception {
  const EventWalletAddError({this.alreadyAdded = false});

  /// Every pass is already in Wallet.
  final bool alreadyAdded;
}

/// "Add to Google Wallet" on Android or "Add to Apple Wallet" on iOS, for an order's tickets
/// (B25). Shows only when the server says that wallet can take them ([passes]), so an older or
/// unconfigured server keeps today's look (an empty box).
///
/// Google: `googleWalletUrl`, then the save link opens outside the app. Apple: each ticket's
/// `.pkpass` is fetched with `&ticketId=` (the PassKit package reads single passes, not a
/// `.pkpasses` bundle) and they're handed to Wallet's Add sheet together. With [ticketId] it
/// is just that ticket; otherwise every ticket of [orderId] (from [ticketIds], or
/// `myTickets` at the tap).
class EventWalletButton extends StatefulWidget {
  const EventWalletButton({
    super.key,
    required this.eventId,
    required this.orderId,
    required this.passes,
    this.ticketId,
    this.ticketIds,
  });

  final String eventId;
  final String orderId;
  final EventWalletPasses? passes;

  /// Only this ticket (the ticket screen).
  final String? ticketId;

  /// The order's tickets, when already loaded.
  final List<String>? ticketIds;

  /// Opens Google's save link. Tests replace it.
  @visibleForTesting
  static Future<bool> Function(Uri url) launcher = _launch;

  /// Hands pass files to Apple Wallet's Add sheet. Tests replace it.
  @visibleForTesting
  static Future<void> Function(List<Uint8List> passes) addApplePasses = _addApplePasses;

  @visibleForTesting
  static void debugReset() {
    launcher = _launch;
    addApplePasses = _addApplePasses;
  }

  static Future<bool> _launch(Uri url) => launchUrl(url, mode: LaunchMode.externalApplication);

  static Future<void> _addApplePasses(List<Uint8List> passes) async {
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final files = <File>[
      for (var i = 0; i < passes.length; i++)
        await File('${dir.path}/ticket_${stamp}_$i.pkpass').writeAsBytes(passes[i], flush: true),
    ];
    final wallet = IOSWalletPlatform();
    try {
      if (files.length == 1) {
        await wallet.addToWallet(files.single);
      } else {
        await wallet.addMultipleToWallet(files);
      }
    } on WalletException catch (e) {
      final already = e.code == 'PASS_ALREADY_EXISTS' || e.code == 'NO_NEW_PASSES';
      throw EventWalletAddError(alreadyAdded: already);
    } finally {
      for (final f in files) {
        f.delete().ignore();
      }
    }
  }

  /// Which wallet this device would show for [passes], if any.
  static bool showsFor(EventWalletPasses? passes) => switch (defaultTargetPlatform) {
    TargetPlatform.iOS => passes?.apple ?? false,
    TargetPlatform.android => passes?.google ?? false,
    _ => false,
  };

  @override
  State<EventWalletButton> createState() => _EventWalletButtonState();
}

class _EventWalletButtonState extends State<EventWalletButton> {
  bool _busy = false;

  Future<void> _addGoogle() async {
    final url = await EventService.instance.googleWalletUrl(
      widget.eventId,
      widget.orderId,
      ticketId: widget.ticketId,
    );
    final opened = await EventWalletButton.launcher(Uri.parse(url));
    if (!opened && mounted) showStudioToast(context, 'Could not open Google Wallet.', icon: null);
  }

  Future<void> _addApple() async {
    final events = EventService.instance;
    var ids = widget.ticketId != null ? [widget.ticketId!] : widget.ticketIds;
    ids ??= [
      for (final t in await events.myTickets(widget.eventId))
        if (t.orderId == widget.orderId && t.id.isNotEmpty) t.id,
    ];
    final passes = ids.isEmpty
        // No ticket list (an older ticket feed): the order's own pass, one ticket.
        ? [await events.appleWalletPass(widget.eventId, widget.orderId)]
        : await Future.wait([
            for (final id in ids) events.appleWalletPass(widget.eventId, widget.orderId, ticketId: id),
          ]);
    await EventWalletButton.addApplePasses(passes);
  }

  Future<void> _add(Future<void> Function() add) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await add();
    } on ApiException catch (e) {
      if (mounted) showStudioToast(context, e.message, icon: null);
    } on EventWalletAddError catch (e) {
      if (mounted) {
        showStudioToast(
          context,
          e.alreadyAdded ? 'Already in Apple Wallet.' : 'Could not open Apple Wallet.',
          icon: e.alreadyAdded ? StudioIcons.check : null,
        );
      }
    } catch (_) {
      if (mounted) showStudioToast(context, 'Could not open your wallet.', icon: null);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!EventWalletButton.showsFor(widget.passes)) return const SizedBox.shrink();
    if (defaultTargetPlatform == TargetPlatform.android) {
      // Google's own badge (brand guidelines: black, not recoloured, at least 48 high).
      return Semantics(
        button: true,
        label: 'Add to Google Wallet',
        excludeSemantics: true,
        child: GestureDetector(
          key: const ValueKey('wallet-google'),
          behavior: HitTestBehavior.opaque,
          onTap: _busy ? null : () => _add(_addGoogle),
          child: SizedBox(
            height: 50,
            child: Center(
              child: SvgPicture.asset(
                'assets/event/add_to_google_wallet.svg',
                height: 50,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      );
    }
    return StudioButton(
      key: const ValueKey('wallet-apple'),
      label: 'Add to Apple Wallet',
      variant: StudioButtonVariant.outline,
      height: 48,
      loading: _busy,
      onPressed: () => _add(_addApple),
    );
  }
}
