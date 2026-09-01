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
    this.quarantinedAt,
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

  /// When the app stopped trying to send this, or null while it is still live.
  ///
  /// ## Why an entry has to be able to leave the queue without being sent
  ///
  /// A write Odoo refuses for a reason retrying cannot fix — the user's ACLs
  /// forbid it, a record rule hides the asset, a constraint rejects the value
  /// — used to stay in the queue for ever. It burned five attempts, went
  /// [isBlocked], and from then on every drain counted it as failed while it
  /// sat there.
  ///
  /// Three things followed from that, and the third is the one that matters:
  ///
  /// 1. The sync banner warned permanently, so it stopped being read.
  /// 2. The queue never reached zero, so "everything is sent" was unreachable.
  /// 3. `OutboxStore.subjectIds` still named the asset, so
  ///    `PendingWriteOverlay` kept rewriting it to the state the failed write
  ///    intended. The detail screen showed a handover that Odoo had rejected
  ///    and would never accept — indefinitely, and with no way to correct it
  ///    short of discarding every other queued write with it.
  ///
  /// Quarantine is the exit. The entry stops being pending — so the banner
  /// clears, the overlay stops rewriting the asset, and the record on screen
  /// goes back to what Odoo actually holds — while the write itself is kept,
  /// named, and shown with its reason so the user can retry it once the
  /// permission is granted, or discard just that one.
  final DateTime? quarantinedAt;

  bool get isQuarantined => quarantinedAt != null;

  /// True once retrying has been tried enough times to stop being useful.
  ///
  /// Distinct from [isQuarantined]: this is a *count*, reached by a write that
  /// keeps failing for a reason that looked retryable each time. Quarantine is
  /// the state it lands in afterwards, and the one a non-retryable rejection
  /// goes to immediately without spending the attempts.
  bool get isBlocked => attempts >= maxAttempts;

  static const int maxAttempts = 5;

  OutboxEntry copyWith({
    int? attempts,
    String? lastError,
    DateTime? quarantinedAt,
    bool clearQuarantine = false,
  }) => OutboxEntry(
    id: id,
    kind: kind,
    subjectId: subjectId,
    subjectName: subjectName,
    payload: payload,
    queuedAt: queuedAt,
    attempts: attempts ?? this.attempts,
    lastError: lastError ?? this.lastError,
    quarantinedAt: clearQuarantine
        ? null
        : (quarantinedAt ?? this.quarantinedAt),
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
    'quarantinedAt': quarantinedAt?.toIso8601String(),
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
      // Absent on rows written before quarantine existed, which read as live —
      // the right default: an upgrade must not silently retire writes the user
      // is still waiting on.
      quarantinedAt: DateTime.tryParse('${json['quarantinedAt']}'),
    );
  }

  @override
  List<Object?> get props => <Object?>[
    id,
    kind,
    subjectId,
    attempts,
    quarantinedAt,
  ];
}
