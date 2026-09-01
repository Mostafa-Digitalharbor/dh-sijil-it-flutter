import 'dart:async';

import 'package:sijil_it/core/error/exceptions.dart' as app;
import 'package:sijil_it/core/network/connectivity/network_info.dart';
import 'package:sijil_it/core/network/xmlrpc/xml_rpc_client.dart';
import 'package:sijil_it/core/security/credential_vault.dart';
import 'package:sijil_it/core/services/voice_input.dart';
import 'package:sijil_it/core/storage/cache/cache_store.dart';

import 'fake_odoo_data.dart';

/// A [VoiceInput] that reports what a host VM actually has: no microphone.
///
/// [available] is settable so a test can put the button on screen and drive
/// it. [speak] plays a transcript back through the callback the button
/// registered, which is the whole contract the UI depends on — everything
/// between a microphone and that callback belongs to the plugin.
class FakeVoiceInput implements VoiceInput {
  FakeVoiceInput({this.available = false, bool? offered}) : _offered = offered;

  /// What initialising the recogniser would answer — and, on a real device,
  /// the call that raises the microphone prompt.
  bool available;

  bool? _offered;

  /// What [canOffer] answers. Defaults to [available] so a test that only
  /// cares whether the button appears does not have to set both.
  ///
  /// Set independently to model the state the real plugin is in before the
  /// user has ever been asked: nothing is known yet, so the button is offered
  /// and the press is what asks.
  bool get offered => _offered ?? available;

  set offered(bool value) => _offered = value;

  /// Whether [listen] should refuse, as it does when the permission prompt is
  /// answered with "Don't allow".
  bool refuseToStart = false;

  String? lastLocaleId;
  int stopCount = 0;

  /// How often each question was asked.
  ///
  /// [isAvailableCount] is the one that matters: it counts the calls that
  /// prompt on a real device, and a build that increments it is the bug this
  /// double exists to catch.
  int canOfferCount = 0;
  int isAvailableCount = 0;

  void Function(VoiceResult)? _onResult;

  @override
  bool get isListening => _onResult != null;

  @override
  Future<bool> canOffer() async {
    canOfferCount++;
    return offered;
  }

  @override
  Future<bool> isAvailable() async {
    isAvailableCount++;
    return available;
  }

  @override
  Future<bool> listen({
    required void Function(VoiceResult result) onResult,
    required String localeId,
  }) async {
    lastLocaleId = localeId;
    // Through [isAvailable], as the real one does: `PlatformVoiceInput.listen`
    // initialises the recogniser first, and that is the call which raises the
    // microphone prompt. Short-circuiting on `available` here would have made
    // the double unable to show *where* the prompt happens, which is the only
    // interesting thing about it.
    if (!await isAvailable() || refuseToStart) return false;
    _onResult = onResult;
    return true;
  }

  @override
  Future<void> stop() async {
    stopCount++;
    _onResult = null;
  }

  /// Feeds a transcript back, the way the recogniser does.
  void speak(String text, {bool isFinal = true}) {
    _onResult?.call(VoiceResult(text: text, isFinal: isFinal));
    if (isFinal) _onResult = null;
  }
}

/// In-memory [CredentialVault] with the same contract as the real one.
///
/// Extends rather than implements so the production constructor signature is
/// still honoured; every method that would touch the OS keystore is replaced.
class InMemoryVault implements CredentialVault {
  String? _secret;
  String? _hiveKey;

  /// Reads performed, so a test can prove the secret is fetched per call and
  /// never cached in a field.
  int readCount = 0;

  @override
  Future<void> writeSecret(String secret, Object mode) async {
    _secret = secret;
  }

  @override
  Future<String?> readSecret() async {
    readCount++;
    return _secret;
  }

  @override
  Future<bool> hasSecret() async => _secret != null && _secret!.isNotEmpty;

  @override
  Future<void> clearSecret() async => _secret = null;

  @override
  Future<String?> readHiveKey() async => _hiveKey;

  @override
  Future<void> writeHiveKey(String base64Key) async => _hiveKey = base64Key;

  @override
  Future<void> wipe() async {
    _secret = null;
    _hiveKey = null;
  }
}

/// In-memory [CacheStore]. Same TTL semantics, no Hive, no disk.
class InMemoryCache implements CacheStore {
  final Map<String, Map<String, CacheEntry<Object?>>> _boxes = {};

  @override
  Future<void> put<T>(String box, String key, T value) async {
    (_boxes[box] ??= {})[key] = CacheEntry<Object?>(
      value: value,
      storedAt: DateTime.now(),
    );
  }

  @override
  Future<CacheEntry<T>?> get<T>(String box, String key) async {
    final entry = _boxes[box]?[key];
    if (entry == null) return null;
    final value = entry.value;
    if (value is! T) return null;
    return CacheEntry<T>(value: value, storedAt: entry.storedAt);
  }

  @override
  Future<void> delete(String box, String key) async {
    _boxes[box]?.remove(key);
  }

  @override
  Future<void> clearBox(String box) async => _boxes.remove(box);

  @override
  Future<void> clearAll() async => _boxes.clear();

  @override
  Future<List<String>> keys(String box) async =>
      _boxes[box]?.keys.toList() ?? const [];
}

/// Connectivity that a test controls directly.
class FakeNetworkInfo implements NetworkInfo {
  FakeNetworkInfo({bool connected = true}) : _connected = connected;

  bool _connected;

  final StreamController<bool> _changes = StreamController<bool>.broadcast();

  bool get connected => _connected;

  /// Setting this emits, so a test can walk the device out of a server room
  /// and watch the queue drain by itself. A plain field could only ever be
  /// read, which made the reconnect path — the whole point of the outbox —
  /// untestable.
  set connected(bool value) {
    if (_connected == value) return;
    _connected = value;
    _changes.add(value);
  }

  @override
  Future<bool> get isConnected async => _connected;

  @override
  Stream<bool> get onConnectivityChanged => _changes.stream;

  Future<void> dispose() => _changes.close();
}

/// An [XmlRpcClient] that answers from [FakeOdooData] without a socket.
///
/// `TestWidgetsFlutterBinding` stubs `HttpClient` so every request returns 400
/// — real network is impossible in a widget test, by design. The transport is
/// an interface for exactly this reason: widget tests swap it here and still
/// exercise the real services, repositories and Cubits above it, while
/// `test/integration/odoo_api_test.dart` proves the wire format over an actual
/// socket in a plain Dart test.
class InProcessOdooClient implements XmlRpcClient {
  InProcessOdooClient(this.data);

  final FakeOdooData data;

  /// Every call made, for asserting on what the app asked Odoo for.
  final List<({String path, String method, List<Object?> params})> calls = [];

  /// Faults keyed by `model.method`, or by the bare method for `/common`.
  final Map<String, ({int code, String message})> faults = {};

  /// Makes every call fail as if the host were unreachable.
  bool unreachable = false;

  /// Artificial latency.
  ///
  /// The in-process client answers within one microtask, which is faster than
  /// any real network and fast enough that a loading state can come and go
  /// between two frames. A test that wants to *see* the skeleton sets this.
  Duration delay = Duration.zero;

  @override
  Future<Object?> call({
    required Uri endpoint,
    required String methodName,
    required List<Object?> params,
  }) async {
    calls.add((path: endpoint.path, method: methodName, params: params));

    if (delay > Duration.zero) await Future<void>.delayed(delay);

    if (unreachable) {
      throw const app.ConnectionException(
        'Could not reach the Odoo server.',
        technicalDetails: 'InProcessOdooClient.unreachable',
      );
    }

    void maybeFault(String key) {
      final fault = faults[key];
      if (fault != null) {
        throw app.OdooFaultException(
          fault.message,
          faultCode: fault.code,
          technicalDetails: fault.message,
        );
      }
    }

    try {
      if (endpoint.path.endsWith('/common')) {
        maybeFault(methodName);
        return _common(methodName, params);
      }
      if (endpoint.path.endsWith('/db')) {
        maybeFault(methodName);
        if (!data.allowDatabaseListing) {
          throw const app.OdooFaultException(
            'AccessDenied: database listing is disabled',
            faultCode: 1,
          );
        }
        return data.databases;
      }

      final database = params[0] as String;
      final model = params[3] as String;
      final method = params[4] as String;

      if (database != data.database) {
        throw app.OdooFaultException(
          'FATAL: database "$database" does not exist',
          faultCode: 1,
        );
      }
      maybeFault('$model.$method');
      maybeFault(method);

      return data.execute(
        model: model,
        method: method,
        args: (params[5] as List<Object?>?) ?? const [],
        kwargs: params.length > 6
            ? (params[6] as Map<String, dynamic>? ?? const {})
            : const {},
      );
    } on FakeOdooFault catch (fault) {
      throw app.OdooFaultException(
        fault.message,
        faultCode: fault.code,
        technicalDetails: fault.message,
      );
    }
  }

  Object? _common(String methodName, List<Object?> params) {
    switch (methodName) {
      case 'version':
        return <String, dynamic>{
          'server_version': data.serverVersion,
          'server_serie': data.serverVersion,
          'protocol_version': 1,
        };
      case 'authenticate':
        final database = params[0] as String;
        final login = params[1] as String;
        final secret = params[2] as String;
        if (database != data.database) {
          throw app.OdooFaultException(
            'FATAL: database "$database" does not exist',
            faultCode: 1,
          );
        }
        // Odoo answers false rather than faulting on a bad credential.
        return (login == data.login && secret == data.secret)
            ? data.userId
            : false;
      default:
        throw app.OdooFaultException(
          'Unknown common method: $methodName',
          faultCode: 1,
        );
    }
  }
}
