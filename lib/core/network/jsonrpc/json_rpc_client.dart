import 'package:dio/dio.dart';

import '../../constants/app_constants.dart';
import '../../error/exceptions.dart' as app;
import '../../utils/logger.dart';

/// Transport-level contract for Odoo's JSON endpoints.
///
/// ## Why a second transport exists at all
///
/// Everything the app *does* is XML-RPC, and that is deliberate: it is the
/// interface Odoo documents for external clients and the one that works
/// identically on-premise and hosted. This client exists for exactly one call
/// that XML-RPC cannot make on a hosted instance — listing the databases on
/// the server, so a user does not have to know their database's name.
///
/// On Odoo Online the `/xmlrpc/2/db` service is disabled outright and answers
/// `AccessDenied` to `list`, while the web client's own `/web/database/list`
/// answers it fine — that is how the browser fills the database dropdown on
/// the login page. The app asked only the first and therefore told every
/// odoo.com customer "this server does not publish its databases", which was
/// false and left them typing a generated name of the shape
/// `<account>-<project>-live-<digits>` that is written down nowhere they look.
///
/// Kept behind an interface for the same reason [XmlRpcClient] is: the fake
/// server in the tests substitutes it, and no repository knows either exists.
abstract interface class JsonRpcClient {
  /// Invokes [method] on [endpoint] with named [params].
  ///
  /// Named `invoke` rather than `call` so one object can implement both this
  /// and [XmlRpcClient] — the fake server in the tests does, because a real
  /// Odoo is one host answering on both routes, and two fakes would let them
  /// drift apart.
  ///
  /// Throws only [app.AppException] subtypes; never leaks Dio or JSON errors.
  Future<Object?> invoke({
    required Uri endpoint,
    required String method,
    Map<String, Object?> params,
  });
}

/// Dio-backed implementation.
class DioJsonRpcClient implements JsonRpcClient {
  DioJsonRpcClient(this._dio);

  /// Configured exactly like the XML-RPC transport, including leaving SSL
  /// validation at Flutter's secure default (spec §25).
  factory DioJsonRpcClient.createDefault() => DioJsonRpcClient(
    Dio(
      BaseOptions(
        connectTimeout: AppConstants.connectTimeout,
        receiveTimeout: AppConstants.receiveTimeout,
        sendTimeout: AppConstants.sendTimeout,
        responseType: ResponseType.json,
        headers: const <String, String>{
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        validateStatus: (_) => true,
      ),
    ),
  );

  final Dio _dio;

  @override
  Future<Object?> invoke({
    required Uri endpoint,
    required String method,
    Map<String, Object?> params = const <String, Object?>{},
  }) async {
    AppLogger.debug('JSON-RPC -> ${endpoint.path} :: $method');

    try {
      final response = await _dio.postUri<Object?>(
        endpoint,
        data: <String, Object?>{
          'jsonrpc': _version,
          'method': 'call',
          'params': params,
        },
      );

      final status = response.statusCode ?? 0;
      if (status >= _statusBadRequest) {
        throw app.ServerException(
          'The server rejected the request.',
          statusCode: status,
          technicalDetails: 'HTTP $status from ${endpoint.path}',
        );
      }

      final payload = response.data;
      if (payload is! Map) {
        throw const app.ResponseParsingException(
          'The server returned an unexpected response.',
          technicalDetails: 'JSON-RPC body was not an object.',
        );
      }

      // A JSON-RPC error is a 200 with an `error` member, not a status code —
      // so a caller that only checked the status would read a refusal as a
      // successful empty answer.
      final Object? error = payload['error'];
      if (error != null) {
        throw app.OdooFaultException(
          _messageOf(error),
          technicalDetails: '$error',
        );
      }

      return payload['result'];
    } on DioException catch (e) {
      throw app.ConnectionException(
        'Could not reach the server.',
        technicalDetails: e.message,
      );
    }
  }

  /// The sentence out of a JSON-RPC error object, falling back to the whole
  /// thing when it is not shaped the way Odoo shapes it.
  static String _messageOf(Object error) {
    if (error is! Map) return '$error';
    final data = error['data'];
    if (data is Map && data['message'] != null) return '${data['message']}';
    return '${error['message'] ?? error}';
  }

  static const String _version = '2.0';
  static const int _statusBadRequest = 400;
}
