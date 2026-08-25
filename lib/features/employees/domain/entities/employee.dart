import 'package:equatable/equatable.dart';

import '../../../../core/network/odoo/odoo_object_service.dart';

/// A person who can hold assets, from `hr.employee` (spec §9).
///
/// Optional throughout: an instance without the Employees app has none of
/// these, and every screen that shows one is capability-gated.
class Employee extends Equatable {
  const Employee({
    required this.id,
    required this.name,
    this.department,
    this.job,
    this.jobTitle,
    this.workEmail,
    this.workPhone,
    this.mobilePhone,
    this.assetCount = 0,
  });

  final int id;
  final String name;
  final OdooNameRef? department;
  final OdooNameRef? job;

  /// Free-text title. Odoo populates it from `job_id` but lets it be
  /// overridden, so it is preferred over the related record's name.
  final String? jobTitle;

  final String? workEmail;
  final String? workPhone;
  final String? mobilePhone;

  /// How many assets this person currently holds. Counted separately, so it is
  /// zero on the list screen and populated on the detail screen.
  final int assetCount;

  /// The best available job description, or null when neither is recorded.
  String? get role => jobTitle ?? job?.name;

  /// One phone number to call, preferring the mobile.
  String? get callableNumber => mobilePhone ?? workPhone;

  bool get hasEmail => workEmail != null && workEmail!.isNotEmpty;

  bool get hasPhone => callableNumber != null && callableNumber!.isNotEmpty;

  /// "IT · Systems Engineer" — the list-row subtitle, skipping whichever half
  /// is missing rather than rendering a stray separator.
  String get summary => [
    department?.name,
    role,
  ].where((p) => p != null && p.isNotEmpty).join(' · ');

  Employee copyWith({int? assetCount}) => Employee(
    id: id,
    name: name,
    department: department,
    job: job,
    jobTitle: jobTitle,
    workEmail: workEmail,
    workPhone: workPhone,
    mobilePhone: mobilePhone,
    assetCount: assetCount ?? this.assetCount,
  );

  @override
  List<Object?> get props => [
    id,
    name,
    department,
    job,
    jobTitle,
    workEmail,
    workPhone,
    mobilePhone,
    assetCount,
  ];
}

/// Filters the employee directory supports (spec §9).
class EmployeeFilters extends Equatable {
  const EmployeeFilters({this.query, this.departmentId});

  final String? query;
  final int? departmentId;

  bool get isEmpty =>
      (query == null || query!.trim().isEmpty) && departmentId == null;

  bool get isNotEmpty => !isEmpty;

  EmployeeFilters copyWith({
    String? query,
    int? departmentId,
    bool clearQuery = false,
    bool clearDepartment = false,
  }) => EmployeeFilters(
    query: clearQuery ? null : (query ?? this.query),
    departmentId: clearDepartment ? null : (departmentId ?? this.departmentId),
  );

  @override
  List<Object?> get props => [query, departmentId];
}
