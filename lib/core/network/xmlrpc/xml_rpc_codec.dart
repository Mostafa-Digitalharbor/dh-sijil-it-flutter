import 'dart:convert';
import 'dart:typed_data';

import 'package:xml/xml.dart';

import '../../error/exceptions.dart';

/// An XML-RPC `<fault>` returned by the server.
///
/// Odoo encodes every server-side Python exception this way; the fault string
/// carries the exception class name, which `ErrorMapper` classifies.
class XmlRpcFault implements Exception {
  const XmlRpcFault(this.faultCode, this.faultString);

  final int faultCode;
  final String faultString;

  @override
  String toString() => 'XmlRpcFault($faultCode): $faultString';
}

/// Encodes `methodCall` documents and decodes `methodResponse` documents.
///
/// Pure and synchronous — fully unit-testable with no network involved.
abstract final class XmlRpcCodec {
  // ── Encoding ─────────────────────────────────────────────────────────────

  static String encodeRequest(String methodName, List<Object?> params) {
    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    builder.element(
      'methodCall',
      nest: () {
        builder.element('methodName', nest: () => builder.text(methodName));
        builder.element(
          'params',
          nest: () {
            for (final param in params) {
              builder.element('param', nest: () => _buildValue(builder, param));
            }
          },
        );
      },
    );
    return builder.buildDocument().toXmlString();
  }

  static void _buildValue(XmlBuilder builder, Object? value) {
    builder.element(
      'value',
      nest: () {
        switch (value) {
          case null:
            builder.element('nil');
          case final bool v:
            builder.element('boolean', nest: () => builder.text(v ? '1' : '0'));
          case final int v:
            builder.element('int', nest: () => builder.text('$v'));
          case final double v:
            builder.element('double', nest: () => builder.text('$v'));
          case final String v:
            builder.element('string', nest: () => builder.text(v));
          case final DateTime v:
            builder.element(
              'dateTime.iso8601',
              nest: () => builder.text(_formatDateTime(v)),
            );
          case final Uint8List v:
            builder.element(
              'base64',
              nest: () => builder.text(base64Encode(v)),
            );
          case final List<Object?> v:
            builder.element(
              'array',
              nest: () => builder.element(
                'data',
                nest: () {
                  for (final item in v) {
                    _buildValue(builder, item);
                  }
                },
              ),
            );
          case final Map<Object?, Object?> v:
            builder.element(
              'struct',
              nest: () {
                v.forEach((key, val) {
                  builder.element(
                    'member',
                    nest: () {
                      builder.element('name', nest: () => builder.text('$key'));
                      _buildValue(builder, val);
                    },
                  );
                });
              },
            );
          default:
            // Anything else is serialised through its string form rather than
            // silently dropped.
            builder.element('string', nest: () => builder.text('$value'));
        }
      },
    );
  }

  /// XML-RPC wants `19980717T14:08:55` — no separators in the date part.
  static String _formatDateTime(DateTime value) {
    final utc = value.toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${utc.year}${two(utc.month)}${two(utc.day)}T'
        '${two(utc.hour)}:${two(utc.minute)}:${two(utc.second)}';
  }

  // ── Decoding ─────────────────────────────────────────────────────────────

  /// Parses a `methodResponse` body.
  ///
  /// Throws [XmlRpcFault] for a `<fault>` response and
  /// [ResponseParsingException] when the document is not valid XML-RPC.
  static Object? decodeResponse(String body) {
    final XmlDocument document;
    try {
      document = XmlDocument.parse(body);
    } on XmlException catch (e) {
      throw ResponseParsingException(
        'The server did not return a valid XML-RPC response.',
        technicalDetails: '$e',
      );
    }

    final response = document.getElement('methodResponse');
    if (response == null) {
      throw const ResponseParsingException(
        'The server did not return a valid XML-RPC response.',
        technicalDetails: 'Missing <methodResponse> root element.',
      );
    }

    final fault = response.getElement('fault');
    if (fault != null) {
      final decoded = _parseValue(_requireElement(fault, 'value'));
      if (decoded is Map) {
        final code = decoded['faultCode'];
        return throw XmlRpcFault(
          code is int ? code : -1,
          '${decoded['faultString'] ?? 'Unknown Odoo error'}',
        );
      }
      throw XmlRpcFault(-1, '$decoded');
    }

    final params = response.getElement('params');
    if (params == null) return null;

    final param = params.getElement('param');
    if (param == null) return null;

    return _parseValue(_requireElement(param, 'value'));
  }

  static XmlElement _requireElement(XmlElement parent, String name) {
    final element = parent.getElement(name);
    if (element == null) {
      throw ResponseParsingException(
        'The server returned an unexpected response.',
        technicalDetails: 'Missing <$name> inside <${parent.name.local}>.',
      );
    }
    return element;
  }

  static Object? _parseValue(XmlElement value) {
    final typed = value.childElements.firstOrNull;

    // <value>text</value> with no type element means string.
    if (typed == null) return value.innerText;

    final text = typed.innerText;

    switch (typed.name.local) {
      case 'nil':
        return null;
      case 'boolean':
        return text.trim() == '1';
      case 'int':
      case 'i4':
      case 'i8':
        return int.tryParse(text.trim()) ?? 0;
      case 'double':
        return double.tryParse(text.trim()) ?? 0.0;
      case 'string':
        return text;
      case 'dateTime.iso8601':
        return _parseDateTime(text.trim());
      case 'base64':
        return base64Decode(text.trim());
      case 'array':
        final data = typed.getElement('data');
        if (data == null) return <Object?>[];
        return data.childElements
            .where((e) => e.name.local == 'value')
            .map(_parseValue)
            .toList(growable: false);
      case 'struct':
        final result = <String, dynamic>{};
        for (final member in typed.childElements) {
          if (member.name.local != 'member') continue;
          final name = member.getElement('name')?.innerText;
          final memberValue = member.getElement('value');
          if (name == null || memberValue == null) continue;
          result[name] = _parseValue(memberValue);
        }
        return result;
      default:
        return text;
    }
  }

  static DateTime? _parseDateTime(String raw) {
    // Accepts both `19980717T14:08:55` and ISO-8601 with separators.
    final compact = RegExp(
      r'^(\d{4})(\d{2})(\d{2})T(\d{2}):(\d{2}):(\d{2})$',
    ).firstMatch(raw);

    if (compact != null) {
      return DateTime.utc(
        int.parse(compact.group(1)!),
        int.parse(compact.group(2)!),
        int.parse(compact.group(3)!),
        int.parse(compact.group(4)!),
        int.parse(compact.group(5)!),
        int.parse(compact.group(6)!),
      );
    }
    return DateTime.tryParse(raw);
  }
}
