/// Names of **standard** Odoo models and fields used by the app.
///
/// Spec §2: no custom addon is ever required. Every identifier below ships
/// with stock Odoo 17/18/19. Optional models are resolved at runtime through
/// `OdooCapabilityService` before use, so a missing app degrades the feature
/// instead of crashing the UI.
///
/// Never hardcode Odoo **record IDs** (spec §10) — resolve them with
/// `name_search`, or by external identifier through `ir.model.data`.
abstract final class OdooModels {
  // -- Metadata / introspection (always present) ---------------------------
  static const String irModel = 'ir.model';
  static const String irModelFields = 'ir.model.fields';
  static const String irAttachment = 'ir.attachment';

  // -- Users & partners (always present) -----------------------------------
  static const String resUsers = 'res.users';
  static const String resPartner = 'res.partner';
  static const String resCompany = 'res.company';

  // -- HR (optional, the `hr` app) -----------------------------------------
  static const String hrEmployee = 'hr.employee';
  static const String hrDepartment = 'hr.department';
  static const String hrJob = 'hr.job';

  // -- Maintenance (optional, the `maintenance` app) -----------------------
  /// Primary backing model for an IT asset when Maintenance is installed.
  static const String maintenanceEquipment = 'maintenance.equipment';
  static const String maintenanceRequest = 'maintenance.request';
  static const String maintenanceEquipmentCategory =
      'maintenance.equipment.category';
  static const String maintenanceStage = 'maintenance.stage';

  // -- Inventory (optional, fallback asset source) -------------------------
  static const String productProduct = 'product.product';

  /// Serial/lot model. Renamed from `stock.production.lot` in Odoo 16, so the
  /// capability service resolves whichever one exists.
  static const String stockLot = 'stock.lot';
  static const String stockProductionLotLegacy = 'stock.production.lot';

  // -- Mail / activity (optional, drives the activity timeline) ------------
  static const String mailMessage = 'mail.message';

  /// The rows Odoo writes when a *tracked field* changes.
  ///
  /// A `mail.message` posted by the web client for a field edit carries no
  /// body at all — Odoo renders the sentence in the browser from these rows.
  /// Reading only `mail.message` therefore showed an asset's whole life as
  /// seen from this app and nothing anybody did in Odoo itself.
  static const String mailTrackingValue = 'mail.tracking.value';

  /// Models the app can run without. Each is capability-checked at startup.
  static const List<String> optional = <String>[
    hrEmployee,
    hrDepartment,
    hrJob,
    maintenanceEquipment,
    maintenanceRequest,
    maintenanceEquipmentCategory,
    productProduct,
    stockLot,
    mailMessage,
  ];

  const OdooModels._();
}

/// Field names on `maintenance.equipment`, the preferred asset source.
abstract final class EquipmentFields {
  static const String name = 'name';
  static const String serialNo = 'serial_no';
  static const String model = 'model';
  static const String categoryId = 'category_id';
  static const String partnerId = 'partner_id'; // vendor
  static const String partnerRef = 'partner_ref';
  static const String employeeId = 'employee_id';
  static const String departmentId = 'department_id';
  static const String assignTo = 'equipment_assign_to';
  static const String assignDate = 'assign_date';
  static const String effectiveDate = 'effective_date';
  static const String cost = 'cost';
  static const String warrantyDate = 'warranty_date';
  static const String scrapDate = 'scrap_date';
  static const String note = 'note';
  static const String ownerUserId = 'owner_user_id';
  static const String maintenanceOpenCount = 'maintenance_open_count';
  static const String active = 'active';
  static const String companyId = 'company_id';
  static const String writeDate = 'write_date';
  static const String createDate = 'create_date';

  /// Fields we would like to read. The repository intersects this list with
  /// what `fields_get` actually reports before issuing the query, so an older
  /// or trimmed Odoo never produces an "invalid field" fault.
  static const List<String> readSet = <String>[
    'id',
    name,
    serialNo,
    model,
    categoryId,
    partnerId,
    employeeId,
    departmentId,
    assignTo,
    assignDate,
    effectiveDate,
    cost,
    warrantyDate,
    scrapDate,
    note,
    ownerUserId,
    maintenanceOpenCount,
    companyId,
    writeDate,
    createDate,
  ];

  const EquipmentFields._();
}

/// Field names on `hr.employee`.
abstract final class EmployeeFields {
  static const String name = 'name';
  static const String departmentId = 'department_id';
  static const String jobId = 'job_id';
  static const String jobTitle = 'job_title';
  static const String workEmail = 'work_email';
  static const String workPhone = 'work_phone';
  static const String mobilePhone = 'mobile_phone';
  static const String userId = 'user_id';
  static const String companyId = 'company_id';
  static const String active = 'active';

  static const List<String> readSet = <String>[
    'id',
    name,
    departmentId,
    jobId,
    jobTitle,
    workEmail,
    workPhone,
    mobilePhone,
    companyId,
  ];

  const EmployeeFields._();
}

/// Field names on `maintenance.request`.
abstract final class MaintenanceRequestFields {
  static const String name = 'name';
  static const String equipmentId = 'equipment_id';
  static const String categoryId = 'category_id';
  static const String requestDate = 'request_date';
  static const String scheduleDate = 'schedule_date';
  static const String closeDate = 'close_date';
  static const String stageId = 'stage_id';
  static const String maintenanceType = 'maintenance_type';
  static const String priority = 'priority';
  static const String description = 'description';
  static const String employeeId = 'employee_id';
  static const String ownerUserId = 'owner_user_id';
  static const String userId = 'user_id'; // assigned technician
  static const String duration = 'duration';
  static const String done = 'done';
  static const String archive = 'archive';

  static const List<String> readSet = <String>[
    'id',
    name,
    equipmentId,
    categoryId,
    requestDate,
    scheduleDate,
    closeDate,
    stageId,
    maintenanceType,
    priority,
    description,
    userId,
    duration,
  ];

  const MaintenanceRequestFields._();
}

/// Field names on `res.users`, used for the logged-in profile.
abstract final class UserFields {
  static const String name = 'name';
  static const String login = 'login';
  static const String email = 'email';
  static const String companyId = 'company_id';
  static const String partnerId = 'partner_id';
  static const String lang = 'lang';
  static const String tz = 'tz';

  /// The user's photo, base64. `res.users` inherits it from `res.partner`, so
  /// it is there on every instance — unlike `hr.employee.image_128`, which
  /// needs the HR app installed and the user linked to an employee record.
  static const String image = 'image_128';

  static const List<String> readSet = <String>[
    'id',
    name,
    login,
    email,
    companyId,
    partnerId,
    image,
    lang,
    tz,
  ];

  const UserFields._();
}

/// Field names on `hr.department` and the category models.
///
/// Both are simple named records; keeping one catalog for them avoids three
/// near-identical classes whose only field is `name`.
abstract final class NamedRecordFields {
  static const String name = 'name';
  static const String active = 'active';

  static const List<String> readSet = <String>['id', name];

  const NamedRecordFields._();
}

/// Field names on `mail.message`, which backs the activity timeline.
abstract final class MailMessageFields {
  static const String id = 'id';
  static const String body = 'body';
  static const String subject = 'subject';
  static const String date = 'date';
  static const String authorId = 'author_id';
  static const String model = 'model';
  static const String resId = 'res_id';
  static const String messageType = 'message_type';

  /// The tracked-field changes attached to this message, if any.
  ///
  /// Read through `supportedFields` like every other set, because it is the
  /// one field here an instance can genuinely lack: `mail.message` has carried
  /// it for many versions, but a trimmed model or a restricted read would
  /// otherwise turn the whole history screen into an "invalid field" fault.
  static const String trackingValueIds = 'tracking_value_ids';

  /// The two `message_type` values that carry something a person wrote or that
  /// the system announced. The rest are field-tracking rows Odoo renders from
  /// tracking values the app does not read, so they arrive with an empty body.
  static const String typeComment = 'comment';
  static const String typeNotification = 'notification';

  static const List<String> readSet = <String>[
    'id',
    body,
    subject,
    date,
    authorId,
    model,
    resId,
    messageType,
    trackingValueIds,
  ];

  /// The `message_post` keyword arguments the app uses when writing a note.
  static const String argBody = 'body';
  static const String argSubtype = 'subtype_xmlid';

  /// Internal note rather than a customer-facing message: chatter notes the
  /// app writes are operational records, not correspondence.
  static const String subtypeNote = 'mail.mt_note';

  const MailMessageFields._();
}

/// Field names on `mail.tracking.value` — what a tracked field changed from
/// and to.
///
/// ## Why every name here is optional
///
/// This model is the one the app touches whose schema Odoo actually reshuffled
/// between supported versions. Up to 16 the link to the field was `field`
/// plus a `field_desc` label; 17 renamed it to `field_id` and dropped the
/// separate label, because `ir.model.fields` already renders as its
/// translated description. Naming both and letting `supportedFields` decide is
/// what keeps one build working across 17, 18 and 19 (spec §28) — and would
/// have kept it working on 16.
///
/// The value columns are typed rather than generic: Odoo stores an integer
/// change in `old_value_integer` and a text one in `old_value_char`, and the
/// only way to know which is populated is to read them all and take the one
/// that is.
abstract final class MailTrackingValueFields {
  static const String id = 'id';
  static const String messageId = 'mail_message_id';

  /// Odoo 17+.
  static const String fieldId = 'field_id';

  /// Odoo ≤16.
  static const String fieldLegacy = 'field';

  /// Odoo ≤16 — the translated label, which 17+ reads off [fieldId] instead.
  static const String fieldDescription = 'field_desc';

  static const String oldChar = 'old_value_char';
  static const String newChar = 'new_value_char';
  static const String oldText = 'old_value_text';
  static const String newText = 'new_value_text';
  static const String oldInteger = 'old_value_integer';
  static const String newInteger = 'new_value_integer';
  static const String oldFloat = 'old_value_float';
  static const String newFloat = 'new_value_float';
  static const String oldMonetary = 'old_value_monetary';
  static const String newMonetary = 'new_value_monetary';
  static const String oldDatetime = 'old_value_datetime';
  static const String newDatetime = 'new_value_datetime';

  /// Narrowed by `supportedFields` before it is sent.
  static const List<String> readSet = <String>[
    id,
    messageId,
    fieldId,
    fieldLegacy,
    fieldDescription,
    oldChar,
    newChar,
    oldText,
    newText,
    oldInteger,
    newInteger,
    oldFloat,
    newFloat,
    oldMonetary,
    newMonetary,
    oldDatetime,
    newDatetime,
  ];

  /// The value columns, oldest-typed first, paired old→new.
  ///
  /// Order matters only in that the first populated pair wins; a tracking row
  /// populates exactly one of them, so any order is correct and this one reads
  /// in the order a person would guess.
  static const List<(String, String)> valuePairs = <(String, String)>[
    (oldChar, newChar),
    (oldText, newText),
    (oldDatetime, newDatetime),
    (oldMonetary, newMonetary),
    (oldFloat, newFloat),
    (oldInteger, newInteger),
  ];

  const MailTrackingValueFields._();
}

/// Field names on `ir.model.fields`, read to recover a tracked field's
/// *technical* name.
///
/// The label is what a person reads; the technical name is what the app can
/// reason about. "Used By" and "مستخدم بواسطة" are the same field, and only
/// `employee_id` says so — which is what lets a change made in the web client
/// be classified as a handover rather than as an anonymous edit.
abstract final class ModelFieldFields {
  static const String id = 'id';
  static const String name = 'name';
  static const String description = 'field_description';

  static const List<String> readSet = <String>[id, name, description];

  const ModelFieldFields._();
}

/// Field names on `ir.attachment`, used for return photos (spec §8).
abstract final class AttachmentFields {
  static const String id = 'id';
  static const String name = 'name';
  static const String datas = 'datas';
  static const String resModel = 'res_model';
  static const String resId = 'res_id';
  static const String mimetype = 'mimetype';
  static const String fileSize = 'file_size';

  /// Everything a photo strip needs *except* the bytes. `datas` is fetched one
  /// attachment at a time, because a record with six photos is several
  /// megabytes of base64 and a list that only wants a count would pull it all.
  static const List<String> listSet = <String>[name, mimetype, fileSize];

  const AttachmentFields._();
}

/// Odoo method names the app calls beyond the CRUD verbs.
abstract final class OdooMethods {
  // ── ORM reads ────────────────────────────────────────────────────────────
  static const String searchRead = 'search_read';
  static const String search = 'search';
  static const String searchCount = 'search_count';
  static const String read = 'read';
  static const String readGroup = 'read_group';
  static const String nameSearch = 'name_search';
  static const String fieldsGet = 'fields_get';

  // ── ORM writes ───────────────────────────────────────────────────────────
  static const String create = 'create';
  static const String write = 'write';
  static const String unlink = 'unlink';

  // ── Chatter & ACLs ───────────────────────────────────────────────────────
  static const String messagePost = 'message_post';

  /// Renamed to `check_access` in Odoo 18; the transport tries the legacy name
  /// and treats a missing method as "permitted", so the app degrades to Odoo's
  /// own ACL error rather than hiding a control the user actually has.
  static const String checkAccessRights = 'check_access_rights';

  const OdooMethods._();
}

/// The optional customer-provided status field (docs/ARCHITECTURE.md §6).
///
/// When an instance already has a real IT-asset status field, Odoo becomes the
/// single source of truth and the local overlay is bypassed entirely. The name
/// is a convention rather than a requirement: `AssetStatusResolver` probes for
/// it with `fieldExists` and carries on without it.
abstract final class AssetStatusField {
  static const String name = 'x_sijil_status';

  const AssetStatusField._();
}
