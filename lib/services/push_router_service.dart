import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../utils/app_destination.dart';

/// Turning a tapped push notification into a screen.
///
/// Before this, nothing in the app listened for a notification tap at all: tapping any push
/// — outbid, sale, follow, or a declined auction payment with a ten-minute deadline on it —
/// opened the app wherever it had last been and left the reader to find the thing
/// themselves.
///
/// There are two separate ways a tap arrives, and handling only one of them is the common
/// mistake:
///
/// * [FirebaseMessaging.onMessageOpenedApp] fires when the app was **already running** in
///   the background.
/// * [FirebaseMessaging.instance.getInitialMessage] returns the notification that **cold
///   started** the process. It is a one-shot read, not a stream, and a notification
///   delivered this way never appears on the stream above — miss it and tapping a push on a
///   closed app silently does nothing, which is the state most people's phone is in.
///
/// A foreground message is deliberately *not* routed. Yanking someone out of what they are
/// doing because a notification arrived is hostile; the in-app list and the live socket
/// already surface it.
class PushRouterService {
  PushRouterService._();
  static final PushRouterService instance = PushRouterService._();

  StreamSubscription<RemoteMessage>? _subscription;
  bool _handledInitial = false;

  /// Start listening for taps, and make sure this device is registered with APNs.
  ///
  /// The [FirebaseMessaging.requestPermission] call looks redundant next to
  /// `PermissionService.requestNotifications`, which already prompts through
  /// permission_handler — it is kept because the two do different jobs on iOS. Both surface
  /// the same system prompt, but only Firebase's own call registers the app with APNs, and
  /// without that registration `getToken()` returns null and the device is never recorded on
  /// the server. On an already-authorised device it is a no-op, so calling both is cheap.
  ///
  /// Everything here is best-effort. Someone who declines notifications must still get a
  /// working app.
  Future<void> start(BuildContext context) async {
    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (_) {
      // Firebase not configured in this build, or the platform channel isn't up yet.
    }

    if (!context.mounted) return;
    await _handleColdStart(context);
    if (!context.mounted) return;
    _listen(context);
  }

  /// The notification that launched the app, if any. Read once per process.
  Future<void> _handleColdStart(BuildContext context) async {
    if (_handledInitial) return;
    _handledInitial = true;
    try {
      final message = await FirebaseMessaging.instance.getInitialMessage();
      if (message == null || !context.mounted) return;
      // The first frame has to be on screen before pushing a route onto it, or the
      // destination is built against a Navigator that does not exist yet.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) _route(context, message);
      });
    } catch (_) {
      // No initial message, or messaging is unavailable.
    }
  }

  void _listen(BuildContext context) {
    if (_subscription != null) return;
    try {
      _subscription = FirebaseMessaging.onMessageOpenedApp.listen((message) {
        if (context.mounted) _route(context, message);
      });
    } catch (_) {
      // Messaging unavailable — the in-app list still works.
    }
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }

  void _route(BuildContext context, RemoteMessage message) {
    final destination = destinationFor(message.data);
    if (!destination.isKnown) return;
    openDestination(context, destination);
  }

  /// The destination encoded in a push payload's `data` map.
  ///
  /// FCM stringifies every data value, so nothing here may assume a non-string type.
  /// Exposed for testing: this is the half of the flow that can be checked without a device.
  @visibleForTesting
  static AppDestination destinationFor(Map<String, dynamic> data) {
    return AppDestination.fromTarget(
      data['targetType'] as String?,
      data['targetId'] as String?,
      actorUsername: data['actorUsername'] as String?,
    );
  }
}
