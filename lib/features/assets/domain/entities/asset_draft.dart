import 'package:equatable/equatable.dart';

import 'asset.dart';

/// The editable shape of an asset — what the create/edit form collects.
///
/// Separate from [Asset] on purpose. [Asset] is what Odoo *has*: it carries a
/// resolved status, a computed warranty and an open-request count, none of
/// which a user types. A draft carries only fields a person can fill in, so
/// the form cannot accidentally try to write a derived value back.
class AssetDraft extends Equatable {
  const AssetDraft({
    this.id,
    this.name = '',
    this.serialNumber,
    this.model,
    this.categoryId,
    this.vendorId,
    this.assetTag,
    this.purchaseDate,
    this.purchaseValue,
    this.warrantyEnd,
    this.notes,
  });

  /// Builds a draft from an existing asset, for the edit form.
  factory AssetDraft.from(Asset asset) => AssetDraft(
    id: asset.id,
    name: asset.name,
    serialNumber: asset.serialNumber,
    model: asset.model,
    categoryId: asset.category?.id,
    vendorId: asset.vendor?.id,
    assetTag: asset.assetTag,
    purchaseDate: asset.purchaseDate,
    purchaseValue: asset.purchaseValue,
    warrantyEnd: asset.warranty.endDate,
    notes: asset.notes,
  );

  /// Null for a create, the Odoo id for an edit.
  final int? id;

  final String name;
  final String? serialNumber;
  final String? model;
  final int? categoryId;
  final int? vendorId;
  final String? assetTag;
  final DateTime? purchaseDate;
  final double? purchaseValue;
  final DateTime? warrantyEnd;
  final String? notes;

  bool get isEdit => id != null;

  /// The one field Odoo genuinely requires on every backing model.
  bool get isValid => name.trim().isNotEmpty;

  AssetDraft copyWith({
    String? name,
    String? serialNumber,
    String? model,
    int? categoryId,
    int? vendorId,
    String? assetTag,
    DateTime? purchaseDate,
    double? purchaseValue,
    DateTime? warrantyEnd,
    String? notes,
    bool clearCategory = false,
    bool clearVendor = false,
    bool clearPurchaseDate = false,
    bool clearWarrantyEnd = false,
  }) => AssetDraft(
    id: id,
    name: name ?? this.name,
    serialNumber: serialNumber ?? this.serialNumber,
    model: model ?? this.model,
    categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
    vendorId: clearVendor ? null : (vendorId ?? this.vendorId),
    assetTag: assetTag ?? this.assetTag,
    purchaseDate: clearPurchaseDate
        ? null
        : (purchaseDate ?? this.purchaseDate),
    purchaseValue: purchaseValue ?? this.purchaseValue,
    warrantyEnd: clearWarrantyEnd ? null : (warrantyEnd ?? this.warrantyEnd),
    notes: notes ?? this.notes,
  );

  @override
  List<Object?> get props => [
    id,
    name,
    serialNumber,
    model,
    categoryId,
    vendorId,
    assetTag,
    purchaseDate,
    purchaseValue,
    warrantyEnd,
    notes,
  ];
}
