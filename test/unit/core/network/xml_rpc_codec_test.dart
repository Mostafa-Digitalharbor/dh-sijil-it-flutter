import 'package:flutter_test/flutter_test.dart';
import 'package:sijil_it/core/error/exceptions.dart';
import 'package:sijil_it/core/network/xmlrpc/xml_rpc_codec.dart';

void main() {
  group('XmlRpcCodec.encodeRequest', () {
    test('encodes an authenticate call the way Odoo expects', () {
      final xml = XmlRpcCodec.encodeRequest('authenticate', <Object?>[
        'company-production',
        'admin@company.com',
        'secret',
        const <String, dynamic>{},
      ]);

      expect(xml, contains('<methodName>authenticate</methodName>'));
      expect(xml, contains('<string>company-production</string>'));
      expect(xml, contains('<struct/>'));
    });

    test('encodes a nested execute_kw domain as an array of arrays', () {
      final xml = XmlRpcCodec.encodeRequest('execute_kw', <Object?>[
        'db',
        2,
        'secret',
        'maintenance.equipment',
        'search_read',
        <Object?>[
          <Object?>[
            <Object?>['employee_id', '!=', false],
          ],
        ],
        <String, dynamic>{'limit': 50},
      ]);

      expect(xml, contains('<string>employee_id</string>'));
      expect(xml, contains('<boolean>0</boolean>'));
      expect(xml, contains('<name>limit</name>'));
      expect(xml, contains('<int>50</int>'));
    });

    test('encodes null as nil rather than dropping the argument', () {
      final xml = XmlRpcCodec.encodeRequest('m', <Object?>[null]);
      expect(xml, contains('<nil/>'));
    });
  });

  group('XmlRpcCodec.decodeResponse', () {
    test('decodes a uid integer', () {
      const body =
          '<?xml version="1.0"?><methodResponse><params><param>'
          '<value><int>7</int></value></param></params></methodResponse>';

      expect(XmlRpcCodec.decodeResponse(body), 7);
    });

    test('decodes a search_read result into records', () {
      const body = '''
<?xml version="1.0"?>
<methodResponse><params><param><value><array><data>
  <value><struct>
    <member><name>id</name><value><int>12</int></value></member>
    <member><name>name</name><value><string>MacBook Pro M4</string></value></member>
    <member><name>employee_id</name><value><array><data>
      <value><int>3</int></value>
      <value><string>Ahmed Mohamed</string></value>
    </data></array></value></member>
  </struct></value>
</data></array></value></param></params></methodResponse>''';

      final decoded = XmlRpcCodec.decodeResponse(body);

      expect(decoded, isA<List<Object?>>());
      final record = (decoded! as List).first as Map<String, dynamic>;
      expect(record['id'], 12);
      expect(record['name'], 'MacBook Pro M4');
      expect(record['employee_id'], [3, 'Ahmed Mohamed']);
    });

    test('decodes Odoo false for an empty relational field', () {
      const body =
          '<?xml version="1.0"?><methodResponse><params><param>'
          '<value><boolean>0</boolean></value></param></params>'
          '</methodResponse>';

      expect(XmlRpcCodec.decodeResponse(body), false);
    });

    test('throws XmlRpcFault carrying the Odoo exception class', () {
      const body = '''
<?xml version="1.0"?>
<methodResponse><fault><value><struct>
  <member><name>faultCode</name><value><int>1</int></value></member>
  <member><name>faultString</name><value><string>odoo.exceptions.AccessError: Not allowed to modify this record</string></value></member>
</struct></value></fault></methodResponse>''';

      expect(
        () => XmlRpcCodec.decodeResponse(body),
        throwsA(
          isA<XmlRpcFault>().having(
            (f) => f.faultString,
            'faultString',
            contains('AccessError'),
          ),
        ),
      );
    });

    test('throws a typed parsing error for a non-XML body', () {
      expect(
        () => XmlRpcCodec.decodeResponse('<html>404 Not Found</html>'),
        throwsA(isA<ResponseParsingException>()),
      );
    });
  });
  group('XmlRpcCodec.decode', () {
    /// A response big enough to cross the offload threshold, shaped like the
    /// one that motivated it: an attachment's base64 payload.
    String largeResponse(String payload) =>
        '<?xml version="1.0"?><methodResponse><params><param>'
        '<value><string>$payload</string></value>'
        '</param></params></methodResponse>';

    test('a small payload decodes without leaving the isolate', () async {
      const body =
          '<?xml version="1.0"?><methodResponse><params><param>'
          '<value><int>7</int></value></param></params></methodResponse>';

      expect(body.length, lessThan(XmlRpcCodec.offloadThreshold));
      // Synchronous completion: an await for every small round trip would
      // cost a frame each time.
      expect(await XmlRpcCodec.decode(body), 7);
    });

    test(
      'a large payload decodes to the same value as the sync path',
      () async {
        final payload = 'A' * XmlRpcCodec.offloadThreshold;
        final body = largeResponse(payload);

        expect(body.length, greaterThan(XmlRpcCodec.offloadThreshold));
        expect(await XmlRpcCodec.decode(body), payload);
        expect(XmlRpcCodec.decodeResponse(body), payload);
      },
    );

    test(
      'a fault raised off-isolate still arrives as an XmlRpcFault',
      () async {
        // The exception has to cross the isolate boundary intact, or a server
        // error on a large response degrades into a generic one.
        final filler = 'x' * XmlRpcCodec.offloadThreshold;
        final body =
            '<?xml version="1.0"?><methodResponse><fault><value><struct>'
            '<member><name>faultCode</name><value><int>3</int></value></member>'
            '<member><name>faultString</name>'
            '<value><string>AccessDenied $filler</string></value></member>'
            '</struct></value></fault></methodResponse>';

        expect(body.length, greaterThan(XmlRpcCodec.offloadThreshold));
        await expectLater(
          XmlRpcCodec.decode(body),
          throwsA(
            isA<XmlRpcFault>()
                .having((f) => f.faultCode, 'faultCode', 3)
                .having(
                  (f) => f.faultString,
                  'faultString',
                  contains('AccessDenied'),
                ),
          ),
        );
      },
    );

    test(
      'a malformed large payload still becomes a parsing exception',
      () async {
        final body = '<html>${'y' * XmlRpcCodec.offloadThreshold}';

        await expectLater(
          XmlRpcCodec.decode(body),
          throwsA(isA<ResponseParsingException>()),
        );
      },
    );
  });
}
