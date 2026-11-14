import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/events/logic/activity_rules.dart';
import '../../features/tanding/logic/match_rules.dart';
import '../models/activity.dart';
import '../models/local_record.dart';
import '../repositories/local_repository.dart';
import '../repositories/record_queue.dart';

final localRepositoryProvider = Provider<LocalRepository>(
  (ref) => LocalRepository(),
);
final localStateProvider =
    AsyncNotifierProvider<LocalState, Map<String, dynamic>>(LocalState.new);

class LocalState extends AsyncNotifier<Map<String, dynamic>> {
  final _queue = RecordQueue();
  @override
  Future<Map<String, dynamic>> build() =>
      ref.read(localRepositoryProvider).load();
  Future<void> change(void Function(Map<String, dynamic>) update) {
    return _queue.apply(
      current: () => state.requireValue,
      update: update,
      save: ref.read(localRepositoryProvider).save,
      commit: (next) => state = AsyncData(next),
    );
  }

  Future<void> start() => change((j) => j['onboarded'] = true);
  Future<void> profile(String name, String city, String sport, String level) =>
      change((j) {
        if (name.trim().isEmpty ||
            name.trim().length > 50 ||
            city.trim().isEmpty ||
            city.trim().length > 80) {
          throw ArgumentError('Periksa nama dan domisili.');
        }
        j['name'] = name.trim();
        j['city'] = city.trim();
        j['sport'] = sport;
        j['level'] = level;
      });
  Future<void> join(String id) =>
      change((j) => ActivityRules.join(j, id, DateTime.now()));
  Future<void> leave(String id) => change((j) => ActivityRules.leave(j, id));
  Future<void> create(Activity activity) => change((j) {
    ActivityRules.validateNew(activity, DateTime.now());
    if ((j['activities'] as List).any((a) => a['id'] == activity.id)) {
      throw StateError('Kegiatan sudah dibuat.');
    }
    (j['activities'] as List).insert(0, {
      ...activity.toJson(),
      'owned': true,
      'owner': j['name'],
    });
    (j['joined'] as List).add(activity.id);
  });
  Future<void> requestFriend(String id) => change((j) {
    if (!(j['players'] as List).any((p) => p['id'] == id)) {
      throw StateError('Pemain tidak ditemukan.');
    }
    if ((j['friends'] as List).contains(id)) {
      return;
    }
    final requested = j['requested'] as List;
    requested.contains(id) ? requested.remove(id) : requested.add(id);
  });
  Future<void> toggleCommunity(String sport) => change((j) {
    if (!LocalRecord.sports.contains(sport)) {
      throw ArgumentError('Olahraga tidak valid.');
    }
    final list = j['communities'] as List;
    list.contains(sport) ? list.remove(sport) : list.add(sport);
  });
  Future<void> submitScore(String id, int own, int other) =>
      change((j) => MatchRules.submit(j, id, own, other, DateTime.now()));
}

List<Activity> activitiesOf(Map<String, dynamic> value) =>
    (value['activities'] as List)
        .map((j) => Activity.fromJson(Map<String, dynamic>.from(j as Map)))
        .toList();
