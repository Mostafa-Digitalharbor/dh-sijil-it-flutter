import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sijil_it/core/error/failures.dart';
import 'package:sijil_it/core/utils/typedefs.dart';
import 'package:sijil_it/features/assets/domain/entities/asset_history.dart';
import 'package:sijil_it/features/assets/domain/repositories/asset_repository.dart';
import 'package:sijil_it/features/assets/domain/usecases/asset_usecases.dart';
import 'package:sijil_it/features/assets/presentation/cubit/asset_history_cubit.dart';

/// Paging an asset's service life.
///
/// The timeline used to read one page of sixty chatter entries and stop. Not
/// "sixty of two hundred" — just an end, on the one screen a technician opens
/// to answer "who had this before". A device reassigned and repaired for a few
/// years has more than that, and none of it was reachable.
void main() {
  AssetHistoryEntry entry(int id) => AssetHistoryEntry(
    id: id,
    kind: AssetEventKind.assigned,
    summary: 'entry $id',
    occurredAt: DateTime(2026, 1, 1),
  );

  AssetHistory page({
    required int from,
    required int count,
    required bool hasMore,
    DateTime? registeredOn,
  }) => AssetHistory(
    entries: <AssetHistoryEntry>[
      for (var i = 0; i < count; i++) entry(from + i),
    ],
    registeredOn: registeredOn,
    hasMore: hasMore,
  );

  test('a full first page reports there is more', () async {
    final repo = _FakeRepo(
      pages: <int, AssetHistory>{0: page(from: 0, count: 60, hasMore: true)},
    );
    final cubit = AssetHistoryCubit(GetAssetHistory(repo));

    await cubit.load(1);

    expect(cubit.state.data!.hasMore, isTrue);
    expect(cubit.state.data!.entries, hasLength(60));
  });

  test('loadMore appends the older page and keeps the creation date', () async {
    final registered = DateTime(2020, 3, 4);
    final repo = _FakeRepo(
      pages: <int, AssetHistory>{
        0: page(from: 0, count: 60, hasMore: true, registeredOn: registered),
        60: page(from: 60, count: 12, hasMore: false),
      },
    );
    final cubit = AssetHistoryCubit(GetAssetHistory(repo));

    await cubit.load(1);
    await cubit.loadMore();

    final history = cubit.state.data!;
    expect(history.entries, hasLength(72));
    // Newest first, and the older page went on the end rather than the front.
    expect(history.entries.first.id, 0);
    expect(history.entries.last.id, 71);
    // The creation date closes the timeline and only the first page carries
    // it, so a merge that dropped it would lose the end of the story.
    expect(history.registeredOn, registered);
    expect(history.hasMore, isFalse);
    expect(repo.offsetsRequested, <int>[0, 60]);
  });

  test('the second page is asked for at the right offset', () async {
    final repo = _FakeRepo(
      pages: <int, AssetHistory>{
        0: page(from: 0, count: 60, hasMore: true),
        60: page(from: 60, count: 60, hasMore: true),
        120: page(from: 120, count: 3, hasMore: false),
      },
    );
    final cubit = AssetHistoryCubit(GetAssetHistory(repo));

    await cubit.load(1);
    await cubit.loadMore();
    await cubit.loadMore();

    expect(repo.offsetsRequested, <int>[0, 60, 120]);
    expect(cubit.state.data!.entries, hasLength(123));
  });

  test('loadMore does nothing once the end is reached', () async {
    final repo = _FakeRepo(
      pages: <int, AssetHistory>{0: page(from: 0, count: 4, hasMore: false)},
    );
    final cubit = AssetHistoryCubit(GetAssetHistory(repo));

    await cubit.load(1);
    await cubit.loadMore();

    expect(repo.offsetsRequested, <int>[0], reason: 'no second request');
  });

  test('a failed page keeps what is on screen and stops asking', () async {
    // The user is reading a timeline. Replacing it with an error page because
    // the *tail* could not be fetched throws away the part that arrived fine.
    final repo = _FakeRepo(
      pages: <int, AssetHistory>{0: page(from: 0, count: 60, hasMore: true)},
      failOffsets: <int>{60},
    );
    final cubit = AssetHistoryCubit(GetAssetHistory(repo));

    await cubit.load(1);
    await cubit.loadMore();

    expect(cubit.state.data!.entries, hasLength(60));
    expect(cubit.state.hasFailed, isFalse);

    // And it must not immediately ask again: the footer rebuilds, and a server
    // refusing that offset would otherwise be retried in a tight loop.
    expect(cubit.state.data!.hasMore, isFalse);
    await cubit.loadMore();
    expect(repo.offsetsRequested, <int>[0, 60]);
  });

  test('a reload starts from the first page again', () async {
    final repo = _FakeRepo(
      pages: <int, AssetHistory>{
        0: page(from: 0, count: 60, hasMore: true),
        60: page(from: 60, count: 5, hasMore: false),
      },
    );
    final cubit = AssetHistoryCubit(GetAssetHistory(repo));

    await cubit.load(1);
    await cubit.loadMore();
    await cubit.load(1, refresh: true);

    expect(cubit.state.data!.entries, hasLength(60));
    expect(repo.offsetsRequested, <int>[0, 60, 0]);
  });
}

class _FakeRepo implements AssetRepository {
  _FakeRepo({required this.pages, this.failOffsets = const <int>{}});

  final Map<int, AssetHistory> pages;
  final Set<int> failOffsets;
  final List<int> offsetsRequested = <int>[];

  @override
  ResultFuture<AssetHistory> history(int id, {int offset = 0}) async {
    offsetsRequested.add(offset);
    if (failOffsets.contains(offset)) {
      return const Left<Failure, AssetHistory>(
        Failure(kind: FailureKind.timeout),
      );
    }
    return Right<Failure, AssetHistory>(pages[offset] ?? const AssetHistory());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not used here');
}
