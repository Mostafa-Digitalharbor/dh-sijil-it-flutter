import 'package:equatable/equatable.dart';

import '../../../assets/domain/entities/asset_status.dart';

/// Everything the assignment workflow records (spec §7).
///
/// Carries [employeeName] alongside the id so the chatter note and the success
/// message can name the person without a second round trip — the picker
/// already had the name on screen when the user chose.
class AssignmentRequest extends Equatable {
  const AssignmentRequest({
    required this.assetId,
    required this.employeeId,
    required this.employeeName,
    required this.assignedOn,
    this.notes,
  });

  final int assetId;
  final int employeeId;
  final String employeeName;
  final DateTime assignedOn;
  final String? notes;

  @override
  List<Object?> get props => [
    assetId,
    employeeId,
    employeeName,
    assignedOn,
    notes,
  ];
}

/// Everything the return workflow records (spec §8).
class ReturnRequest extends Equatable {
  const ReturnRequest({
    required this.assetId,
    required this.condition,
    required this.returnedOn,
    this.employeeName,
    this.notes,
    this.photoPaths = const <String>[],
  });

  final int assetId;
  final ReturnCondition condition;
  final DateTime returnedOn;

  /// Who is handing it back, for the chatter note. Null when the asset's
  /// holder could not be resolved.
  final String? employeeName;

  final String? notes;

  /// Local file paths chosen by the user; uploaded as `ir.attachment`
  /// records against the asset.
  final List<String> photoPaths;

  /// Where the asset lands once this return is confirmed.
  AssetStatus get resultingStatus => condition.resultingStatus;

  /// Whether to offer opening a maintenance request afterwards.
  bool get suggestsMaintenance => condition.suggestsMaintenanceRequest;

  /// The most photos a single return may carry.
  ///
  /// A cap rather than an unbounded list: each photo becomes a base64
  /// `ir.attachment` in one XML-RPC payload, and an unbounded set is how a
  /// return times out on a slow connection.
  static const int maxPhotos = 5;

  @override
  List<Object?> get props => [
    assetId,
    condition,
    returnedOn,
    employeeName,
    notes,
    photoPaths,
  ];
}
