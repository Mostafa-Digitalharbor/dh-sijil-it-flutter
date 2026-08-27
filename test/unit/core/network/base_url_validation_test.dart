import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sijil_it/core/error/exceptions.dart';
import 'package:sijil_it/core/network/odoo/odoo_connection.dart';
import 'package:sijil_it/l10n/generated/app_localizations.dart';
import 'package:sijil_it/shared/utils/l10n_lookup.dart';

/// What the connection screen says when the URL is refused.
///
/// Every rejection used to collapse into one message. `http://demo.odoo.com`
/// is a perfectly well-formed URL — telling the user it "doesn't look like a
/// valid server address" sends them to re-read the host name when the only
/// thing wrong is the scheme. The translated string that names the scheme
/// existed in both languages already and nothing in the app could reach it.
void main() {
  group('scheme', () {
    test('a bare host is assumed to be https', () {
      expect(
        OdooConnection.parseBaseUrl('company.odoo.com').toString(),
        'https://company.odoo.com',
      );
    });

    test('https is kept', () {
      expect(
        OdooConnection.parseBaseUrl('https://company.odoo.com/').toString(),
        'https://company.odoo.com',
      );
    });

    test('http is refused, and says so', () {
      // Not accepted-and-left-to-fail: neither platform will send cleartext,
      // so a connection saved with it can only produce a confusing "server
      // unreachable" after a full timeout.
      try {
        OdooConnection.parseBaseUrl('http://demo.odoo.com');
        fail('http:// should be refused');
      } on InputValidationException catch (error) {
        expect(error.validationKey, OdooConnection.validationHttpsRequired);
      }
    });

    test('a scheme that is neither is refused as https-required too', () {
      try {
        OdooConnection.parseBaseUrl('ftp://demo.odoo.com');
        fail('ftp:// should be refused');
      } on InputValidationException catch (error) {
        expect(error.validationKey, OdooConnection.validationHttpsRequired);
      }
    });
  });

  group('the key reaches the user as words', () {
    late AppL10n en;
    late AppL10n ar;

    setUpAll(() async {
      en = await AppL10n.delegate.load(const Locale('en'));
      ar = await AppL10n.delegate.load(const Locale('ar'));
    });

    test('https-required resolves to its own message, not the generic one', () {
      final message = en.lookup(OdooConnection.validationHttpsRequired);

      expect(message, en.validationHttpsRequired);
      expect(
        message,
        isNot(en.validationInvalidUrl),
        reason: 'this is the collapse the whole change exists to undo',
      );
      expect(message, contains('https'));
    });

    test('and in Arabic', () {
      expect(
        ar.lookup(OdooConnection.validationHttpsRequired),
        ar.validationHttpsRequired,
      );
      expect(
        ar.lookup(OdooConnection.validationHttpsRequired),
        isNot(ar.validationInvalidUrl),
      );
    });

    test('every key parseBaseUrl raises has a message of its own', () {
      // A key with no case in the lookup silently degrades to the generic
      // validation message, which is the failure this file is about.
      for (final key in <String>[
        OdooConnection.validationServerUrlRequired,
        OdooConnection.validationUrlInvalid,
        OdooConnection.validationHttpsRequired,
      ]) {
        expect(
          en.lookup(key),
          isNot(en.errorValidationFix),
          reason: '$key fell through to the generic message',
        );
      }
    });
  });

  group('malformed input keeps the generic message', () {
    test('an empty URL asks for one', () {
      try {
        OdooConnection.parseBaseUrl('   ');
        fail('empty should be refused');
      } on InputValidationException catch (error) {
        expect(error.validationKey, OdooConnection.validationServerUrlRequired);
      }
    });

    test('something with no host is invalid rather than https-required', () {
      try {
        OdooConnection.parseBaseUrl('https://');
        fail('a schemeless host should be refused');
      } on InputValidationException catch (error) {
        expect(error.validationKey, OdooConnection.validationUrlInvalid);
      }
    });
  });
}
