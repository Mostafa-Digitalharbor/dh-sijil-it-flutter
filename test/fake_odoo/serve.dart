import 'dart:io';

import 'fake_odoo_data.dart';
import 'fake_odoo_server.dart';

/// Runs the fake Odoo as a real server, for driving the app by hand.
///
/// ```
/// dart run test/fake_odoo/serve.dart
/// ```
///
/// The same [FakeOdooServer] the tests use, bound where a device outside this
/// process can reach it — so a build on an emulator or a handset signs in
/// against the identical fixture the suite asserts on, rather than against a
/// customer's live instance or a second set of made-up data that drifts.
///
/// Loopback is deliberately *not* the default here, unlike in the tests: an
/// emulator is another machine as far as the socket is concerned. It reaches
/// the host at the well-known alias below.
Future<void> main(List<String> args) async {
  const port = 8069;
  final data = FakeOdooData.seeded();
  final server = FakeOdooServer(data: data);

  await server.start(address: InternetAddress.anyIPv4, port: port);

  stdout
    ..writeln('Fake Odoo listening on port $port')
    ..writeln('  Android emulator : http://10.0.2.2:$port')
    ..writeln('  This machine     : http://127.0.0.1:$port')
    ..writeln('  Database         : ${data.database}')
    ..writeln('  User             : ${data.login}')
    ..writeln('  Password         : ${data.secret}')
    ..writeln('Ctrl-C to stop.');

  // Nothing else to do: the server serves until the process is killed.
  await ProcessSignal.sigint.watch().first;
  await server.stop();
}
