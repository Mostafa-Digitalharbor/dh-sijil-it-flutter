import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sijil_it/core/network/odoo/odoo_binary.dart';

/// The payload shapes a real Odoo puts on the wire for a binary field.
///
/// Every case here is one an instance actually produces. The app used to
/// treat three of them as "no photo", which is the worst possible answer: the
/// image exists, downloaded fine, and vanished with nothing said about it.
void main() {
  final bytes = Uint8List.fromList(List<int>.generate(200, (i) => i % 256));
  final encoded = base64.encode(bytes);

  group('tryDecode', () {
    test('decodes a plain payload', () {
      expect(OdooBinary.tryDecode(encoded), bytes);
    });

    test('decodes a payload Python wrapped at 76 characters', () {
      // What `base64.encodebytes` — and therefore `xmlrpc.client` — emits.
      final wrapped = <String>[
        for (var i = 0; i < encoded.length; i += 76)
          encoded.substring(i, (i + 76).clamp(0, encoded.length)),
      ].join('\n');

      expect(wrapped, contains('\n'));
      expect(OdooBinary.tryDecode(wrapped), bytes);
    });

    test('decodes a payload with CRLF and surrounding whitespace', () {
      final messy =
          '  \r\n${encoded.substring(0, 40)}\r\n'
          '${encoded.substring(40)}  \n';

      expect(OdooBinary.tryDecode(messy), bytes);
    });

    test('decodes a payload a proxy stripped the padding from', () {
      final unpadded = encoded.replaceAll(RegExp(r'=+$'), '');

      // Only meaningful when this fixture actually needed padding.
      expect(unpadded.length, isNot(encoded.length));
      expect(OdooBinary.tryDecode(unpadded), bytes);
    });

    test('an unset field is null, not an error', () {
      // Odoo sends `false` for an unset binary.
      expect(OdooBinary.tryDecode(false), isNull);
      expect(OdooBinary.tryDecode(null), isNull);
      expect(OdooBinary.tryDecode(''), isNull);
      expect(OdooBinary.tryDecode('   \n  '), isNull);
    });

    test('genuinely corrupt data is null rather than a throw', () {
      expect(OdooBinary.tryDecode('not base64 at all!!'), isNull);
      expect(OdooBinary.tryDecode('%%%%'), isNull);
    });

    test('bytes already decoded pass through', () {
      expect(OdooBinary.tryDecode(bytes), same(bytes));
    });
  });

  group('normalize', () {
    test('leaves a well-formed payload alone', () {
      expect(OdooBinary.normalize(encoded), encoded);
    });

    test('never invents padding that cannot be valid', () {
      // A length of 4n+1 is not a truncated payload, it is a broken one.
      // Padding it would turn "corrupt" into "silently wrong bytes".
      expect(
        OdooBinary.normalize('QUJDRE'.substring(0, 5)).length % 4,
        isNot(0),
      );
    });
  });
}
