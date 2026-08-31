import 'package:sijil_it/core/constants/odoo_models.dart';

/// An in-memory Odoo database.
///
/// Implements just enough of the ORM for the app's nine required operations,
/// with the same quirks the real thing has: `false` for an empty relational
/// field, `[id, "Name"]` pairs for many2ones, `ilike` that is case-insensitive
/// and unanchored, and `search_read` that honours limit/offset/order. Those
/// quirks are the whole reason this exists — a mock that returns tidy data
/// would not catch the bugs the real server does.
class FakeOdooData {
  FakeOdooData({
    required this.serverVersion,
    required this.database,
    required this.login,
    required this.secret,
    required this.userId,
    required this.installedModels,
    required Map<String, List<Map<String, dynamic>>> records,
    this.allowDatabaseListing = false,
    this.databases = const ['company-production'],
    Set<String>? deniedOperations,
    Map<String, Set<String>>? requiredFields,
  }) : _records = records,
       deniedOperations = deniedOperations ?? <String>{},
       requiredFields = requiredFields ?? _defaultRequiredFields();

  final String serverVersion;
  final String database;
  final String login;
  final String secret;
  final int userId;

  /// Which models `ir.model` reports. Drop one to simulate an Odoo without
  /// the Maintenance or Employees app.
  final Set<String> installedModels;

  final bool allowDatabaseListing;
  final List<String> databases;

  /// `model.operation` pairs that raise `AccessError`, for ACL testing.
  ///
  /// Mutable so a test can tighten the ACLs after `seeded()` has built the
  /// instance — the alternative is threading a denial list through every
  /// factory just to hide one button.
  final Set<String> deniedOperations;

  /// Whether this instance uses the pre-19 `name_search(name, args, operator)`
  /// signature. Odoo 19 renamed those parameters to `name, domain`.
  bool speaksLegacyNameSearch = false;

  /// How many `name_search` calls have been answered, faults included.
  ///
  /// Lets a test prove the client memoises which signature worked instead of
  /// paying for the probe on every keystroke of a typeahead.
  int nameSearchCallCount = 0;

  /// Fields each model marks `required`, keyed by model.
  ///
  /// Mirrors stock Odoo, which really does mark
  /// `maintenance.equipment.effective_date` mandatory — and really does reject
  /// a create that sends `false` for it, because that overrides the default
  /// the constraint relies on.
  final Map<String, Set<String>> requiredFields;

  static Map<String, Set<String>> _defaultRequiredFields() =>
      <String, Set<String>>{
        OdooModels.maintenanceEquipment: <String>{'name', 'effective_date'},
        OdooModels.hrEmployee: <String>{'name'},
        OdooModels.maintenanceRequest: <String>{'name'},
      };

  final Map<String, List<Map<String, dynamic>>> _records;

  int _nextId = 9000;

  List<Map<String, dynamic>> tableOf(String model) =>
      _records[model] ??= <Map<String, dynamic>>[];

  /// A representative instance: Odoo 18, Maintenance + HR installed, a handful
  /// of assets across every status the app can show.
  factory FakeOdooData.seeded() {
    return FakeOdooData(
      serverVersion: '18.0',
      database: 'company-production',
      login: 'admin@company.com',
      secret: 'test-api-key',
      userId: 2,
      installedModels: {
        OdooModels.irModel,
        OdooModels.irModelFields,
        OdooModels.resUsers,
        OdooModels.resPartner,
        OdooModels.resCompany,
        OdooModels.hrEmployee,
        OdooModels.hrDepartment,
        OdooModels.hrJob,
        OdooModels.maintenanceEquipment,
        OdooModels.maintenanceRequest,
        OdooModels.maintenanceEquipmentCategory,
        OdooModels.mailMessage,
        OdooModels.mailTrackingValue,
        OdooModels.irAttachment,
      },
      records: {
        OdooModels.resUsers: [
          {
            'id': 2,
            'name': 'Mostafa Bader',
            'login': 'admin@company.com',
            'email': 'mostafa.bader@company.com',
            'company_id': [1, 'Digital Harbor'],
            'partner_id': [3, 'Mostafa Bader'],
            'lang': 'en_US',
            'tz': 'Africa/Cairo',
          },
        ],
        OdooModels.hrDepartment: [
          {'id': 1, 'name': 'IT'},
          {'id': 2, 'name': 'Development'},
          {'id': 3, 'name': 'Finance'},
        ],
        OdooModels.hrEmployee: [
          {
            'id': 11,
            'name': 'Mostafa Bader',
            'department_id': [1, 'IT'],
            'job_id': [1, 'Senior Flutter Engineer'],
            'job_title': 'Senior Flutter Engineer',
            'work_email': 'mostafa.bader@company.com',
            'work_phone': '+20 100 000 0001',
            'mobile_phone': false,
            'company_id': [1, 'Digital Harbor'],
          },
          {
            'id': 12,
            'name': 'Ahmed Mohamed',
            'department_id': [1, 'IT'],
            'job_id': [2, 'Systems Engineer'],
            'job_title': 'Systems Engineer',
            'work_email': 'ahmed.mohamed@company.com',
            'work_phone': false,
            'mobile_phone': false,
            'company_id': [1, 'Digital Harbor'],
          },
          {
            'id': 13,
            'name': 'Sara Fouad',
            'department_id': [2, 'Development'],
            'job_id': [3, 'Backend Engineer'],
            'job_title': 'Backend Engineer',
            'work_email': 'sara.fouad@company.com',
            'work_phone': false,
            'mobile_phone': false,
            'company_id': [1, 'Digital Harbor'],
          },
        ],
        OdooModels.maintenanceEquipmentCategory: [
          {'id': 1, 'name': 'Laptop'},
          {'id': 2, 'name': 'Monitor'},
          {'id': 3, 'name': 'Mobile'},
          {'id': 4, 'name': 'Printer'},
        ],
        OdooModels.maintenanceEquipment: [
          _equipment(
            id: 101,
            name: 'MacBook Pro M4',
            serial: 'C02XK1YZQ6L4',
            model: 'MacBook Pro 14',
            category: [1, 'Laptop'],
            employee: [12, 'Ahmed Mohamed'],
            department: [1, 'IT'],
            assignDate: '2026-08-23',
            warranty: '2026-10-05',
            cost: 128400.0,
            partner: [7, 'Apple Egypt'],
            openRequests: 0,
          ),
          _equipment(
            id: 102,
            name: 'Dell UltraSharp U2723QE',
            serial: 'CN0P2H1L',
            model: 'U2723QE',
            category: [2, 'Monitor'],
            employee: [12, 'Ahmed Mohamed'],
            department: [1, 'IT'],
            assignDate: '2025-10-15',
            warranty: '2026-09-13',
            cost: 19800.0,
            partner: [8, 'Dell Egypt'],
            openRequests: 0,
          ),
          _equipment(
            id: 103,
            name: 'iPhone 15 Pro',
            serial: 'F2LX90ABCD',
            model: 'A3102',
            category: [3, 'Mobile'],
            employee: [11, 'Mostafa Bader'],
            department: [1, 'IT'],
            assignDate: '2026-03-02',
            warranty: '2027-03-01',
            cost: 62000.0,
            partner: [7, 'Apple Egypt'],
            openRequests: 1,
          ),
          _equipment(
            id: 104,
            name: 'ThinkPad X1 Carbon G12',
            serial: 'PF3ABCDE',
            model: '21KC',
            category: [1, 'Laptop'],
            employee: false,
            department: false,
            assignDate: false,
            warranty: '2028-01-20',
            cost: 84000.0,
            partner: [9, 'Lenovo MEA'],
            openRequests: 0,
          ),
          _equipment(
            id: 105,
            name: 'HP LaserJet Pro M404',
            serial: 'VNC4H12345',
            model: 'M404dn',
            category: [4, 'Printer'],
            employee: false,
            department: false,
            assignDate: false,
            warranty: '2024-06-01',
            cost: 14500.0,
            partner: [10, 'HP Egypt'],
            openRequests: 0,
            scrapDate: '2026-05-11',
          ),
        ],
        // The half of an asset's history this app did not write.
        //
        // `ir.model.fields` is what turns a tracking row's label into a
        // technical name, which is the only thing that can tell a handover
        // made in the web client from any other field edit — "Used By" is
        // "مستخدم بواسطة" on the same instance in another language.
        OdooModels.irModelFields: [
          {
            'id': 4101,
            'name': EquipmentFields.employeeId,
            'field_description': 'Used By',
          },
          {
            'id': 4102,
            'name': EquipmentFields.departmentId,
            'field_description': 'Department',
          },
        ],
        // Odoo 17+ shape: `field_id`, and no separate `field_desc` column.
        // Seeded this way on purpose — the app reads whichever of the two
        // names the instance exposes, and a fake that offered both would let
        // a regression in that fallback pass unnoticed.
        OdooModels.mailTrackingValue: [
          _tracking(
            id: 7001,
            messageId: 6001,
            field: [4101, 'Used By'],
            newChar: 'Ahmed Mohamed',
          ),
        ],
        OdooModels.mailMessage: [
          // A field change made in the Odoo web client: `message_type` is
          // `notification`, the body is empty, and everything the entry says
          // lives in the tracking rows. This is the message the app used to
          // read, find blank, and drop — so a handover done in Odoo left no
          // mark on the history screen at all.
          {
            'id': 6001,
            'body': false,
            'subject': false,
            'date': '2025-10-15 08:12:00',
            'author_id': [2, 'Mostafa Bader'],
            'model': OdooModels.maintenanceEquipment,
            'res_id': 102,
            'message_type': 'notification',
            'tracking_value_ids': [7001],
          },
        ],
        OdooModels.maintenanceRequest: [
          {
            'id': 501,
            'name': 'Screen replacement',
            'equipment_id': [103, 'iPhone 15 Pro'],
            'category_id': [3, 'Mobile'],
            'request_date': '2026-08-20',
            'schedule_date': '2026-08-27 09:00:00',
            'close_date': false,
            'stage_id': [2, 'In Progress'],
            'maintenance_type': 'corrective',
            'priority': '2',
            'description': 'Cracked screen, digitizer intermittent.',
            'user_id': [2, 'Karim Hassan'],
            'duration': 2.0,
          },
        ],

        // Photographs. The strip and the viewer had no fixture at all before
        // this, so the whole attachment path — list, download, delete — was
        // only ever exercised against hand-written doubles.
        //
        // `datas` holds a real 1x1 PNG, base64 as Odoo stores it, so a
        // download decodes rather than merely returning bytes. The third row
        // is a PDF: `list` filters on mimetype server-side, and a quote
        // attached to a repair must not put a broken tile in the strip.
        OdooModels.irAttachment: [
          {
            'id': 9001,
            'name': 'front-damage.png',
            'res_model': OdooModels.maintenanceRequest,
            'res_id': 501,
            'mimetype': 'image/png',
            'file_size': 2400000,
            'datas': onePixelPng,
          },
          {
            'id': 9002,
            'name': 'serial-plate.png',
            'res_model': OdooModels.maintenanceRequest,
            'res_id': 501,
            'mimetype': 'image/png',
            'file_size': 1800000,
            'datas': onePixelPng,
          },
          {
            'id': 9003,
            'name': 'repair-quote.pdf',
            'res_model': OdooModels.maintenanceRequest,
            'res_id': 501,
            'mimetype': 'application/pdf',
            'file_size': 90000,
            'datas': onePixelPng,
          },
          {
            'id': 9004,
            'name': 'asset-photo.png',
            'res_model': OdooModels.maintenanceEquipment,
            'res_id': 101,
            'mimetype': 'image/png',
            'file_size': 3100000,
            'datas': onePixelPng,
          },
        ],
      },
    );
  }

  /// A 1x1 PNG, base64-encoded the way `ir.attachment.datas` holds one.
  ///
  /// Real image bytes rather than a placeholder string: a download that only
  /// returned *something* would pass a test while handing the decoder
  /// nonsense, which is exactly the failure mode the photo strip's
  /// `errorBuilder` exists for.
  static const String onePixelPng =
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8'
      'z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

  /// Builds one `mail.tracking.value` row with Odoo's own column shapes.
  ///
  /// Every typed column is present and empty, because that is what Odoo sends:
  /// a char change still returns `old_value_integer: 0`, and code that reads
  /// the first *non-empty* pair has to survive that. A fake that omitted the
  /// unused columns would be testing a payload nobody receives.
  static Map<String, dynamic> _tracking({
    required int id,
    required int messageId,
    required List<Object?> field,
    Object oldChar = false,
    Object newChar = false,
  }) => {
    'id': id,
    'mail_message_id': [messageId, 'Message $messageId'],
    'field_id': field,
    'old_value_char': oldChar,
    'new_value_char': newChar,
    'old_value_text': false,
    'new_value_text': false,
    'old_value_integer': 0,
    'new_value_integer': 0,
    'old_value_float': 0.0,
    'new_value_float': 0.0,
    'old_value_monetary': 0.0,
    'new_value_monetary': 0.0,
    'old_value_datetime': false,
    'new_value_datetime': false,
  };

  /// Builds one `maintenance.equipment` record with Odoo's own field shapes.
  static Map<String, dynamic> _equipment({
    required int id,
    required String name,
    required String serial,
    required String model,
    required Object category,
    required Object employee,
    required Object department,
    required Object assignDate,
    required Object warranty,
    required double cost,
    required Object partner,
    required int openRequests,
    Object scrapDate = false,
  }) => {
    'id': id,
    'name': name,
    'serial_no': serial,
    'model': model,
    'category_id': category,
    'partner_id': partner,
    'employee_id': employee,
    'department_id': department,
    'equipment_assign_to': employee == false ? 'other' : 'employee',
    'assign_date': assignDate,
    'effective_date': '2023-10-05',
    'cost': cost,
    'warranty_date': warranty,
    'scrap_date': scrapDate,
    'note': false,
    'owner_user_id': [2, 'Mostafa Bader'],
    'maintenance_open_count': openRequests,
    'company_id': [1, 'Digital Harbor'],
    'active': true,
    'write_date': '2026-08-23 09:14:02',
    'create_date': '2023-10-05 11:02:41',
  };

  // ── ORM ──────────────────────────────────────────────────────────────────

  Object? execute({
    required String model,
    required String method,
    required List<Object?> args,
    required Map<String, dynamic> kwargs,
  }) {
    if (deniedOperations.contains('$model.$method')) {
      throw FakeOdooFault(
        3,
        'odoo.exceptions.AccessError: Sorry, you are not allowed to '
        '$method this kind of document ($model).',
      );
    }

    // `ir.model` is how the app decides what exists (spec §17), so it is
    // answered from installedModels rather than from a table.
    if (model == OdooModels.irModel) {
      return _executeIrModel(method, args, kwargs);
    }

    if (!installedModels.contains(model)) {
      throw FakeOdooFault(1, "KeyError: 'Object $model doesn't exist'");
    }

    return switch (method) {
      'search_read' => _searchRead(model, args, kwargs),
      'search' => _search(model, args, kwargs).map((r) => r['id']).toList(),
      'search_count' => _search(model, args, kwargs).length,
      'read' => _read(model, args, kwargs),
      'fields_get' => _fieldsGet(model),
      'name_search' => _nameSearch(model, kwargs),
      'create' => _create(model, args),
      'write' => _write(model, args),
      'unlink' => _unlink(model, args),
      'check_access_rights' => !deniedOperations.contains(
        '$model.${args.isEmpty ? 'read' : args.first}',
      ),
      'read_group' => _readGroup(model, args),
      'message_post' => _messagePost(model, args, kwargs),
      _ => throw FakeOdooFault(1, 'Unsupported method $model.$method'),
    };
  }

  /// `read_group`, in the one shape the app asks for: count by a single
  /// many2one field.
  ///
  /// Returns Odoo 17+'s `__count` key. The app also accepts the older
  /// `<field>_count` shape, but a fake that emits both would let a regression
  /// in that fallback pass unnoticed.
  List<Map<String, dynamic>> _readGroup(String model, List<Object?> args) {
    final domain = args.isEmpty ? const <Object?>[] : args[0]! as List<Object?>;
    final groupBy = args.length > 2
        ? (args[2]! as List<Object?>).first as String
        : (args[1]! as List<Object?>).first as String;

    final counts = <String, ({Object? value, int count})>{};

    for (final row in tableOf(model).where((r) => _matches(r, domain))) {
      final raw = row[groupBy];
      // Odoo omits the "not set" group from a many2one read_group.
      if (raw == false || raw == null) continue;
      final key = raw is List ? '${raw.first}' : '$raw';
      counts[key] = (value: raw, count: (counts[key]?.count ?? 0) + 1);
    }

    return counts.values
        .map(
          (entry) => <String, dynamic>{
            groupBy: entry.value,
            '__count': entry.count,
          },
        )
        .toList();
  }

  /// `message_post`, recorded rather than modelled.
  ///
  /// The app writes chatter notes for every assignment, return and local
  /// status change, and a test needs to prove the note was written and what it
  /// said — so the body lands in `mail.message` where the dashboard's activity
  /// feed will read it back.
  int _messagePost(
    String model,
    List<Object?> args,
    Map<String, dynamic> kwargs,
  ) {
    final ids = args.isEmpty ? const <Object?>[] : args.first! as List<Object?>;
    final rows = tableOf(OdooModels.mailMessage);
    final id = ++_nextId;

    rows.add(<String, dynamic>{
      'id': id,
      'body': kwargs['body'] ?? false,
      'subject': false,
      'date': '2026-08-24 10:00:00',
      'author_id': [userId, login],
      'model': model,
      'res_id': ids.isEmpty ? false : ids.first,
      'message_type': 'comment',
      // Odoo sends an empty x2m as `[]`, not `false`. Present on every row
      // because `fields_get` here is derived from one, and a key missing from
      // the sample would read as a field this instance does not have.
      'tracking_value_ids': <Object?>[],
    });

    return id;
  }

  Object? _executeIrModel(
    String method,
    List<Object?> args,
    Map<String, dynamic> kwargs,
  ) {
    final rows = installedModels
        .map((name) => <String, dynamic>{'id': name.hashCode, 'model': name})
        .toList();

    final domain = args.isEmpty
        ? const <Object?>[]
        : args.first as List<Object?>;
    final matched = rows.where((row) => _matches(row, domain)).toList();

    return switch (method) {
      'search_count' => matched.length,
      'search' => matched.map((r) => r['id']).toList(),
      'search_read' => matched,
      'fields_get' => <String, dynamic>{
        'id': {'type': 'integer', 'string': 'ID'},
        'model': {'type': 'char', 'string': 'Model'},
      },
      _ => throw FakeOdooFault(1, 'Unsupported ir.model method $method'),
    };
  }

  List<Map<String, dynamic>> _search(
    String model,
    List<Object?> args,
    Map<String, dynamic> kwargs,
  ) {
    final domain = args.isEmpty
        ? const <Object?>[]
        : (args.first as List<Object?>? ?? const []);

    var rows = tableOf(model).where((row) => _matches(row, domain)).toList();

    final order = kwargs['order'] as String?;
    if (order != null && order.trim().isNotEmpty) {
      final parts = order.split(' ');
      final field = parts.first;
      final descending = parts.length > 1 && parts[1].toLowerCase() == 'desc';
      rows.sort((a, b) {
        final left = _comparable(a[field]);
        final right = _comparable(b[field]);
        // Postgres' default collation orders case-insensitively, so "iPhone"
        // sorts between "Dell" and "MacBook" rather than after both the way a
        // raw ASCII compare would put it.
        final result = (left is String && right is String)
            ? left.toLowerCase().compareTo(right.toLowerCase())
            : left.compareTo(right);
        return descending ? -result : result;
      });
    }

    final offset = kwargs['offset'] as int? ?? 0;
    if (offset > 0) {
      rows = offset >= rows.length ? [] : rows.sublist(offset);
    }

    final limit = kwargs['limit'] as int?;
    if (limit != null && limit > 0 && rows.length > limit) {
      rows = rows.sublist(0, limit);
    }

    return rows;
  }

  List<Map<String, dynamic>> _searchRead(
    String model,
    List<Object?> args,
    Map<String, dynamic> kwargs,
  ) {
    final fields = (kwargs['fields'] as List<Object?>?)
        ?.map((f) => '$f')
        .toList();
    return _search(
      model,
      args,
      kwargs,
    ).map((row) => _project(model, row, fields)).toList();
  }

  List<Map<String, dynamic>> _read(
    String model,
    List<Object?> args,
    Map<String, dynamic> kwargs,
  ) {
    final ids = (args.isEmpty ? const <Object?>[] : args.first as List<Object?>)
        .whereType<int>()
        .toSet();
    final fields = (kwargs['fields'] as List<Object?>?)
        ?.map((f) => '$f')
        .toList();

    final rows = tableOf(model).where((r) => ids.contains(r['id'])).toList();

    // Real Odoo raises MissingError when an id no longer exists.
    if (rows.length != ids.length) {
      final missing = ids.where((id) => !rows.any((r) => r['id'] == id));
      if (missing.isNotEmpty) {
        throw FakeOdooFault(
          2,
          'odoo.exceptions.MissingError: Record does not exist or has been '
          'deleted. ($model: ${missing.join(', ')})',
        );
      }
    }

    return rows.map((row) => _project(model, row, fields)).toList();
  }

  Map<String, dynamic> _fieldsGet(String model) {
    final sample = tableOf(model).firstOrNull ?? const <String, dynamic>{};
    return {
      for (final key in sample.keys)
        key: <String, dynamic>{
          'string': key,
          'type': _typeOf(sample[key]),
          'required': requiredFields[model]?.contains(key) ?? false,
          'readonly': false,
        },
    };
  }

  /// `name_search`, in whichever signature this fake is pretending to speak.
  ///
  /// Odoo renamed the parameters in 19 — `args`/`operator` became `domain` —
  /// and each version faults on the other's keywords. Modelling that is the
  /// only way to prove the client's fallback actually works, rather than
  /// quietly ignoring a domain it did not recognise.
  List<Object?> _nameSearch(String model, Map<String, dynamic> kwargs) {
    nameSearchCallCount++;

    if (speaksLegacyNameSearch) {
      if (kwargs.containsKey('domain')) {
        throw FakeOdooFault(
          1,
          "TypeError: name_search() got an unexpected keyword argument 'domain'",
        );
      }
    } else if (kwargs.containsKey('args') || kwargs.containsKey('operator')) {
      throw FakeOdooFault(
        1,
        "TypeError: name_search() got an unexpected keyword argument 'args'",
      );
    }

    final query = '${kwargs['name'] ?? ''}'.toLowerCase();
    final limit = kwargs['limit'] as int? ?? 20;
    final domain =
        ((speaksLegacyNameSearch ? kwargs['args'] : kwargs['domain'])
            as List<Object?>?) ??
        const <Object?>[];

    return tableOf(model)
        .where((row) => _matches(row, domain))
        .where(
          (row) =>
              query.isEmpty ||
              '${row['name'] ?? ''}'.toLowerCase().contains(query),
        )
        .take(limit)
        .map((row) => <Object?>[row['id'], '${row['name']}'])
        .toList();
  }

  int _create(String model, List<Object?> args) {
    final values = Map<String, dynamic>.from(args.first as Map);
    _rejectClearedRequiredFields(model, values);

    final id = ++_nextId;
    tableOf(model).add({'id': id, ..._resolveRelations(values)});
    return id;
  }

  /// Turns a written many2one id into the `[id, "Display name"]` pair Odoo
  /// returns when the record is read back.
  ///
  /// A write sends `{'employee_id': 11}`; a read returns
  /// `{'employee_id': [11, 'Mostafa Bader']}`. Storing the bare int made every
  /// read-after-write look like an empty relation to the app's mapper — so an
  /// asset assigned a moment ago still read "Unassigned", and the test that
  /// should have caught it passed because it inspected the raw row instead of
  /// what the app could parse.
  Map<String, dynamic> _resolveRelations(Map<String, dynamic> values) {
    const relations = <String, String>{
      'employee_id': OdooModels.hrEmployee,
      'department_id': OdooModels.hrDepartment,
      'job_id': OdooModels.hrJob,
      'category_id': OdooModels.maintenanceEquipmentCategory,
      'partner_id': OdooModels.resPartner,
      'equipment_id': OdooModels.maintenanceEquipment,
      'stage_id': OdooModels.maintenanceStage,
      'user_id': OdooModels.resUsers,
      'owner_user_id': OdooModels.resUsers,
      'company_id': OdooModels.resCompany,
    };

    final resolved = Map<String, dynamic>.from(values);

    for (final entry in relations.entries) {
      final value = resolved[entry.key];
      if (value is! int) continue;

      final target = _records[entry.value]
          ?.where((row) => row['id'] == value)
          .firstOrNull;

      resolved[entry.key] = <Object?>[value, '${target?['name'] ?? value}'];
    }

    return resolved;
  }

  /// Reproduces Odoo's mandatory-field constraint.
  ///
  /// A key that is simply *absent* is fine — Odoo applies its default. A key
  /// present with `false` is not: it overrides that default and leaves the
  /// field empty, which the constraint then rejects. Getting this distinction
  /// right is the whole point of modelling it here, because it is exactly the
  /// mistake the mapper used to make.
  void _rejectClearedRequiredFields(String model, Map<String, dynamic> values) {
    final required = requiredFields[model] ?? const <String>{};

    for (final field in required) {
      if (!values.containsKey(field)) continue;
      final value = values[field];
      if (value == false || value == null || value == '') {
        throw FakeOdooFault(
          2,
          'The operation cannot be completed: Missing required value for '
          "the field '$field' ($field). Model: '$model'",
        );
      }
    }
  }

  bool _write(String model, List<Object?> args) {
    final ids = (args.first as List<Object?>).whereType<int>().toSet();
    final values = Map<String, dynamic>.from(args[1] as Map);
    _rejectClearedRequiredFields(model, values);

    final resolved = _resolveRelations(values);
    for (final row in tableOf(model)) {
      if (ids.contains(row['id'])) row.addAll(resolved);
    }
    return true;
  }

  bool _unlink(String model, List<Object?> args) {
    final ids = (args.first as List<Object?>).whereType<int>().toSet();
    tableOf(model).removeWhere((row) => ids.contains(row['id']));
    return true;
  }

  /// Returns only the requested fields, always including `id` — exactly what
  /// Odoo does.
  Map<String, dynamic> _project(
    String model,
    Map<String, dynamic> row,
    List<String>? fields,
  ) {
    if (fields == null || fields.isEmpty) return Map<String, dynamic>.from(row);

    final projected = <String, dynamic>{'id': row['id']};
    for (final field in fields) {
      if (field == 'id') continue;
      if (!row.containsKey(field)) {
        throw FakeOdooFault(
          1,
          'ValueError: Invalid field $model.$field in leaf',
        );
      }
      projected[field] = row[field];
    }
    return projected;
  }

  /// Evaluates an Odoo domain in prefix notation.
  ///
  /// Supports the operators the app's `OdooDomainBuilder` can emit, including
  /// the `|` / `&` / `!` markers — which is what makes the domain builder's
  /// output verifiable rather than merely plausible.
  /// Evaluates an Odoo domain against one row.
  ///
  /// Odoo domains are prefix notation: `['|', a, b, c]` means `(a OR b) AND c`,
  /// because operators bind exactly their own operands and whatever is left at
  /// the top level is implicitly AND-ed.
  ///
  /// That "exactly their own operands" is the whole subtlety. An earlier
  /// version of this evaluator let a leaf greedily absorb every following leaf
  /// as an implicit AND, which is right at the top level and wrong inside an
  /// operator — `['|','|',a,b,c,d]` collapsed to `(a AND b AND c AND d) OR
  /// true`, so every row matched and the search bar looked like it worked while
  /// filtering nothing.
  static bool _matches(Map<String, dynamic> row, List<Object?> domain) {
    if (domain.isEmpty) return true;

    final tokens = List<Object?>.from(domain);
    var index = 0;
    var result = true;

    while (index < tokens.length) {
      final (value, next) = _evaluate(row, tokens, index);
      result = result && value;
      // Defensive: a malformed domain must not spin here.
      if (next <= index) break;
      index = next;
    }

    return result;
  }

  /// Parses exactly one expression — a leaf, or an operator and its operands —
  /// and returns it with the index just past it.
  static (bool, int) _evaluate(
    Map<String, dynamic> row,
    List<Object?> tokens,
    int index,
  ) {
    if (index >= tokens.length) return (true, index);

    final token = tokens[index];

    if (token == '|' || token == '&') {
      final (left, next) = _evaluate(row, tokens, index + 1);
      final (right, after) = _evaluate(row, tokens, next);
      return (token == '|' ? left || right : left && right, after);
    }
    if (token == '!') {
      final (value, next) = _evaluate(row, tokens, index + 1);
      return (!value, next);
    }

    return (_leaf(row, token! as List<Object?>), index + 1);
  }

  static bool _leaf(Map<String, dynamic> row, List<Object?> leaf) {
    final field = '${leaf[0]}';
    final operator = '${leaf[1]}';
    final expected = leaf[2];
    final actual = row[field];

    // Odoo compares a many2one leaf against its id, not the [id, name] pair.
    final normalised = actual is List && actual.isNotEmpty
        ? actual.first
        : actual;

    return switch (operator) {
      '=' => normalised == expected,
      '!=' => normalised != expected,
      'in' => (expected as List<Object?>).contains(normalised),
      'not in' => !(expected as List<Object?>).contains(normalised),
      '>' => _comparable(normalised).compareTo(_comparable(expected)) > 0,
      '>=' => _comparable(normalised).compareTo(_comparable(expected)) >= 0,
      '<' => _comparable(normalised).compareTo(_comparable(expected)) < 0,
      '<=' => _comparable(normalised).compareTo(_comparable(expected)) <= 0,
      'ilike' => _like(actual, expected, caseSensitive: false),
      'not ilike' => !_like(actual, expected, caseSensitive: false),
      'like' => _like(actual, expected),
      'not like' => !_like(actual, expected),
      _ => throw FakeOdooFault(1, 'Unsupported domain operator: $operator'),
    };
  }

  /// Odoo's `like`, including its SQL wildcards.
  ///
  /// This used to be a plain `contains`, which is right for the *unanchored*
  /// pattern Odoo's typeahead sends and wrong for every anchored one. The app
  /// filters the photo strip with `mimetype like 'image/%'`, and against a
  /// substring match `'image/png'.contains('image/%')` is false — so the fake
  /// returned no photos at all, and the one filter standing between a repair's
  /// PDF quote and a broken tile in the strip had never been exercised.
  ///
  /// `%` matches any run, `_` matches one character, and a pattern with
  /// neither is treated as `%pattern%`, which is what Odoo does.
  static bool _like(
    Object? actual,
    Object? expected, {
    bool caseSensitive = true,
  }) {
    final subject = '$actual';
    final pattern = '$expected';

    if (!pattern.contains('%') && !pattern.contains('_')) {
      return caseSensitive
          ? subject.contains(pattern)
          : subject.toLowerCase().contains(pattern.toLowerCase());
    }

    final regex = StringBuffer('^');
    for (final char in pattern.split('')) {
      regex.write(switch (char) {
        '%' => '.*',
        '_' => '.',
        _ => RegExp.escape(char),
      });
    }
    regex.write(r'$');

    return RegExp(
      regex.toString(),
      caseSensitive: caseSensitive,
    ).hasMatch(subject);
  }

  static Comparable<Object> _comparable(Object? value) {
    if (value is Comparable<Object>) return value;
    if (value is List &&
        value.isNotEmpty &&
        value.first is Comparable<Object>) {
      return value.first as Comparable<Object>;
    }
    if (value == false || value == null) return '';
    return '$value';
  }

  static String _typeOf(Object? value) => switch (value) {
    int() => 'integer',
    double() => 'float',
    bool() => 'boolean',
    List() => 'many2one',
    _ => 'char',
  };
}

/// Raised by the in-memory ORM; the server encodes it as an XML-RPC fault.
class FakeOdooFault implements Exception {
  FakeOdooFault(this.code, this.message);

  final int code;
  final String message;

  @override
  String toString() => 'FakeOdooFault($code): $message';
}
