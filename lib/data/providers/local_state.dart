import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/logic/session_provider.dart';
import '../../features/events/logic/activity_rules.dart';
import '../../features/tanding/logic/match_rules.dart';
import '../../features/payments/logic/checkout_rules.dart';
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

  Future<void> syncWithServer(Map<String, dynamic> syncData) => change((j) {
    if (syncData['activities'] is List && (syncData['activities'] as List).isNotEmpty) {
      j['activities'] = (syncData['activities'] as List)
          .map((a) => Map<String, dynamic>.from(a as Map))
          .toList();
    }
    if (syncData['players'] is List && (syncData['players'] as List).isNotEmpty) {
      j['players'] = (syncData['players'] as List)
          .map((p) => Map<String, dynamic>.from(p as Map))
          .toList();
    }
    if (syncData['venues'] is List && (syncData['venues'] as List).isNotEmpty) {
      j['venues'] = (syncData['venues'] as List)
          .map((v) => Map<String, dynamic>.from(v as Map))
          .toList();
    }
    if (syncData['rankings'] is List && (syncData['rankings'] as List).isNotEmpty) {
      j['rankings'] = (syncData['rankings'] as List)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();
    }
    if (syncData['joined'] is List) {
      final joinedList = (syncData['joined'] as List).cast<String>().toList();
      for (final id in joinedList) {
        if (!(j['joined'] as List).contains(id)) {
          (j['joined'] as List).add(id);
        }
      }
    }
    if (syncData['friends'] is List) {
      j['friends'] = (syncData['friends'] as List).cast<String>().toSet().toList();
    }
    if (syncData['requested'] is List) {
      j['requested'] = (syncData['requested'] as List).cast<String>().toSet().toList();
    }
    if (syncData['incomingRequests'] is List) {
      j['incomingRequests'] = (syncData['incomingRequests'] as List).cast<String>().toSet().toList();
    }
    if (syncData['notifications'] is List) {
      j['notifications'] = (syncData['notifications'] as List)
          .map((n) => Map<String, dynamic>.from(n as Map))
          .toList();
    }
    final user = syncData['user'];
    if (user is Map) {
      if (user['display_name'] != null && (user['display_name'] as String).isNotEmpty) {
        j['name'] = user['display_name'];
      }
      if (user['city'] != null && (user['city'] as String).isNotEmpty) {
        j['city'] = user['city'];
      }
      if (user['sport'] != null && (user['sport'] as String).isNotEmpty) {
        j['sport'] = user['sport'];
      }
      if (user['level'] != null && (user['level'] as String).isNotEmpty) {
        j['level'] = user['level'];
      }
      if (user['playerId'] != null && (user['playerId'] as String).isNotEmpty) {
        j['playerId'] = user['playerId'];
      }
    }
  });

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
  Future<void> openCheckout(String id) =>
      change((j) => CheckoutRules.open(j, id, DateTime.now()));
  Future<void> confirmCheckout(String id, String reference) =>
      change((j) => CheckoutRules.confirm(j, id, reference, DateTime.now()));
  Future<void> cancelCheckout(String id) =>
      change((j) => CheckoutRules.cancel(j, id));
  Future<void> leave(String id) => change((j) => ActivityRules.leave(j, id));
  Future<void> create(Activity activity, {String? teamName}) => change((j) {
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
    if (MatchRules.rankedRoom(activity) && teamName != null) {
      MatchRules.registerTeam(j, activity.id, teamName, DateTime.now());
    }
  });
  Future<void> registerMatchTeam(String id, String name) =>
      change((j) => MatchRules.registerTeam(j, id, name, DateTime.now()));
  Future<void> requestFriend(String id) async {
    final isRequested = (state.requireValue['requested'] as List).contains(id);
    final api = ref.read(authApiClientProvider);
    if (isRequested) {
      await api.cancelFriendRequest(id);
      await change((j) {
        (j['requested'] as List).remove(id);
      });
    } else {
      await api.sendFriendRequest(id);
      await change((j) {
        if (!(j['players'] as List).any((p) => p['id'] == id)) {
          throw StateError('Pemain tidak ditemukan.');
        }
        if ((j['friends'] as List).contains(id)) {
          return;
        }
        final requested = j['requested'] as List;
        if (!requested.contains(id)) requested.add(id);
      });
    }
  }

  Future<void> acceptFriend(String id) async {
    final api = ref.read(authApiClientProvider);
    await api.acceptFriendRequest(id);
    await change((j) {
      final inc = j['incomingRequests'] as List? ?? [];
      inc.remove(id);
      j['incomingRequests'] = inc;

      final friends = j['friends'] as List;
      if (!friends.contains(id)) friends.add(id);

      (j['requested'] as List).remove(id);

      // Find player name for local notification
      final matches = (j['players'] as List).cast<Map>().where((p) => p['id'] == id);
      final playerName = matches.isNotEmpty ? (matches.first['name'] as String? ?? id) : id;

      final notifs = (j['notifications'] as List? ?? []).toList();
      notifs.insert(0, {
        'id': DateTime.now().millisecondsSinceEpoch,
        'title': 'Pertemanan Diterima',
        'body': 'Kamu sekarang berteman dengan $playerName!',
        'isRead': false,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      });
      j['notifications'] = notifs;
    });
  }

  Future<void> rejectFriend(String id) async {
    final api = ref.read(authApiClientProvider);
    await api.rejectFriendRequest(id);
    await change((j) {
      final inc = j['incomingRequests'] as List? ?? [];
      inc.remove(id);
      j['incomingRequests'] = inc;
    });
  }

  Future<void> removeFriend(String id) async {
    final api = ref.read(authApiClientProvider);
    await api.removeFriend(id);
    await change((j) {
      (j['friends'] as List).remove(id);
    });
  }

  Future<void> markNotificationRead(dynamic id) async {
    final intId = id is int ? id : int.tryParse(id.toString());
    if (intId != null) {
      final api = ref.read(authApiClientProvider);
      await api.markNotificationRead(intId);
    }
    await change((j) {
      final notifs = (j['notifications'] as List? ?? []).map((n) {
        final map = Map<String, dynamic>.from(n as Map);
        if (map['id'] == id || map['id'] == intId) {
          map['isRead'] = true;
        }
        return map;
      }).toList();
      j['notifications'] = notifs;
    });
  }

  Future<void> refreshSync() async {
    try {
      final api = ref.read(authApiClientProvider);
      final syncData = await api.fetchSync();
      if (syncData != null) {
        await syncWithServer(syncData);
      }
    } catch (_) {}
  }
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
