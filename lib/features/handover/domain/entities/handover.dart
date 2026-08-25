import 'dart:typed_data';

import 'package:equatable/equatable.dart';

import '../../../assets/domain/entities/asset.dart';
import '../../../employees/domain/entities/employee.dart';

/// Several assets going to one person, at one moment, against one signature.
///
/// ## Why this is not "assign, three times"
///
/// The app could already hand over one asset. A new hire receives a laptop, a
/// monitor, a dock and a phone, and doing that four times means four dates,
/// four notes, and four chances to pick the wrong person from the list —
/// producing four records that describe one event nobody can reconstruct.
///
/// The other half is the signature. An assignment note records that IT *says*
/// it handed something over. A signature records that the recipient agreed,
/// and it is what makes the log worth anything on the day the laptop does not
/// come back. That is why [signature] is not optional here: a bundle without
/// one is just the per-asset assign flow, which still exists for the case
/// where the recipient is not standing there.
class HandoverBundle extends Equatable {
  const HandoverBundle({
    required this.recipient,
    required this.assets,
    required this.handedOverOn,
    required this.signature,
    this.notes,
  });

  final Employee recipient;

  /// In the order they were added, which is the order they are listed in the
  /// note — so the paper trail matches what was on screen when it was signed.
  final List<Asset> assets;

  final DateTime handedOverOn;

  /// The captured signature as PNG bytes, black on white.
  final Uint8List signature;

  final String? notes;

  /// The most assets one handover may carry.
  ///
  /// Not an arbitrary round number: each one is a write plus an attachment
  /// upload in sequence, and a bundle long enough to time out halfway is worse
  /// than two bundles. Twelve is comfortably past the largest real onboarding
  /// kit anyone has described.
  static const int maxAssets = 12;

  /// A short fingerprint of the signature, shown under the pad and written
  /// into the note.
  ///
  /// It lets someone holding a printed receipt and the Odoo record confirm
  /// they are looking at the same signature without opening the image. FNV-1a
  /// rather than a cryptographic digest, and deliberately: this is a visual
  /// cross-reference, not a tamper seal, and claiming otherwise by reaching
  /// for SHA-256 would suggest a guarantee four hex characters cannot make.
  String get signatureFingerprint {
    var hash = 0x811C9DC5;
    for (final byte in signature) {
      hash = ((hash ^ byte) * 0x01000193) & 0xFFFFFFFF;
    }
    final hex = hash.toRadixString(16).toUpperCase().padLeft(8, '0');
    return '${hex.substring(0, 2)}:${hex.substring(2, 4)}';
  }

  @override
  List<Object?> get props => <Object?>[
    recipient.id,
    assets.map((a) => a.id).toList(),
    handedOverOn,
    signature.length,
    notes,
  ];
}

/// What a submitted handover actually did.
///
/// ## Why a receipt and not a bool
///
/// A bundle is several writes, and Odoo can refuse the fourth after accepting
/// the first three — an ACL on one category, a record someone archived while
/// the form was open. Reporting that as "handover failed" would be a lie the
/// user acts on: they would run the whole bundle again and hand over the first
/// three assets twice.
///
/// So the result says exactly what landed and what did not, and the screen
/// offers to retry only [failed].
class HandoverReceipt extends Equatable {
  const HandoverReceipt({
    required this.handedOver,
    required this.failed,
    required this.signedCount,
  });

  /// Assets now recorded against the recipient.
  final List<Asset> handedOver;

  /// Assets Odoo refused. Named, because "3 of 4" is not actionable.
  final List<Asset> failed;

  /// How many of [handedOver] carry the signature image.
  ///
  /// Separate from the count because the assignment is the fact and the
  /// signature is the evidence: an upload that fails leaves a correct record
  /// with weaker proof, which is worth saying and is not worth undoing.
  final int signedCount;

  bool get isComplete => failed.isEmpty && handedOver.isNotEmpty;

  bool get isTotalFailure => handedOver.isEmpty;

  /// True when the assets landed but not all of the proof did.
  bool get isPartiallySigned => handedOver.isNotEmpty && signedCount < handedOver.length;

  @override
  List<Object?> get props => <Object?>[
    handedOver.map((a) => a.id).toList(),
    failed.map((a) => a.id).toList(),
    signedCount,
  ];
}
