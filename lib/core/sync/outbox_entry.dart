import 'package:equatable/equatable.dart';

/// A write the app made while it could not reach Odoo.
///
/// The payload is deliberately the *request*, not the result: replaying it
/// later runs the same repository method the online path runs, so there is one
/// implementation of "assign an asset" rather than two that have to be kept
/// agreeing.
enum OutboxKind {
  assignAsset,
  returnAsset,
  setAssetStatus;

  static OutboxKind? parse(String? raw) =>
      OutboxKind.values.where((k) => k.name == raw).firstOrNull;
}

/// One queued write, as it sits on disk.
class OutboxEntry extends Equatable {
  const OutboxEntry({
    required this.id,
    required this.kind,
    required this.subjectId,
    required this.subjectName,
    required this.payload,
    required this.queuedAt,
    this.attempts = 0,
    this.lastError,
  });

  /// Sortable and unique without a uuid dependency: the queue is per-device
  /// and a single writer, so the clock plus a counter cannot collide.
  final String id;

  final OutboxKind kind;

  /// The asset this concerns, so a list row can be marked as pending.
  final int subjectId;

  /// Shown in the queue, because "asset 118" is not something a technician
  /// standing in a corridor can act on.
  final String subjectName;

  final Map<String, dynamic> payload;
  final DateTime queuedAt;

  /// How many times a replay has been tried and failed.
  final int attempts;

  /// Why the last replay failed, for the queue screen. Never a stack trace.
  final String? lastError;

  /// True once Odoo has rejected this write for a reason retrying cannot fix.
  ///
  /// A queue that retries a permanently-broken write forever is a queue that
  /// never empties, and a badge that never clears stops meaning anything.
  bool get isBlocked => attempts >= maxAttempts;

  static const int maxAttempts = 5;

  OutboxEntry copyWith({int? attempts, String? lastError}) => OutboxEntry(
    id: id,
    kind: kind,
    subjectId: subjectId,
    subjectName: subjectName,
    payload: payload,
    queuedAt: queuedAt,
    attempts: attempts ?? this.attempts,
    lastError: lastError ?? this.lastError,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'kind': kind.name,
    'subjectId': subjectId,
    'subjectName': subjectName,
    'payload': payload,
    'queuedAt': queuedAt.toIso8601String(),
    'attempts': attempts,
    'lastError': lastError,
  };

  /// Returns null for a row this build cannot understand — an entry written by
  /// a newer version, or one corrupted on disk. Dropping it beats crashing the
  /// queue that every other write is waiting behind.
  static OutboxEntry? fromJson(Map<String, dynamic> json) {
    final kind = OutboxKind.parse(json['kind'] as String?);
    final id = json['id'];
    final subjectId = json['subjectId'];
    final queuedAt = DateTime.tryParse('${json['queuedAt']}');
    if (kind == null ||
        id is! String ||
        subjectId is! int ||
        queuedAt == null) {
      return null;
    }

    return OutboxEntry(
      id: id,
      kind: kind,
      subjectId: subjectId,
      subjectName: '${json['subjectName'] ?? ''}',
      payload: Map<String, dynamic>.from(
        json['payload'] as Map? ?? <String, dynamic>{},
      ),
      queuedAt: queuedAt,
      attempts: json['attempts'] as int? ?? 0,
      lastError: json['lastError'] as String?,
    );
  }

  @override
  List<Object?> get props => <Object?>[id, kind, subjectId, attempts];
}
