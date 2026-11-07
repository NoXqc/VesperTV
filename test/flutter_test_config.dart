import 'dart:async';
import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Runs before every test file (Flutter's per-directory test config).
///
/// The suite was written on Windows hosts. Some packages pick their backend
/// from the *host* OS: flutter_cache_manager keeps its image index in sqflite
/// on Android/iOS/macOS but in a JSON file elsewhere. On a macOS host the
/// sqflite factory is not initialized in tests, so any widget showing a
/// network image threw `databaseFactory not initialized`. Give macOS the FFI
/// factory so it behaves like the Windows host the tests were tuned on.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  if (Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  await testMain();
}
