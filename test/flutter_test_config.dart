import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Gives every test a canvas larger than any device it simulates.
///
/// Flutter's default test view is 800x600. `TestApp(size:)` lays a screen out
/// at a phone's real dimensions, and a 390x844 phone is taller than that
/// canvas — anything past 600 px would be painted outside the view, where
/// `tester.tap` cannot reach it. A bottom navigation bar is exactly that.
///
/// So the canvas is made bigger than the biggest simulated screen, and the
/// simulated screen is pinned inside it. Nothing reads this size: every widget
/// under test sees the [MediaQuery] and the constraints its own test asked
/// for.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Set on the view rather than through `setSurfaceSize`, which asserts it is
  // called from inside a test. Nothing resets it between tests, so one call
  // here covers the whole file.
  TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.implicitView
    ?..devicePixelRatio = 1
    ..physicalSize = const Size(1400, 1600);

  // Initialising that binding also installs an override that answers every
  // HTTP request with a 400, so that a stray `Image.network` cannot reach the
  // internet from a test. The integration suite speaks XML-RPC to a fake Odoo
  // over a real socket and needs the real client back.
  HttpOverrides.global = null;

  await testMain();
}
