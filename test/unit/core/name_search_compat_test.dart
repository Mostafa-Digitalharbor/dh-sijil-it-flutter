import 'package:flutter_test/flutter_test.dart';
import 'package:sijil_it/app/di/injector.dart';
import 'package:sijil_it/core/constants/odoo_models.dart';
import 'package:sijil_it/core/network/odoo/odoo_object_service.dart';

import '../../fake_odoo/fake_odoo_data.dart';
import '../../fake_odoo/test_app_harness.dart';

/// `name_search` across Odoo generations.
///
/// Odoo 19 renamed this method's parameters: `name_search(name, args,
/// operator, limit)` became `name_search(name, domain, limit)`, and each
/// version faults on the other's keywords. The app must run on 17, 18 and 19
/// (spec §28), so it tries one shape and falls back to the other.
///
/// This was found against a live Odoo 19, where the assignment screen's
/// employee picker returned a fault instead of a list.
void main() {
  late FakeOdooData data;

  setUp(() async {
    data = FakeOdooData.seeded();
    await configureTestDependencies(data: data);
    await signInForTest(data);
  });

  tearDown(() async => sl.reset());

  Future<List<String>> search(String query) async {
    final matches = await sl<OdooObjectService>().nameSearch(
      model: OdooModels.hrEmployee,
      query: query,
    );
    return matches.map((m) => m.name).toList();
  }

  test('works against an Odoo 19 signature', () async {
    data.speaksLegacyNameSearch = false;
    expect(await search('mostafa'), isNotEmpty);
  });

  test('works against an Odoo 17/18 signature', () async {
    data.speaksLegacyNameSearch = true;
    expect(await search('mostafa'), isNotEmpty);
  });

  test('returns the same rows either way', () async {
    data.speaksLegacyNameSearch = false;
    final modern = await search('mostafa');

    await sl.reset();
    data = FakeOdooData.seeded()..speaksLegacyNameSearch = true;
    await configureTestDependencies(data: data);
    await signInForTest(data);
    final legacy = await search('mostafa');

    expect(legacy, modern);
  });

  test('remembers the working shape instead of retrying every call', () async {
    data.speaksLegacyNameSearch = true;

    await search('mostafa');
    final afterFirst = _nameSearchCalls(data);

    await search('ahmed');
    final afterSecond = _nameSearchCalls(data);

    expect(
      afterSecond - afterFirst,
      1,
      reason: 'only the first call may pay for the probe',
    );
  });

  test('an empty query returns the first page rather than nothing', () async {
    expect(await search(''), isNotEmpty);
  });
}

/// How many `name_search` calls the fake has answered, faults included.
int _nameSearchCalls(FakeOdooData data) => data.nameSearchCallCount;
