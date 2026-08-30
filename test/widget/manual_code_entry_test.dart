import 'package:flutter_test/flutter_test.dart';
import 'package:sijil_it/app/di/injector.dart';
import 'package:sijil_it/core/constants/app_constants.dart';
import 'package:sijil_it/features/scanner/presentation/cubit/scanner_cubit.dart';
import 'package:sijil_it/l10n/generated/app_localizations.dart';

import '../fake_odoo/fake_odoo_data.dart';
import '../fake_odoo/test_app_harness.dart';

/// The way in when the camera is not the answer.
///
/// The scanner used to have no alternative at all: a scuffed sticker, a dark
/// store room or a label on the underside of a desk was a dead end, with the
/// screen still instructing the user to point a camera at a code it could not
/// read.
///
/// The fix is deliberately not a second lookup — a typed code goes through the
/// same `onDetected` path a scanned one does, so everything that resolves from
/// the camera resolves from the keyboard and neither can drift.
void main() {
  late FakeOdooData data;
  late AppL10n l10n;

  setUp(() async {
    data = FakeOdooData.seeded();
    await configureTestDependencies(data: data);
    l10n = await loadL10n();
    await signInForTest(data);
  });

  tearDown(() async => sl.reset());

  test('a typed serial resolves the same asset a scan would', () async {
    final cubit = sl<ScannerCubit>();

    // The serial printed on the fixture's MacBook.
    await cubit.onDetected('C02XK1YZQ6L4');

    expect(cubit.state.match?.id, 101);
    expect(cubit.state.unmatchedCode, isNull);
    await cubit.close();
  });

  test('a typed QR payload addresses the record directly', () async {
    final cubit = sl<ScannerCubit>();

    await cubit.onDetected('${AppConstants.qrScheme}://103');

    expect(cubit.state.match?.id, 103);
    await cubit.close();
  });

  test('surrounding whitespace is forgiven', () async {
    // Somebody typing a serial off a sticker adds a trailing space far more
    // often than a scanner does.
    final cubit = sl<ScannerCubit>();

    await cubit.onDetected('  C02XK1YZQ6L4 ');

    expect(cubit.state.match?.id, 101);
    await cubit.close();
  });

  test('a code that matches nothing is an offer, not a failure', () async {
    final cubit = sl<ScannerCubit>();

    await cubit.onDetected('NOT-A-REAL-TAG');

    expect(cubit.state.match, isNull);
    expect(cubit.state.unmatchedCode, 'NOT-A-REAL-TAG');
    expect(cubit.state.failure, isNull);
    await cubit.close();
  });

  test('the screens that offer it all have the words for it', () {
    // Both the scanner and the audit walk open the same dialog. The audit is
    // where it matters most: a stock count is a fixed target, and one
    // unreadable sticker otherwise leaves an asset counted as missing when it
    // is in the room.
    expect(l10n.scanEnterCode, isNotEmpty);
    expect(l10n.scanEnterCodeTitle, isNotEmpty);
    expect(l10n.scanEnterCodeHint, isNotEmpty);
  });
}
