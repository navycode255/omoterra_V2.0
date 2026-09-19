import 'dart:async';
import 'package:omoterra/core/auth/session.dart';

/// Runs before every test file. The splash hold is presentational and its
/// timer would outlive the widget tree, so it is off under test.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  SessionController.holdSplash = false;
  await testMain();
}
