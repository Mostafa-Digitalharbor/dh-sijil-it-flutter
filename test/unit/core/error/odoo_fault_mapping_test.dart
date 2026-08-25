import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sijil_it/core/error/error_mapper.dart';
import 'package:sijil_it/core/error/exceptions.dart';
import 'package:sijil_it/core/error/failure_presenter.dart';
import 'package:sijil_it/core/error/failures.dart';
import 'package:sijil_it/l10n/generated/app_localizations.dart';

/// Every string in this file was **recorded from the customer's Odoo 19.0+e**
/// by provoking the error against the live instance, not written from memory.
///
/// That distinction is the point. The mapper used to test clean against
/// invented fault text and still mis-classified what the server actually
/// sends: Odoo 19 reports a constraint failure with no exception class in the
/// fault at all, so "Missing required value for the field 'Subjects'" — the
/// one sentence that says what to fix — was being shown to the user as a
/// generic "server problem, try again".
void main() {
  Failure mapFault(String faultString) =>
      ErrorMapper.map(OdooFaultException(faultString));

  group('classifying what Odoo 19 actually returns', () {
    test('a model the instance does not have', () {
      final failure = mapFault("Object sijil.no.such.model doesn't exist");

      expect(failure.kind, FailureKind.modelUnavailable);
    });

    test('a field the instance does not have, named', () {
      final failure = mapFault(
        "ValueError: Invalid field 'x_sijil_status' on 'maintenance.equipment'",
      );

      expect(failure.kind, FailureKind.fieldUnavailable);
      expect(failure.serverMessage, 'x_sijil_status',
          reason: 'the user needs to know which field');
    });

    test('a field that does not exist inside a search domain', () {
      final failure = mapFault(
        'ValueError: Invalid field maintenance.equipment.x_nope in condition '
        "('x_nope', '=', 1)",
      );

      expect(failure.kind, FailureKind.fieldUnavailable);
    });

    test('a record that was deleted', () {
      final failure = mapFault(
        'Record does not exist or has been deleted.\n'
        '(Record: maintenance.equipment(99999999,), User: 2)',
      );

      expect(failure.kind, FailureKind.recordNotFound);
    });

    test("a required field, in Odoo's own words", () {
      // The regression this file exists for. No `ValidationError:` marker
      // anywhere in the fault — just the sentence.
      final failure = mapFault(
        'The operation cannot be completed: Missing required value for the '
        "field 'Subjects' (name).\n"
        "Model: 'Maintenance Request' (maintenance.request)\n"
        '- create/update: a mandatory field is not set\n'
        '- delete: another model requires the record being deleted, you can '
        'archive it instead\n',
      );

      expect(failure.kind, FailureKind.businessRule);
      expect(
        failure.serverMessage,
        contains('Missing required value'),
        reason: "Odoo's sentence is better than anything we would write",
      );
      expect(failure.isBlocking, isFalse,
          reason: 'a form error belongs in a snackbar, not over the screen');
    });

    test('a database name that does not exist', () {
      final failure = mapFault(
        'psycopg2.OperationalError: connection to server at "192.168.1.1", '
        'port 5432 failed: FATAL:  database "no-such-db" does not exist',
      );

      expect(failure.kind, FailureKind.databaseUnavailable);
      expect(failure.action, FailureAction.editConnection,
          reason: 'the fix is one field on the connection screen');
    });

    test('a method this Odoo version does not have', () {
      final failure = mapFault(
        "AttributeError: The method 'maintenance.equipment.no_such_method' "
        'does not exist',
      );

      // Genuinely ours to fix, not the user's — so it stays retryable and
      // generic rather than pretending the user can act on it.
      expect(failure.kind, FailureKind.server);
    });

    test('a value Odoo could not coerce', () {
      final failure = mapFault(
        "ValueError: could not convert string to float: 'not-a-number'",
      );

      expect(failure.kind, FailureKind.server);
    });

    test('an access error still names the model and the operation', () {
      final failure = mapFault(
        'odoo.exceptions.AccessError: You are not allowed to modify this '
        'document (maintenance.equipment).',
      );

      expect(failure.kind, FailureKind.accessDenied);
      expect(failure.model, 'maintenance.equipment');
      expect(failure.operation, isNotNull);
    });

    test('a database problem outranks the permission wording it contains', () {
      // Odoo answers a wrong database with a message that also says
      // "AccessDenied". Reading permissions first sends the user to their
      // administrator instead of to the one field they need to correct.
      final failure = mapFault(
        'AccessDenied: database "typo-db" does not exist',
      );

      expect(failure.kind, FailureKind.databaseUnavailable);
    });
  });

  group('what the user is actually shown', () {
    late AppL10n en;
    late AppL10n ar;

    setUpAll(() async {
      en = await AppL10n.delegate.load(const Locale('en'));
      ar = await AppL10n.delegate.load(const Locale('ar', 'EG'));
    });

    test('every failure kind has a title, a cause and a fix, in both languages',
        () {
      // The contract the presenter promises. An empty string here is a screen
      // that says something happened and leaves the user with nowhere to go.
      for (final kind in FailureKind.values) {
        for (final l10n in <AppL10n>[en, ar]) {
          final presented = FailurePresenter.present(l10n, Failure(kind: kind));

          expect(presented.title.trim(), isNotEmpty, reason: kind.name);
          expect(presented.body.trim(), isNotEmpty, reason: kind.name);
          expect(presented.fix.trim(), isNotEmpty,
              reason: '${kind.name} leaves the user with no next step');
        }
      }
    });

    test('a kind that offers an action always labels it', () {
      for (final kind in FailureKind.values) {
        final presented = FailurePresenter.present(en, Failure(kind: kind));
        if (presented.action == FailureAction.none) continue;

        expect(presented.actionLabel.trim(), isNotEmpty, reason: kind.name);
        expect(presented.hasAction, isTrue, reason: kind.name);
      }
    });

    test('the snackbar form is never empty either', () {
      for (final kind in FailureKind.values) {
        expect(
          FailurePresenter.shortMessage(en, Failure(kind: kind)).trim(),
          isNotEmpty,
          reason: kind.name,
        );
      }
    });

    test('an unrecognised fault still produces something actionable', () {
      // The catch-all. Whatever a future Odoo invents, the user gets a
      // sentence and a button rather than a blank screen.
      final failure = mapFault('something nobody has seen before');
      final presented = FailurePresenter.present(en, failure);

      expect(presented.title.trim(), isNotEmpty);
      expect(presented.fix.trim(), isNotEmpty);
      expect(presented.action, FailureAction.retry);
    });

    test('a raw exception that is not an AppException is still handled', () {
      // Nothing may reach a Cubit as an exception; a TypeError from a
      // malformed Odoo row has to come out the other side as a Failure.
      final failure = ErrorMapper.map(
        TypeError(),
        StackTrace.current,
      );

      expect(failure.kind, FailureKind.unknown);
      expect(FailurePresenter.present(en, failure).fix.trim(), isNotEmpty);
    });

    test('the technical detail never reaches the words the user reads', () {
      const traceback =
          'Traceback (most recent call last):\n  File "/home/odoo/src/odoo/'
          'odoo/api.py", line 461\nodoo.exceptions.UserError: Cannot scrap an '
          'assigned asset.';
      final presented = FailurePresenter.present(en, mapFault(traceback));

      expect(presented.body, 'Cannot scrap an assigned asset.');
      expect(presented.body, isNot(contains('Traceback')));
      expect(presented.body, isNot(contains('odoo.exceptions')));
      expect(presented.technicalDetails, contains('Traceback'),
          reason: 'kept for Settings → Diagnostics, shown nowhere else');
    });
  });
}
