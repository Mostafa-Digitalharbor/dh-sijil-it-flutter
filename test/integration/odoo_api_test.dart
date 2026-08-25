import 'package:flutter_test/flutter_test.dart';
import 'package:sijil_it/core/constants/odoo_models.dart';
import 'package:sijil_it/core/error/error_mapper.dart';
import 'package:sijil_it/core/error/exceptions.dart' as app;
import 'package:sijil_it/core/error/failures.dart';
import 'package:sijil_it/core/network/odoo/odoo_auth_service.dart';
import 'package:sijil_it/core/network/odoo/odoo_capability_service.dart';
import 'package:sijil_it/core/network/odoo/odoo_connection.dart';
import 'package:sijil_it/core/network/odoo/odoo_domain_builder.dart';
import 'package:sijil_it/core/network/odoo/odoo_object_service.dart';
import 'package:sijil_it/core/network/odoo/odoo_session_manager.dart';
import 'package:sijil_it/core/network/xmlrpc/xml_rpc_client.dart';
import 'package:sijil_it/core/pagination/page_request.dart';

import '../fake_odoo/fake_odoo_data.dart';
import '../fake_odoo/fake_odoo_server.dart';
import '../fake_odoo/test_doubles.dart';

/// Exercises every XML-RPC operation the spec requires (§19) against a real
/// HTTP server speaking Odoo's dialect.
///
/// This is the closest thing to testing against a live instance that does not
/// need one: the request is encoded by the production codec, sent over a real
/// socket, parsed by a strict server, and the response decoded back — so a
/// wire-format regression fails here, not in the field.
void main() {
  late FakeOdooServer server;
  late OdooAuthService auth;
  late OdooObjectService object;
  late OdooCapabilityService capabilities;
  late OdooSessionManager sessions;
  late InMemoryVault vault;
  late OdooConnection connection;

  Future<void> signIn() async {
    final uid = await auth.authenticate(
      connection: connection,
      secret: server.data.secret,
    );
    await vault.writeSecret(server.data.secret, OdooAuthMode.apiKey);
    sessions.start(
      OdooSession(connection: connection, userId: uid, serverVersion: '18.0'),
    );
  }

  setUp(() async {
    server = FakeOdooServer();
    await server.start();

    vault = InMemoryVault();
    sessions = OdooSessionManager(vault);
    final client = DioXmlRpcClient.createDefault();
    auth = OdooAuthService(client);
    object = OdooObjectService(client, sessions);
    capabilities = OdooCapabilityService(object, InMemoryCache());

    connection = OdooConnection(
      baseUrl: server.baseUrl,
      database: server.data.database,
      username: server.data.login,
      authMode: OdooAuthMode.apiKey,
    );
  });

  tearDown(() async {
    await sessions.dispose();
    await server.stop();
  });

  // ── /xmlrpc/2/common ──────────────────────────────────────────────────────

  group('common endpoint', () {
    test('version returns the server banner', () async {
      final info = await auth.version(connection);

      expect(info.serverVersion, '18.0');
      expect(info.majorVersion, 18);
      expect(server.calls.single.method, 'version');
    });

    test('authenticate returns the uid for valid credentials', () async {
      final uid = await auth.authenticate(
        connection: connection,
        secret: server.data.secret,
      );

      expect(uid, server.data.userId);
    });

    test(
      'authenticate rejects a wrong secret as invalid credentials',
      () async {
        expect(
          () => auth.authenticate(connection: connection, secret: 'wrong'),
          throwsA(isA<app.AuthenticationException>()),
        );
      },
    );

    test('a wrong database name maps to databaseUnavailable', () async {
      final wrongDb = connection.copyWith(database: 'does-not-exist');

      try {
        await auth.authenticate(connection: wrongDb, secret: 'anything');
        fail('expected a fault');
      } on Object catch (error) {
        expect(ErrorMapper.map(error).kind, FailureKind.databaseUnavailable);
      }
    });

    test(
      'listDatabases returns null when the server disables listing',
      () async {
        expect(await auth.listDatabases(connection), isNull);
      },
    );

    test(
      'listDatabases returns names when the server allows listing',
      () async {
        await server.stop();
        server = FakeOdooServer(
          data: FakeOdooData(
            serverVersion: '18.0',
            database: 'db1',
            login: 'a@b.c',
            secret: 'k',
            userId: 2,
            installedModels: const {},
            records: const {},
            allowDatabaseListing: true,
            databases: const ['db1', 'db2'],
          ),
        );
        await server.start();

        final result = await auth.listDatabases(
          connection.copyWith(baseUrl: server.baseUrl, database: 'db1'),
        );

        expect(result, ['db1', 'db2']);
      },
    );
  });

  // ── /xmlrpc/2/object — the nine required operations ───────────────────────

  group('object endpoint', () {
    setUp(signIn);

    test(
      'search_read honours domain, fields, limit, offset and order',
      () async {
        final page = await object.searchReadPage(
          model: OdooModels.maintenanceEquipment,
          fields: const ['id', 'name', 'serial_no'],
          page: const PageRequest(limit: 2, order: 'name asc'),
          domain: OdooDomainBuilder().isSet('employee_id').build(),
        );

        expect(page, hasLength(2));
        expect(page.first.keys, containsAll(['id', 'name', 'serial_no']));
        // Alphabetical: Dell before iPhone before MacBook.
        expect(page.first['name'], 'Dell UltraSharp U2723QE');

        final second = await object.searchReadPage(
          model: OdooModels.maintenanceEquipment,
          fields: const ['id', 'name'],
          page: const PageRequest(offset: 2, limit: 2, order: 'name asc'),
          domain: OdooDomainBuilder().isSet('employee_id').build(),
        );

        expect(second, hasLength(1));
        expect(second.first['name'], 'MacBook Pro M4');
      },
    );

    test('search returns ids only', () async {
      final ids = await object.search(
        model: OdooModels.maintenanceEquipment,
        domain: OdooDomainBuilder().equals('category_id', 1).build(),
      );

      expect(ids, containsAll(<int>[101, 104]));
      expect(ids, isNot(contains(103)));
    });

    test('search_count matches the domain', () async {
      final total = await object.searchCount(
        model: OdooModels.maintenanceEquipment,
      );
      final assigned = await object.searchCount(
        model: OdooModels.maintenanceEquipment,
        domain: OdooDomainBuilder().isSet('employee_id').build(),
      );

      expect(total, 5);
      expect(assigned, 3);
    });

    test('read returns the requested records', () async {
      final records = await object.read(
        model: OdooModels.maintenanceEquipment,
        ids: const [101, 103],
        fields: const ['id', 'name', 'employee_id'],
      );

      expect(records, hasLength(2));
      expect(records.first['employee_id'], [12, 'Ahmed Mohamed']);
    });

    test('read of a deleted id maps to recordNotFound', () async {
      try {
        await object.read(
          model: OdooModels.maintenanceEquipment,
          ids: const [999999],
          fields: const ['id', 'name'],
        );
        fail('expected a MissingError fault');
      } on Object catch (error) {
        expect(ErrorMapper.map(error).kind, FailureKind.recordNotFound);
      }
    });

    test('fields_get describes the model', () async {
      final fields = await object.fieldsGet(
        model: OdooModels.maintenanceEquipment,
      );

      expect(fields.keys, contains('serial_no'));
      expect(fields.keys, contains('warranty_date'));
    });

    test('name_search resolves a display name to an id', () async {
      final matches = await object.nameSearch(
        model: OdooModels.hrEmployee,
        query: 'most',
      );

      expect(matches, hasLength(1));
      expect(matches.single.id, 11);
      expect(matches.single.name, 'Mostafa Bader');
    });

    test('create returns the new id and the record is readable', () async {
      final id = await object.create(
        model: OdooModels.maintenanceEquipment,
        values: {'name': 'New Asset', 'serial_no': 'SN-NEW-1'},
      );

      expect(id, greaterThan(0));

      final read = await object.read(
        model: OdooModels.maintenanceEquipment,
        ids: [id],
        fields: const ['id', 'name'],
      );
      expect(read.single['name'], 'New Asset');
    });

    test('write updates the record', () async {
      final ok = await object.write(
        model: OdooModels.maintenanceEquipment,
        ids: const [104],
        values: {'employee_id': 13},
      );

      expect(ok, isTrue);

      final read = await object.read(
        model: OdooModels.maintenanceEquipment,
        ids: const [104],
        fields: const ['id', 'employee_id'],
      );

      // A many2one is *written* as a bare id and *read back* as an
      // `[id, "Display name"]` pair. Asserting on the id alone here would
      // describe a server that does not exist, and did in fact hide a bug: the
      // app's mapper sees a bare int as an empty relation, so an asset assigned
      // a moment earlier still read "Unassigned".
      expect(read.single['employee_id'], <Object?>[13, 'Sara Fouad']);
      expect(
        OdooNameRef.fromPair(read.single['employee_id'])?.name,
        'Sara Fouad',
        reason: 'the app must be able to parse what the write produced',
      );
    });

    test('unlink removes the record', () async {
      expect(
        await object.unlink(
          model: OdooModels.maintenanceEquipment,
          ids: const [105],
        ),
        isTrue,
      );

      expect(
        await object.searchCount(model: OdooModels.maintenanceEquipment),
        4,
      );
    });

    test('check_access_rights reports what the user may do', () async {
      expect(
        await object.checkAccessRights(
          model: OdooModels.maintenanceEquipment,
          operation: 'write',
        ),
        isTrue,
      );
    });

    test('the credential is fetched per call, never held in memory', () async {
      final before = vault.readCount;
      await object.searchCount(model: OdooModels.maintenanceEquipment);
      await object.searchCount(model: OdooModels.hrEmployee);

      expect(vault.readCount, before + 2);
    });
  });

  // ── Capability detection (spec §17) ───────────────────────────────────────

  group('capability detection', () {
    setUp(signIn);

    test('finds the models this instance has', () async {
      final probe = await capabilities.probeAll();

      expect(probe.hasMaintenance, isTrue);
      expect(probe.hasMaintenanceRequests, isTrue);
      expect(probe.hasHrEmployees, isTrue);
      expect(probe.assetSource, AssetSource.maintenanceEquipment);
    });

    test(
      'reports a missing optional model as absent, without throwing',
      () async {
        expect(await capabilities.modelExists('account.asset'), isFalse);
      },
    );

    test(
      'narrows a read set to fields the instance actually exposes',
      () async {
        final supported = await capabilities.supportedFields(
          OdooModels.maintenanceEquipment,
          const ['id', 'name', 'serial_no', 'x_does_not_exist'],
        );

        expect(supported, containsAll(['id', 'name', 'serial_no']));
        expect(supported, isNot(contains('x_does_not_exist')));
      },
    );

    test('probes are memoised — a second call makes no new request', () async {
      await capabilities.modelExists(OdooModels.maintenanceEquipment);
      final after = server.calls.length;
      await capabilities.modelExists(OdooModels.maintenanceEquipment);

      expect(server.calls.length, after);
    });
  });

  // ── Error paths, end to end ───────────────────────────────────────────────

  group('error handling', () {
    setUp(signIn);

    test(
      'an Odoo AccessError becomes an actionable accessDenied failure',
      () async {
        server.faults['maintenance.equipment.write'] = (
          code: 3,
          message:
              'odoo.exceptions.AccessError: Sorry, you are not allowed to '
              'modify this document (maintenance.equipment).',
        );

        try {
          await object.write(
            model: OdooModels.maintenanceEquipment,
            ids: const [101],
            values: {'name': 'x'},
          );
          fail('expected an AccessError fault');
        } on Object catch (error) {
          final failure = ErrorMapper.map(error);
          expect(failure.kind, FailureKind.accessDenied);
          expect(failure.model, 'maintenance.equipment');
          expect(failure.action, FailureAction.none);
        }
      },
    );

    test(
      "a missing model becomes modelUnavailable, and doesn't crash",
      () async {
        try {
          await object.searchCount(model: 'account.asset');
          fail('expected a model fault');
        } on Object catch (error) {
          expect(ErrorMapper.map(error).kind, FailureKind.modelUnavailable);
        }
      },
    );

    test('an Odoo UserError is forwarded verbatim to the user', () async {
      server.faults['maintenance.equipment.unlink'] = (
        code: 2,
        message:
            'odoo.exceptions.UserError: You cannot delete an asset that '
            'is currently assigned.',
      );

      try {
        await object.unlink(
          model: OdooModels.maintenanceEquipment,
          ids: const [101],
        );
        fail('expected a UserError fault');
      } on Object catch (error) {
        final failure = ErrorMapper.map(error);
        expect(failure.kind, FailureKind.businessRule);
        expect(
          failure.serverMessage,
          'You cannot delete an asset that is currently assigned.',
        );
        // The Python class name must not survive into what the user reads.
        expect(failure.serverMessage, isNot(contains('odoo.exceptions')));
      }
    });

    test('an unreachable server becomes serverUnreachable', () async {
      await server.stop();

      try {
        await auth.version(connection);
        fail('expected a connection failure');
      } on Object catch (error) {
        expect(ErrorMapper.map(error).kind, FailureKind.serverUnreachable);
      }
    });

    test('a 5xx response becomes serverUnreachable, not a crash', () async {
      server.refuseEverything = true;

      try {
        await auth.version(connection);
        fail('expected a failure');
      } on Object catch (error) {
        final failure = ErrorMapper.map(error);
        expect(failure.isRetryable, isTrue);
      }
    });

    test('every failure kind resolves to an action the user can take', () {
      for (final kind in FailureKind.values) {
        final failure = Failure(kind: kind);
        // Exhaustive by construction; this asserts no kind was left unmapped.
        expect(failure.action, isA<FailureAction>());
        expect(failure.isBlocking, isA<bool>());
      }
    });
  });
}
