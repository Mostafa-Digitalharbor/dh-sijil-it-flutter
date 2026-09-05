import 'package:flutter_test/flutter_test.dart';
import 'package:sijil_it/core/network/odoo/odoo_value.dart';

/// Odoo does not send `null`. Every empty field arrives as the boolean
/// `false`, and a mapper that casts directly is wrong on real data about as
/// often as it is right — so these are the rules the whole data layer rests on.
void main() {
  group('readString', () {
    test('false becomes null', () {
      expect(<String, dynamic>{'name': false}.readString('name'), isNull);
    });

    test('a blank string becomes null', () {
      expect(<String, dynamic>{'name': '   '}.readString('name'), isNull);
    });

    test('a missing key becomes null', () {
      expect(<String, dynamic>{}.readString('name'), isNull);
    });

    test('a value is trimmed', () {
      expect(
        <String, dynamic>{'name': '  MacBook  '}.readString('name'),
        'MacBook',
      );
    });
  });

  group('readHtmlAsText', () {
    test('strips tags Odoo stores in an html field', () {
      expect(
        <String, dynamic>{
          'note': '<p>Cracked display.</p>',
        }.readHtmlAsText('note'),
        'Cracked display.',
      );
    });

    test('keeps paragraph breaks as newlines', () {
      final text = <String, dynamic>{
        'note': '<p>First.</p><p>Second.</p>',
      }.readHtmlAsText('note');

      expect(text, 'First.\nSecond.');
    });

    test('turns <br> into a line break', () {
      expect(
        <String, dynamic>{'note': 'a<br/>b'}.readHtmlAsText('note'),
        'a\nb',
      );
    });

    test('decodes the entities Odoo escapes', () {
      expect(
        <String, dynamic>{
          'note': '<p>Dell &amp; HP &lt;3 &quot;kit&quot;</p>',
        }.readHtmlAsText('note'),
        'Dell & HP <3 "kit"',
      );
    });

    // The ampersand has to be decoded last, and this is the case that proves
    // it. An asset genuinely named `Dell <Pro>` is escaped once by Odoo into
    // `&amp;lt;Pro&amp;gt;`. Decoding `&amp;` first yields `&lt;Pro&gt;`,
    // which the following passes then decode a second time into `<Pro>` —
    // markup the record never contained, after the tag stripper has already
    // run and can no longer remove it.
    test('unescapes exactly once, whatever the order of the entities', () {
      expect(
        <String, dynamic>{
          'note': '<p>Dell &amp;lt;Pro&amp;gt;</p>',
        }.readHtmlAsText('note'),
        'Dell &lt;Pro&gt;',
      );
    });

    test('decodes the numeric and named quote forms Odoo emits', () {
      expect(
        <String, dynamic>{
          'note': '<p>O&#39;Brien&apos;s &#34;kit&quot;</p>',
        }.readHtmlAsText('note'),
        'O\'Brien\'s "kit"',
      );
    });

    test('an empty paragraph becomes null, not an empty string', () {
      expect(
        <String, dynamic>{'note': '<p></p>'}.readHtmlAsText('note'),
        isNull,
      );
    });
  });

  group('readDouble', () {
    test('accepts an int, which Odoo sends for a whole float', () {
      expect(<String, dynamic>{'cost': 2499}.readDouble('cost'), 2499.0);
    });

    test('accepts a double', () {
      expect(<String, dynamic>{'cost': 12.5}.readDouble('cost'), 12.5);
    });

    test('false becomes null rather than zero', () {
      expect(<String, dynamic>{'cost': false}.readDouble('cost'), isNull);
    });
  });

  group('readDate', () {
    test('parses a bare date without shifting it', () {
      final value = <String, dynamic>{'d': '2026-08-24'}.readDate('d');

      // A calendar date means that day in every zone; shifting it by the
      // device offset is how a warranty silently expires a day early.
      expect(value, DateTime(2026, 8, 24));
    });

    test('reads a datetime as UTC, because Odoo stores it that way', () {
      final value = <String, dynamic>{
        'd': '2026-08-24 09:30:00',
      }.readDate('d')!;

      expect(value.toUtc(), DateTime.utc(2026, 8, 24, 9, 30));
    });

    test('false becomes null', () {
      expect(<String, dynamic>{'d': false}.readDate('d'), isNull);
    });

    test('nonsense becomes null rather than throwing', () {
      expect(<String, dynamic>{'d': 'not-a-date'}.readDate('d'), isNull);
    });
  });

  group('readRef', () {
    test('parses a many2one pair', () {
      final ref = <String, dynamic>{
        'category_id': <Object?>[3, 'Laptop'],
      }.readRef('category_id')!;

      expect(ref.id, 3);
      expect(ref.name, 'Laptop');
    });

    test('an empty relation becomes null', () {
      expect(
        <String, dynamic>{'category_id': false}.readRef('category_id'),
        isNull,
      );
    });
  });

  group('readSelection', () {
    test('accepts a value the app knows', () {
      expect(
        <String, dynamic>{
          's': 'employee',
        }.readSelection('s', {'employee', 'other'}),
        'employee',
      );
    });

    test('rejects a value a customised Odoo added', () {
      expect(
        <String, dynamic>{'s': 'contractor'}.readSelection('s', {'employee'}),
        isNull,
      );
    });
  });

  group('OdooWrite', () {
    test('a null date clears the field with false, not null', () {
      expect(OdooWrite.date(null), false);
    });

    test('a date is written in Odoo format regardless of locale', () {
      expect(OdooWrite.date(DateTime(2026, 8, 4)), '2026-08-04');
    });

    test('a datetime is written in UTC', () {
      expect(
        OdooWrite.dateTime(DateTime.utc(2026, 8, 4, 7, 5, 9)),
        '2026-08-04 07:05:09',
      );
    });

    test('blank text clears the field', () {
      expect(OdooWrite.text('   '), false);
    });

    test('html escapes characters that would inject markup', () {
      expect(OdooWrite.html('a <b> & "c"'), '<p>a &lt;b&gt; &amp; "c"</p>');
    });

    test('html turns newlines into breaks', () {
      expect(OdooWrite.html('one\ntwo'), '<p>one<br/>two</p>');
    });
  });
}
