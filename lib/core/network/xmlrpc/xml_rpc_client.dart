import 'package:dio/dio.dart';

import '../../constants/app_constants.dart';
import '../../error/exceptions.dart' as app;
import '../../utils/logger.dart';
import 'xml_rpc_codec.dart';

/// Transport-level contract for talking XML-RPC.
///
/// Declared as an interface so tests substitute a fake and so a different
/// transport (JSON-RPC, REST) could be dropped in later without touching a
/// single repository — spec §19 and acceptance criterion 15.
abstract interface class XmlRpcClient {
  /// Invokes [methodName] on [endpoint] with positional [params].
  ///
  /// Throws only [app.AppException] subtypes; never leaks Dio or XML errors.
  Future<Object?> call({
    required Uri endpoint,
    required String methodName,
    required List<Object?> params,
  });
}

/// Dio-backed implementation.
///
/// Deliberately knows nothing about Odoo: no session, no models, no business
/// rules. Odoo semantics live one layer up in `core/network/odoo/`.
class DioXmlRpcClient implements XmlRpcClient {
  DioXmlRpcClient(this._dio);

  final Dio _dio;

  /// Factory for a Dio instance configured for XML-RPC.
  ///
  /// SSL validation is left at Flutter's secure default — spec §25 forbids
  /// disabling certificate checks.
  factory DioXmlRpcClient.createDefault() {
    final dio = Dio(
      BaseOptions(
        connectTimeout: AppConstants.connectTimeout,
        receiveTimeout: AppConstants.receiveTimeout,
        sendTimeout: AppConstants.sendTimeout,
        responseType: ResponseType.plain,
        headers: const {
          'Content-Type': 'text/xml; charset=UTF-8',
          'Accept': 'text/xml',
        },
        // Every status is handled below by hand. Letting Dio decide which
        // ones are exceptional collapses them all into one `badResponse`,
        // and 404 (wrong path), 403 (a proxy in front of Odoo) and 503 (Odoo
        // restarting) need three different sentences told to the user.
        validateStatus: (_) => true,
      ),
    );
    return DioXmlRpcClient(dio);
  }

  @override
  Future<Object?> call({
    required Uri endpoint,
    required String methodName,
    required List<Object?> params,
  }) async {
    final body = XmlRpcCodec.encodeRequest(methodName, params);
    AppLogger.debug('XML-RPC -> ${endpoint.path} :: $methodName');

    try {
      final response = await _dio.postUri<String>(endpoint, data: body);

      _throwForStatus(response.statusCode ?? 0);

      final payload = response.data;
      if (payload == null || payload.isEmpty) {
        throw const app.ResponseParsingException(
          'The server returned an empty response.',
        );
      }

      return await XmlRpcCodec.decode(payload);
    } on XmlRpcFault catch (fault) {
      throw app.OdooFaultException(
        fault.faultString,
        faultCode: fault.faultCode,
        technicalDetails: fault.toString(),
      );
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  /// Turns an HTTP status into the exception that produces the right advice.
  ///
  /// Ordered by what the user has to do about it, not by numeric range.
  static void _throwForStatus(int status) {
    if (status < 400) return;

    // The instance is up and broke while answering. The address is right, so
    // sending the user to the connection screen would be sending them to fix
    // something that is not wrong.
    if (status >= 500) {
      throw app.ServerException(
        'The Odoo server failed while handling the request.',
        statusCode: status,
        technicalDetails: 'HTTP $status',
      );
    }

    // The host answered but has no XML-RPC at that path: a wrong base URL, or
    // a domain that is not the Odoo one.
    if (status == 404) {
      throw const app.ConnectionException(
        'The XML-RPC endpoint was not found on this server.',
        technicalDetails: 'HTTP 404 for the XML-RPC path.',
      );
    }

    // Odoo returns its own auth failures as XML-RPC faults, never as HTTP
    // 401/403. Reaching here means something in front of Odoo — a reverse
    // proxy, a WAF, an SSO gateway — refused the request before Odoo saw it,
    // which the connection screen is where you go to fix.
    throw app.ConnectionException(
      'The server rejected the request.',
      technicalDetails: 'HTTP $status',
    );
  }

  /// Whether the OS refused the request because it was not encrypted.
  static bool _isCleartextBlock(DioException e) {
    final text = '${e.message} ${e.error}'.toLowerCase();
    return text.contains('cleartext') ||
        text.contains('app transport security') ||
        text.contains('nsapptransportsecurity');
  }

  app.AppException _mapDioException(DioException e) {
    return switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => const app.TimeoutException(),
      // Both platforms report a blocked cleartext request as a plain
      // connection error, so the text is the only thing that distinguishes
      // "your server is down" from "this app will never send that URL".
      // Android says CLEARTEXT communication ... not permitted; iOS says the
      // resource load was blocked by App Transport Security.
      DioExceptionType.connectionError when _isCleartextBlock(e) =>
        const app.InsecureConnectionException(),
      DioExceptionType.connectionError => app.ConnectionException(
        'Could not reach the Odoo server.',
        technicalDetails: '${e.message}',
      ),
      DioExceptionType.badCertificate => app.ConnectionException(
        'The server certificate could not be verified.',
        technicalDetails: '${e.message}',
      ),
      // validateStatus lets every status through, so this is reachable only
      // from a Dio path that bypasses it. Classified the same way regardless,
      // so the two routes cannot disagree about what a 503 means.
      DioExceptionType.badResponse when (e.response?.statusCode ?? 0) >= 500 =>
        app.ServerException(
          'The Odoo server failed while handling the request.',
          statusCode: e.response?.statusCode,
          technicalDetails: 'HTTP ${e.response?.statusCode}',
        ),
      DioExceptionType.badResponse => app.ConnectionException(
        'The server returned an unexpected response.',
        technicalDetails: 'HTTP ${e.response?.statusCode}',
      ),
      DioExceptionType.cancel => const app.ConnectionException(
        'The request was cancelled.',
      ),
      _ => app.ConnectionException(
        'Could not reach the Odoo server.',
        technicalDetails: '${e.message}',
      ),
    };
  }
}
