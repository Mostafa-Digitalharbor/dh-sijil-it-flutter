import 'dart:async';

import '../error/exceptions.dart';
import '../error/failures.dart';
import '../storage/cache/cache_store.dart';
import '../utils/logger.dart';

/// Whether a failure is the network's fault rather than Odoo's.
///
/// The distinction decides everything downstream: a timeout means "show what
/// you have and try again later", while an `AccessError` means "this user may
/// not do this" and must never be papered over with yesterday's copy.
bool isOfflineShaped(Object error) => switch (error) {
  NoInternetException() || ConnectionException() || TimeoutException() => true,
  Failure(kind: FailureKind.noInternet) ||
  Failure(kind: FailureKind.serverUnreachable) ||
  Failure(kind: FailureKind.timeout) => true,
  _ => false,
};

/// A read that answers from the last good copy when the server cannot be
/// reached.
///
/// Odoo stays the source of truth: every successful read overwrites the copy,
/// nothing is merged, and a stale answer is always reported as stale through
/// [SyncTrail] rather than passed off as fresh.
///
/// What is cached is the *raw Odoo record*, not the composed entity. Records
/// are already JSON, so nothing needs a serializer; and the mapper, the status
/// resolver and the local overlay all still run on the way out, which means a
/// cached asset goes through exactly the same composition as a live one.
class OfflineReads {
  OfflineReads({required CacheStore cache, required SyncTrail trail})
    : _cache = cache,
      _trail = trail;

  final CacheStore _cache;
  final SyncTrail _trail;

  /// Runs [live]; on a connectivity failure falls back to the stored copy.
  ///
  /// Rethrows when there is nothing stored — an error screen is the honest
  /// answer for a list the device has never seen, and it is the one case where
  /// "try again" is the only thing the user can usefully do.
  /// [onFresh] runs only on the live path, for a read that can fill more than
  /// its own slot — a page of assets is also the detail of every asset in it.
  Future<T> read<T>({
    required String box,
    required String key,
    required Future<T> Function() live,
    required Object Function(T value) encode,
    required T Function(Object stored) decode,
    Future<void> Function(T value)? onFresh,
  }) async {
    try {
      final fresh = await live();
      await _cache.put(box, key, encode(fresh));
      await onFresh?.call(fresh);
      _trail.servedLive();
      return fresh;
    } on Object catch (error) {
      if (!isOfflineShaped(error)) rethrow;

      final stored = await _cache.get<Object>(box, key);
      if (stored == null) rethrow;

      AppLogger.info('Serving $box/$key from ${stored.storedAt} — offline');
      _trail.servedFromCache(stored.storedAt);
      return decode(stored.value);
    }
  }

  /// Stores a value nothing asked for yet, so a later read finds it.
  Future<void> remember(String box, String key, Object value) =>
      _cache.put(box, key, value);

  /// Drops a cached entry, so the next read has to go to Odoo.
  Future<void> forget(String box, String key) => _cache.delete(box, key);

  /// Drops every cached entry in a box.
  ///
  /// For a write whose blast radius is not a list of keys: a bulk department
  /// move changes which rows the department filter matches, and there is no
  /// way to name the affected pages without re-deriving every cache key that
  /// was ever written.
  Future<void> forgetBox(String box) => _cache.clearBox(box);
}

/// Where the app records how fresh what the user is looking at actually is.
///
/// A single observable rather than a flag threaded through every return type:
/// the banner that says "offline — last updated at 14:12" belongs to the app
/// shell, not to one screen, and every screen's data goes stale at the same
/// moment for the same reason.
class SyncTrail {
  final StreamController<DateTime?> _served =
      StreamController<DateTime?>.broadcast();

  DateTime? _servingFrom;

  /// When the data currently on screen was read from Odoo, or null when it is
  /// live.
  DateTime? get servingFrom => _servingFrom;

  /// Emits on every change of freshness. Null means "live again".
  Stream<DateTime?> get changes => _served.stream;

  void servedLive() => _emit(null);

  void servedFromCache(DateTime storedAt) => _emit(storedAt);

  void _emit(DateTime? at) {
    if (_servingFrom == at) return;
    _servingFrom = at;
    if (!_served.isClosed) _served.add(at);
  }

  Future<void> dispose() => _served.close();
}
