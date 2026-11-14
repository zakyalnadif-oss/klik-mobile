import 'dart:convert';
import 'dart:io';

import 'package:klik_mobile/data/models/activity.dart';
import 'package:klik_mobile/data/models/local_record.dart';
import 'package:klik_mobile/data/repositories/record_queue.dart';
import 'package:klik_mobile/features/events/logic/activity_rules.dart';
import 'package:klik_mobile/features/tanding/logic/match_rules.dart';

Future<void> main() async {
  var passed = 0;
  final now = DateTime(2030, 1, 1, 12);
  void check(bool condition, String name) {
    if (!condition) throw StateError('FAIL: $name');
    passed++;
  }

  void rejects(void Function() action, String name) {
    var failed = false;
    try {
      action();
    } on Object {
      failed = true;
    }
    check(failed, name);
  }

  Activity activity({
    String id = 'a',
    String title = 'Main futsal',
    String venue = 'Cilandak',
    String description = 'Datang tepat waktu',
    int capacity = 4,
    int occupied = 1,
    int price = 0,
    int duration = 120,
    DateTime? start,
    bool owned = false,
    String kind = 'room',
    String sport = 'Futsal',
  }) => Activity(
    id: id,
    kind: kind,
    title: title,
    sport: sport,
    venue: venue,
    city: 'Jakarta Selatan',
    mode: 'Kasual',
    startsAt: start ?? now.add(const Duration(days: 1)),
    capacity: capacity,
    occupied: occupied,
    price: price,
    owner: 'Pemain KLIK',
    description: description,
    owned: owned,
    durationMinutes: duration,
  );
  Map<String, dynamic> record(Activity a) => {
    'version': 2,
    'onboarded': true,
    'name': 'Pemain KLIK',
    'city': 'Jakarta Selatan',
    'sport': 'Futsal',
    'level': 'Menengah',
    'theme': 'system',
    'activities': [a.toJson()],
    'players': <Map<String, dynamic>>[],
    'venues': <Map<String, dynamic>>[],
    'joined': <String>[],
    'friends': <String>[],
    'requested': <String>[],
    'communities': <String>[],
    'results': <String, dynamic>{},
  };
  ActivityRules.validateNew(activity(), now);
  check(true, 'valid room');
  for (final bad in [
    activity(title: ''),
    activity(venue: ''),
    activity(description: ''),
    activity(capacity: 1),
    activity(capacity: 101),
    activity(occupied: 0),
    activity(price: -1),
    activity(price: 100000001),
    activity(duration: 14),
    activity(duration: 1441),
    activity(start: now),
    activity(kind: 'wrong'),
    activity(sport: 'wrong'),
  ]) {
    rejects(() => ActivityRules.validateNew(bad, now), 'invalid room rejected');
  }
  final joined = record(activity());
  ActivityRules.join(joined, 'a', now);
  check(
    (joined['joined'] as List).length == 1 &&
        (joined['activities'][0]['occupied'] == 2),
    'join reserves one slot',
  );
  ActivityRules.join(joined, 'a', now);
  check(
    joined['activities'][0]['occupied'] == 2,
    'duplicate join is idempotent',
  );
  ActivityRules.leave(joined, 'a');
  check(
    joined['activities'][0]['occupied'] == 1 &&
        (joined['joined'] as List).isEmpty,
    'leave returns slot',
  );
  ActivityRules.leave(joined, 'a');
  check(
    joined['activities'][0]['occupied'] == 1,
    'duplicate leave preserves slots',
  );
  rejects(
    () => ActivityRules.join(record(activity(occupied: 4)), 'a', now),
    'full room rejected',
  );
  rejects(
    () => ActivityRules.join(
      record(activity(start: now.subtract(const Duration(hours: 3)))),
      'a',
      now,
    ),
    'expired room rejected',
  );
  rejects(
    () => ActivityRules.join(record(activity()), 'missing', now),
    'unknown room rejected',
  );
  rejects(
    () => ActivityRules.leave(record(activity(owned: true)), 'a'),
    'owner cannot leave',
  );
  final ended = record(
    activity(owned: true, start: now.subtract(const Duration(hours: 3))),
  );
  (ended['joined'] as List).add('a');
  MatchRules.submit(ended, 'a', 5, 3, now);
  check(
    ended['results']['a']['status'] == 'Menunggu konfirmasi',
    'result remains pending',
  );
  rejects(
    () => MatchRules.submit(ended, 'a', 9, 0, now),
    'duplicate result rejected',
  );
  check(ended['results']['a']['own'] == 5, 'existing result preserved');
  Map<String, dynamic> scoring({
    bool owned = true,
    bool future = false,
    bool joined = true,
  }) {
    final j = record(
      activity(
        owned: owned,
        start: future
            ? now.add(const Duration(days: 1))
            : now.subtract(const Duration(hours: 3)),
      ),
    );
    if (joined) (j['joined'] as List).add('a');
    return j;
  }

  rejects(
    () => MatchRules.submit(scoring(owned: false), 'a', 1, 0, now),
    'nonowner cannot score',
  );
  rejects(
    () => MatchRules.submit(scoring(joined: false), 'a', 1, 0, now),
    'nonparticipant cannot score',
  );
  rejects(
    () => MatchRules.submit(scoring(future: true), 'a', 1, 0, now),
    'unfinished match cannot score',
  );
  rejects(
    () => MatchRules.submit(scoring(), 'a', -1, 0, now),
    'negative score rejected',
  );
  rejects(
    () => MatchRules.submit(scoring(), 'a', 1000, 0, now),
    'excessive score rejected',
  );
  final tie = scoring();
  MatchRules.submit(tie, 'a', 0, 0, now);
  check(tie['results']['a']['other'] == 0, 'zero score accepted');
  final rename = scoring();
  rename['name'] = 'Nama baru';
  MatchRules.submit(rename, 'a', 1, 0, now);
  check(
    rename['results']['a']['own'] == 1,
    'ownership survives profile rename',
  );
  LocalRecord.validate(record(activity()));
  check(true, 'valid record accepted');
  for (final mutate in <void Function(Map<String, dynamic>)>[
    (j) => j['theme'] = 'wrong',
    (j) => j['activities'].add(activity().toJson()),
    (j) => j['joined'] = ['missing'],
    (j) => j['joined'] = ['a', 'a'],
    (j) => j['activities'][0]['capacity'] = 'four',
    (j) => j['players'] = [
      {'id': 'incomplete'},
    ],
    (j) => j['results'] = {
      'missing': {
        'own': 1,
        'other': 0,
        'status': 'Menunggu konfirmasi',
        'at': now.toIso8601String(),
      },
    },
  ]) {
    final j = record(activity());
    mutate(j);
    rejects(() => LocalRecord.validate(j), 'corrupt record rejected');
  }
  check(
    Activity.fromJson(activity(duration: 90).toJson()).durationMinutes == 90,
    'model duration roundtrip',
  );
  var state = record(activity());
  final queue = RecordQueue();
  var saves = 0;
  Future<void> save(Map<String, dynamic> j) async {
    await Future<void>.delayed(const Duration(milliseconds: 2));
    saves++;
  }

  await Future.wait(
    List.generate(
      20,
      (_) => queue.apply(
        current: () => state,
        update: (j) => ActivityRules.join(j, 'a', now),
        save: save,
        commit: (j) => state = j,
      ),
    ),
  );
  check(
    state['activities'][0]['occupied'] == 2 &&
        (state['joined'] as List).length == 1,
    'concurrent joins do not duplicate',
  );
  final before = jsonEncode(state);
  var failed = false;
  try {
    await queue.apply(
      current: () => state,
      update: (j) => j['name'] = 'Unsaved',
      save: (j) async => throw StateError('disk full'),
      commit: (j) => state = j,
    );
  } on StateError {
    failed = true;
  }
  check(
    failed && jsonEncode(state) == before,
    'failed storage write rolls back',
  );
  await queue.apply(
    current: () => state,
    update: (j) => j['name'] = 'Saved',
    save: save,
    commit: (j) => state = j,
  );
  check(state['name'] == 'Saved', 'queue recovers after failed write');
  final previousSaves = saves;
  try {
    await queue.apply(
      current: () => state,
      update: (j) => j['theme'] = 'invalid',
      save: save,
      commit: (j) => state = j,
    );
  } on FormatException {
    /* expected */
  }
  check(
    state['theme'] == 'system' && saves == previousSaves,
    'invalid mutation never reaches storage',
  );
  check(
    activity().toJson()['startsAt'].toString().endsWith('Z'),
    'stored timestamps use UTC',
  );
  check(
    Activity.fromJson(activity().toJson()).startsAt
        .isAtSameMomentAs(activity().startsAt),
    'timestamp roundtrip preserves instant',
  );
  stdout.writeln('$passed business and persistence checks passed.');
}
