import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:xml/xml.dart';

import 'fake_odoo_data.dart';

/// A real HTTP server that speaks Odoo's XML-RPC dialect.
///
/// Not a mock of our own client — an actual socket the app connects to. That
/// is the point: it exercises the Dio request, the wire format, the fault
/// encoding and the decoder together, so a bug in any of them shows up here
/// rather than on a customer's instance.
///
/// It is deliberately strict about the shape Odoo requires (positional
/// `execute_kw` args, `false` for empty relations, `<fault>` for errors), so
/// a request the real Odoo would reject is rejected here too.
class FakeOdooServer {
  FakeOdooServer({FakeOdooData? data}) : data = data ?? FakeOdooData.seeded();

  final FakeOdooData data;

  HttpServer? _server;

  /// Faults to raise instead of answering. Keyed by `model.method`, or by the
  /// bare method name for `/common` calls. Lets a test drive the app down a
  /// specific error path — an `AccessError` on `write`, a 500 on `read` —
  /// without touching the app's own code.
  final Map<String, ({int code, String message})> faults = {};

  /// Set to fail every request, simulating an unreachable host.
  bool refuseEverything = false;

  /// Artificial latency, for exercising timeouts and loading states.
  Duration delay = Duration.zero;

  /// Requests received, newest last. Assert against this to prove the app sent
  /// what it should — the right domain, the right field list, the right limit.
  final List<RecordedCall> calls = [];

  Uri get baseUrl {
    final server = _server;
    if (server == null) throw StateError('Server is not running.');
    return Uri.parse('http://${server.address.host}:${server.port}');
  }

  /// Binds and starts serving.
  ///
  /// Defaults to loopback so unit tests cannot accidentally expose a fake Odoo
  /// on the network. Pass [address] `InternetAddress.anyIPv4` when a device or
  /// emulator outside this process needs to reach it.
  Future<void> start({InternetAddress? address, int port = 0}) async {
    _server = await HttpServer.bind(
      address ?? InternetAddress.loopbackIPv4,
      port,
    );
    unawaited(_server!.forEach(_handle));
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  void reset() {
    calls.clear();
    faults.clear();
    refuseEverything = false;
    delay = Duration.zero;
  }

  Future<void> _handle(HttpRequest request) async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);

    if (refuseEverything) {
      request.response.statusCode = HttpStatus.serviceUnavailable;
      await request.response.close();
      return;
    }

    final body = await utf8.decoder.bind(request).join();
    final path = request.uri.path;

    String reply;
    try {
      final call = _parseMethodCall(body);
      calls.add(
        RecordedCall(path: path, method: call.name, params: call.params),
      );

      final result = switch (path) {
        '/xmlrpc/2/common' => _handleCommon(call),
        '/xmlrpc/2/object' => _handleObject(call),
        '/xmlrpc/2/db' => _handleDb(call),
        _ => throw _Fault(404, 'No such endpoint: $path'),
      };
      reply = _encodeResponse(result);
    } on _Fault catch (fault) {
      reply = _encodeFault(fault.code, fault.message);
    } on FakeOdooFault catch (fault) {
      reply = _encodeFault(fault.code, fault.message);
    } on Object catch (error) {
      reply = _encodeFault(1, 'Fake server error: $error');
    }

    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType('text', 'xml', charset: 'utf-8')
      ..write(reply);
    await request.response.close();
  }

  // ── /xmlrpc/2/common ─────────────────────────────────────────────────────

  Object? _handleCommon(_MethodCall call) {
    _maybeFault(call.name);

    switch (call.name) {
      case 'version':
        return <String, dynamic>{
          'server_version': data.serverVersion,
          'server_version_info': <Object?>[
            int.parse(data.serverVersion.split('.').first),
            0,
            0,
            'final',
            0,
            '',
          ],
          'server_serie': data.serverVersion,
          'protocol_version': 1,
        };

      case 'authenticate':
        final database = call.params[0] as String;
        final login = call.params[1] as String;
        final secret = call.params[2] as String;

        if (database != data.database) {
          throw _Fault(
            1,
            'FATAL: database "$database" does not exist\n'
            'odoo.exceptions.AccessDenied',
          );
        }
        // Odoo answers `false` rather than faulting on bad credentials.
        if (login != data.login || secret != data.secret) return false;
        return data.userId;

      case 'about':
        return data.serverVersion;

      default:
        throw _Fault(1, 'Unknown common method: ${call.name}');
    }
  }

  Object? _handleDb(_MethodCall call) {
    _maybeFault(call.name);

    if (call.name == 'list') {
      if (!data.allowDatabaseListing) {
        throw _Fault(1, 'AccessDenied: database listing is disabled');
      }
      return data.databases;
    }
    throw _Fault(1, 'Unknown db method: ${call.name}');
  }

  // ── /xmlrpc/2/object ─────────────────────────────────────────────────────

  Object? _handleObject(_MethodCall call) {
    if (call.name != 'execute_kw') {
      throw _Fault(1, 'Unknown object method: ${call.name}');
    }

    final database = call.params[0] as String;
    final uid = call.params[1] as int;
    final secret = call.params[2] as String;
    final model = call.params[3] as String;
    final method = call.params[4] as String;
    final args = (call.params[5] as List<Object?>?) ?? const <Object?>[];
    final kwargs =
        (call.params.length > 6 ? call.params[6] : null)
            as Map<String, dynamic>? ??
        const <String, dynamic>{};

    if (database != data.database) {
      throw _Fault(1, 'FATAL: database "$database" does not exist');
    }
    if (uid != data.userId || secret != data.secret) {
      throw _Fault(
        3,
        'odoo.exceptions.AccessDenied: Access Denied\n'
        'Session expired',
      );
    }

    _maybeFault('$model.$method');
    _maybeFault(method);

    return data.execute(
      model: model,
      method: method,
      args: args,
      kwargs: kwargs,
    );
  }

  void _maybeFault(String key) {
    final fault = faults[key];
    if (fault != null) throw _Fault(fault.code, fault.message);
  }

  // ── XML-RPC wire format ──────────────────────────────────────────────────

  static _MethodCall _parseMethodCall(String body) {
    final document = XmlDocument.parse(body);
    final call = document.getElement('methodCall');
    if (call == null) throw _Fault(1, 'Not a methodCall');

    final name = call.getElement('methodName')?.innerText ?? '';
    final params = <Object?>[];

    final paramsElement = call.getElement('params');
    if (paramsElement != null) {
      for (final param in paramsElement.childElements) {
        if (param.name.local != 'param') continue;
        final value = param.getElement('value');
        if (value != null) params.add(_parseValue(value));
      }
    }

    return _MethodCall(name, params);
  }

  static Object? _parseValue(XmlElement value) {
    final typed = value.childElements.firstOrNull;
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
        return int.parse(text.trim());
      case 'double':
        return double.parse(text.trim());
      case 'string':
        return text;
      case 'base64':
        return base64Decode(text.trim());
      case 'array':
        final items = typed
            .getElement('data')
            ?.childElements
            .where((e) => e.name.local == 'value')
            .map(_parseValue)
            .toList();
        return items ?? <Object?>[];
      case 'struct':
        final map = <String, dynamic>{};
        for (final member in typed.childElements) {
          final key = member.getElement('name')?.innerText;
          final memberValue = member.getElement('value');
          if (key != null && memberValue != null) {
            map[key] = _parseValue(memberValue);
          }
        }
        return map;
      default:
        return text;
    }
  }

  static String _encodeResponse(Object? result) {
    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0"');
    builder.element(
      'methodResponse',
      nest: () => builder.element(
        'params',
        nest: () =>
            builder.element('param', nest: () => _buildValue(builder, result)),
      ),
    );
    return builder.buildDocument().toXmlString();
  }

  static String _encodeFault(int code, String message) {
    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0"');
    builder.element(
      'methodResponse',
      nest: () => builder.element(
        'fault',
        nest: () => _buildValue(builder, <String, dynamic>{
          'faultCode': code,
          'faultString': message,
        }),
      ),
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
              nest: () => v.forEach((key, val) {
                builder.element(
                  'member',
                  nest: () {
                    builder.element('name', nest: () => builder.text('$key'));
                    _buildValue(builder, val);
                  },
                );
              }),
            );
          default:
            builder.element('string', nest: () => builder.text('$value'));
        }
      },
    );
  }
}

/// A request the fake server received.
class RecordedCall {
  const RecordedCall({
    required this.path,
    required this.method,
    required this.params,
  });

  final String path;
  final String method;
  final List<Object?> params;

  /// For `execute_kw`, the model the call targeted.
  String? get model =>
      method == 'execute_kw' && params.length > 3 ? params[3] as String? : null;

  /// For `execute_kw`, the Odoo method invoked.
  String? get modelMethod =>
      method == 'execute_kw' && params.length > 4 ? params[4] as String? : null;

  Map<String, dynamic> get kwargs => method == 'execute_kw' && params.length > 6
      ? (params[6] as Map<String, dynamic>? ?? const {})
      : const {};

  List<Object?> get args => method == 'execute_kw' && params.length > 5
      ? (params[5] as List<Object?>? ?? const [])
      : const [];

  @override
  String toString() =>
      model == null ? '$path :: $method' : '$path :: $model.$modelMethod';
}

class _MethodCall {
  const _MethodCall(this.name, this.params);

  final String name;
  final List<Object?> params;
}

class _Fault implements Exception {
  _Fault(this.code, this.message);

  final int code;
  final String message;
}
