import 'dart:async';

import 'package:logger/logger.dart';

/// Runs before every test file (picked up automatically by `flutter test`).
/// Silences the app logger so test output shows only results.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  Logger.level = Level.off;
  await testMain();
}
