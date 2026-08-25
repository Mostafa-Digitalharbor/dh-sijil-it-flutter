import 'package:equatable/equatable.dart';

/// A cached value together with the moment it was written.
class CacheEntry<T> extends Equatable {
  const CacheEntry({required this.value, required this.storedAt});

  final T value;
  final DateTime storedAt;

  bool isFresh(Duration ttl) => DateTime.now().difference(storedAt) < ttl;

  bool isStale(Duration ttl) => !isFresh(ttl);

  @override
  List<Object?> get props => [value, storedAt];
}

/// Key/value cache contract.
///
/// Declared as an interface so the Hive implementation can be swapped for
/// Isar or SQLite (spec §24) without touching a repository. Odoo remains the
/// source of truth; everything here is disposable.
abstract interface class CacheStore {
  Future<void> put<T>(String box, String key, T value);

  /// Returns the entry with its timestamp so the caller can apply its own TTL.
  Future<CacheEntry<T>?> get<T>(String box, String key);

  Future<void> delete(String box, String key);

  Future<void> clearBox(String box);

  /// Wipes every box. Backs Settings → Clear cache (spec §23).
  Future<void> clearAll();

  Future<List<String>> keys(String box);
}
