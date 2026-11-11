import 'dart:async';
import 'dart:io';

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
  await testMain();
}
