import 'dart:async';
import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Runs before every test file under `test/` (Flutter picks this file up by name).
///
/// Network images go through `cached_network_image`, whose cache keeps its index in SQLite.
/// On a phone the sqflite plugin provides that; the test runner has no plugins, so any screen
/// with artwork failed with "databaseFactory not initialized". This gives the cache a desktop
/// SQLite instead. Test-only: `sqflite_common_ffi` is a dev dependency and never ships.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  sqfliteFfiInit();
  // No background isolate: widget tests run in a fake-async zone that an isolate's
  // messages would never reach.
  databaseFactory = databaseFactoryFfiNoIsolate;
  // Each test file runs in its own process: give each its own folder, so files running side
  // by side never share (or lock) a database, and nothing is written into the project.
  final dir = Directory.systemTemp.createTempSync('studio3_test_db');
  await databaseFactory.setDatabasesPath(dir.path);
  await _preloadBundledFonts();
  await testMain();
}

/// Loads every bundled Inter and Geist weight (`assets/google_fonts/`) before any test runs.
///
/// Since Flutter 3.50 a "fonts changed" message no longer relays text out on the spot: each
/// paragraph schedules the relayout for the next frame. When `google_fonts` loaded a weight
/// on demand partway through a test, that message landed near the end and the test finished
/// with the relayout still pending ("An animation is still running even after the widget
/// tree was disposed"). Loaded here, with no screen built yet, the message is handled before
/// the first test, and `google_fonts` never loads them again.
Future<void> _preloadBundledFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final changed = Completer<void>();
  void onChange() {
    if (!changed.isCompleted) changed.complete();
  }

  PaintingBinding.instance.systemFonts.addListener(onChange);
  try {
    for (final weight in [
      FontWeight.w300,
      FontWeight.w400,
      FontWeight.w500,
      FontWeight.w600,
      FontWeight.w700,
      FontWeight.w800,
    ]) {
      GoogleFonts.inter(fontWeight: weight);
      GoogleFonts.geist(fontWeight: weight);
    }
    await GoogleFonts.pendingFonts();
    // The engine reports the new fonts asynchronously; wait for it (briefly, in case a
    // platform never sends it).
    await changed.future.timeout(const Duration(seconds: 2), onTimeout: () {});
  } catch (_) {
    // A missing bundled weight is bundled_fonts_test.dart's to report, not every test's.
  } finally {
    PaintingBinding.instance.systemFonts.removeListener(onChange);
  }
}
