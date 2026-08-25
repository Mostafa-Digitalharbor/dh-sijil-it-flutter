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
        validateStatus: (status) => status != null && status < 500,
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

      final status = response.statusCode ?? 0;
      if (status == 404) {
        throw const app.ConnectionException(
          'The XML-RPC endpoint was not found on this server.',
          technicalDetails: 'HTTP 404 for the XML-RPC path.',
        );
      }
      if (status >= 400) {
        throw app.ConnectionException(
          'The server rejected the request.',
          technicalDetails: 'HTTP $status',
        );
      }

      final payload = response.data;
      if (payload == null || payload.isEmpty) {
        throw const app.ResponseParsingException(
          'The server returned an empty response.',
        );
      }

      return XmlRpcCodec.decodeResponse(payload);
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

  app.AppException _mapDioException(DioException e) {
    return switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => const app.TimeoutException(),
      DioExceptionType.connectionError => app.ConnectionException(
        'Could not reach the Odoo server.',
        technicalDetails: '${e.message}',
      ),
      DioExceptionType.badCertificate => app.ConnectionException(
        'The server certificate could not be verified.',
        technicalDetails: '${e.message}',
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
