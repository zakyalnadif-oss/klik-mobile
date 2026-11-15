import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:klik_mobile/core/routes/app_router.dart';
import 'package:klik_mobile/data/models/local_record.dart';
import 'package:klik_mobile/data/models/ranked_match.dart';
import 'package:klik_mobile/data/providers/local_state.dart';
import 'package:klik_mobile/data/repositories/local_repository.dart';
import 'package:klik_mobile/features/tanding/logic/match_rules.dart';
import 'package:klik_mobile/features/events/logic/activity_rules.dart';

import 'app_test.dart' show MemoryRepository, app;

void main() {
  final now = DateTime(2030, 1, 1, 12);
  Map<String, dynamic> record({
    String mode = 'Berperingkat',
    String kind = 'room',
    String actor = 'captain-a',
    bool owned = false,
  }) {
    final data = MemoryRepository().record;
    final row = data['activities'][0] as Map;
    row['startsAt'] = now.subtract(const Duration(hours: 3)).toIso8601String();
    row['mode'] = mode;
    row['kind'] = kind;
    row['durationMinutes'] = 120;
    row['owned'] = owned;
    data['playerId'] = actor;
    data['joined'] = ['test-room'];
    data['rankedMatches'] = {
      'test-room': const RankedMatch(
        teamA: MatchTeam(
          id: 'team-a',
          name: 'Tim A',
          captainId: 'captain-a',
          captainName: 'Ketua A',
        ),
        teamB: MatchTeam(
          id: 'team-b',
          name: 'Tim B',
          captainId: 'captain-b',
          captainName: 'Ketua B',
        ),
      ).toJson(),
    };
    return data;
  }

  test('both team captains may submit even when neither owns the room', () {
    for (final actor in ['captain-a', 'captain-b']) {
      final data = record(actor: actor);
      MatchRules.submit(data, 'test-room', 5, 3, now);
      expect(data['results']['test-room']['submissions'].keys, [actor]);
      expect(data['results']['test-room']['status'], 'Menunggu konfirmasi');
      LocalRecord.validate(data);
    }
  });
  test('ordinary members, including the owner, cannot submit', () {
    for (final owned in [false, true]) {
      final data = record(actor: 'member', owned: owned);
      data['name'] = 'Ketua A';
      expect(
        () => MatchRules.submit(data, 'test-room', 1, 0, now),
        throwsStateError,
      );
      expect(data['results'], isEmpty);
    }
  });
  test('casual rooms and ranked events reject all score input', () {
    for (final data in [
      record(mode: 'Kasual', owned: true),
      record(kind: 'event', owned: true),
    ]) {
      expect(MatchRules.isCaptain(data, 'test-room'), isFalse);
      expect(
        () => MatchRules.submit(data, 'test-room', 1, 0, now),
        throwsStateError,
      );
    }
  });
  test('both captains must be registered, joined, and the match finished', () {
    final noOpponent = record();
    noOpponent['rankedMatches']['test-room']['teamB'] = null;
    final notJoined = record();
    notJoined['joined'] = <String>[];
    final unfinished = record();
    unfinished['activities'][0]['startsAt'] = now.toIso8601String();
    for (final data in [noOpponent, notJoined, unfinished]) {
      expect(
        () => MatchRules.submit(data, 'test-room', 1, 0, now),
        throwsStateError,
      );
    }
  });
  test('matching independent submissions approve and lock the result', () {
    final data = record(actor: 'captain-b');
    MatchRules.submit(data, 'test-room', 5, 3, now);
    expect(data['results']['test-room']['status'], 'Menunggu konfirmasi');
    data['playerId'] = 'captain-a';
    MatchRules.submit(data, 'test-room', 5, 3, now);
    expect(data['results']['test-room']['status'], 'Disahkan');
    LocalRecord.validate(data);
    final before = jsonEncode(data['results']);
    MatchRules.submit(data, 'test-room', 5, 3, now);
    expect(jsonEncode(data['results']), before);
    expect(
      () => MatchRules.submit(data, 'test-room', 6, 3, now),
      throwsStateError,
    );
  });
  test(
    'different scores are disputed until one captain corrects their own input',
    () {
      final data = record();
      MatchRules.submit(data, 'test-room', 5, 3, now);
      data['playerId'] = 'captain-b';
      MatchRules.submit(data, 'test-room', 3, 5, now);
      expect(data['results']['test-room']['status'], 'Skor berbeda');
      expect(data['results']['test-room']['confirmedAt'], isNull);
      LocalRecord.validate(data);
      expect(
        data['results']['test-room']['submissions']['captain-a']['scoreA'],
        5,
      );
      MatchRules.submit(data, 'test-room', 5, 3, now);
      expect(data['results']['test-room']['status'], 'Disahkan');
    },
  );
  test(
    'captain access survives profile name changes and rejects invalid scores',
    () {
      final data = record();
      data['name'] = 'Nama baru';
      MatchRules.submit(data, 'test-room', 0, 0, now);
      for (final scores in [
        [-1, 0],
        [1000, 0],
      ]) {
        expect(
          () => MatchRules.submit(data, 'test-room', scores[0], scores[1], now),
          throwsArgumentError,
        );
      }
    },
  );
  test('team registration cannot replace another captain or assign both teams to one person', () {
    final data = record(owned: true);
    data['activities'][0]['startsAt'] = now
        .add(const Duration(hours: 1))
        .toIso8601String();
    data.remove('rankedMatches');
    MatchRules.registerTeam(data, 'test-room', 'Tim A', now);
    expect(
      () => MatchRules.registerTeam(data, 'test-room', 'Tim lawan', now),
      throwsStateError,
    );
    data['playerId'] = 'captain-b';
    data['name'] = 'Ketua B';
    data.remove('teamId');
    MatchRules.registerTeam(data, 'test-room', 'Tim B', now);
    data['playerId'] = 'member';
    expect(
      () => MatchRules.registerTeam(data, 'test-room', 'Tim C', now),
      throwsStateError,
    );
    expect(RankedMatch.read(data, 'test-room')!.teamB!.captainId, 'captain-b');
  });
  test('captain registration closes at kickoff and withdrawing before kickoff frees team B', () {
    final data = record(actor: 'captain-b');
    data['activities'][0]['startsAt'] = now
        .add(const Duration(hours: 1))
        .toIso8601String();
    ActivityRules.leave(data, 'test-room', now: now);
    expect(RankedMatch.read(data, 'test-room')!.teamB, isNull);
    expect(data['joined'], isEmpty);
    final after = record(actor: 'captain-b');
    expect(
      () => ActivityRules.leave(after, 'test-room', now: now),
      throwsStateError,
    );
    final late = record();
    late.remove('rankedMatches');
    expect(
      () => MatchRules.registerTeam(late, 'test-room', 'Late team', now),
      throwsStateError,
    );
  });
  test(
    'tampered approvals and outsider score submissions fail record validation',
    () {
      final data = record();
      MatchRules.submit(data, 'test-room', 5, 3, now);
      data['results']['test-room']['status'] = 'Disahkan';
      expect(() => LocalRecord.validate(data), throwsFormatException);
      data['results']['test-room']['status'] = 'Menunggu konfirmasi';
      data['results']['test-room']['submissions']['member'] = {
        'scoreA': 5,
        'scoreB': 3,
        'at': now.toIso8601String(),
      };
      expect(() => LocalRecord.validate(data), throwsFormatException);
    },
  );
  test('failed storage does not approve a result and can be retried', () async {
    final repository = MemoryRepository()..record = record();
    final container = ProviderContainer(
      overrides: [localRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    // Use a past date relative to the real clock used by the notifier.
    repository.record['activities'][0]['startsAt'] = DateTime.now()
        .subtract(const Duration(hours: 3))
        .toIso8601String();
    await container.read(localStateProvider.future);
    final notifier = container.read(localStateProvider.notifier);
    await notifier.submitScore('test-room', 5, 3);
    await notifier.change((j) => j['playerId'] = 'captain-b');
    repository.rejectWrite = true;
    await expectLater(
      notifier.submitScore('test-room', 5, 3),
      throwsStateError,
    );
    expect(
      repository.record['results']['test-room']['status'],
      'Menunggu konfirmasi',
    );
    repository.rejectWrite = false;
    await notifier.submitScore('test-room', 5, 3);
    expect(repository.record['results']['test-room']['status'], 'Disahkan');
  });
  testWidgets('casual owner cannot see or deep-link into score input', (
    tester,
  ) async {
    final repository = MemoryRepository();
    repository.record['activities'][0]['owned'] = true;
    repository.record['joined'] = ['test-room'];
    await tester.pumpWidget(app(repository));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    container.read(appRouterProvider).go('/activity/test-room');
    await tester.pumpAndSettle();
    expect(find.text('Input hasil pertandingan'), findsNothing);
    container.read(appRouterProvider).go('/score/test-room');
    await tester.pumpAndSettle();
    expect(
      find.text('Input skor hanya tersedia di room Berperingkat.'),
      findsOneWidget,
    );
    expect(find.byType(TextFormField), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  test(
    'identity migration keeps legacy local data and a stable player ID',
    () async {
      final legacy = MemoryRepository().record;
      legacy['name'] = 'Nama tersimpan';
      legacy['results'] = {
        'test-room': {
          'own': 2,
          'other': 1,
          'status': 'Menunggu konfirmasi',
          'at': DateTime.now().toIso8601String(),
        },
      };
      SharedPreferences.setMockInitialValues({
        LocalRepository.storageKey: jsonEncode(legacy),
      });
      final first = await LocalRepository().load();
      final second = await LocalRepository().load();
      expect(first['playerId'], isNotEmpty);
      expect(first['playerId'], second['playerId']);
      expect(second['name'], 'Nama tersimpan');
      expect(second['results']['test-room']['own'], 2);
    },
  );
  testWidgets(
    'opposing captain gets the form while an ordinary room owner is denied',
    (tester) async {
      for (final actor in ['captain-b', 'member']) {
        final repository = MemoryRepository()
          ..record = record(actor: actor, owned: actor == 'member');
        repository.record['activities'][0]['startsAt'] = DateTime.now()
            .subtract(const Duration(hours: 3))
            .toIso8601String();
        await tester.pumpWidget(app(repository));
        await tester.pumpAndSettle();
        final container = ProviderScope.containerOf(
          tester.element(find.byType(MaterialApp)),
        );
        container.read(appRouterProvider).go('/score/test-room');
        await tester.pumpAndSettle();
        expect(
          find.byType(TextFormField),
          actor == 'captain-b' ? findsNWidgets(2) : findsNothing,
        );
        if (actor == 'member') {
          expect(
            find.text('Hanya ketua kedua tim yang dapat menginput skor.'),
            findsOneWidget,
          );
        }
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );
  testWidgets(
    'isolated example lets both captains submit and approves matching scores',
    (tester) async {
      await tester.pumpWidget(app(MemoryRepository()));
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      container.read(appRouterProvider).go('/score-example');
      await tester.pumpAndSettle();
      Future<void> submit() async {
        await tester.enterText(find.byType(TextFormField).at(0), '5');
        await tester.enterText(find.byType(TextFormField).at(1), '3');
        await tester.ensureVisible(find.text('Kirim skor ketua'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Kirim skor ketua'));
        await tester.pumpAndSettle();
      }

      await submit();
      expect(find.text('Menunggu konfirmasi'), findsOneWidget);
      await tester.ensureVisible(find.text('Ketua Tim Biru'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ketua Tim Biru'));
      await tester.pumpAndSettle();
      await submit();
      expect(find.text('Disahkan'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      expect(
        container.read(localStateProvider).requireValue['results'],
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
