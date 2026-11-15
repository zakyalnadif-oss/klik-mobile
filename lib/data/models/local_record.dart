import 'activity.dart';
import 'checkout_preview.dart';
import 'ranked_match.dart';

abstract final class LocalRecord {
  static const sports = [
    'Futsal',
    'Basket',
    'Biliar',
    'Voli',
    'Padel',
    'Bulu Tangkis',
    'Sepak Bola',
  ];
  static Map<String, dynamic> validate(Map<String, dynamic> data) {
    try {
      if (data['version'] != 2 || data['onboarded'] is! bool) {
        throw const FormatException();
      }
      for (final key in ['name', 'city', 'sport', 'level', 'theme']) {
        if (data[key] is! String || (data[key] as String).trim().isEmpty) {
          throw const FormatException();
        }
      }
      if (!sports.contains(data['sport']) ||
          !['Pemula', 'Menengah', 'Mahir'].contains(data['level']) ||
          !['system', 'light', 'dark'].contains(data['theme'])) {
        throw const FormatException();
      }
      final records = data['activities'] as List;
      final ids = <String>{};
      for (final row in records) {
        final a = Activity.fromJson(Map<String, dynamic>.from(row as Map));
        if (!ids.add(a.id) ||
            a.id.isEmpty ||
            a.title.trim().isEmpty ||
            !['room', 'event'].contains(a.kind) ||
            !sports.contains(a.sport) ||
            !['Kasual', 'Berperingkat'].contains(a.mode) ||
            a.capacity < 2 ||
            a.capacity > 100 ||
            a.occupied < 0 ||
            a.occupied > a.capacity ||
            a.price < 0 ||
            a.durationMinutes < 15 ||
            a.durationMinutes > 1440) {
          throw const FormatException();
        }
      }
      for (final key in ['joined', 'friends', 'requested', 'communities']) {
        final values = data[key] as List;
        if (values.any((v) => v is! String) ||
            values.toSet().length != values.length) {
          throw const FormatException();
        }
      }
      if ((data['joined'] as List).any((id) => !ids.contains(id))) {
        throw const FormatException();
      }
      if (data['playerId'] != null &&
          (data['playerId'] is! String ||
              (data['playerId'] as String).trim().isEmpty)) {
        throw const FormatException();
      }
      if (data['rankedMatches'] != null) {
        for (final entry in (data['rankedMatches'] as Map).entries) {
          final a = records.cast<Map>().where((a) => a['id'] == entry.key);
          final fixture = RankedMatch.fromJson(entry.value as Map);
          if (a.isEmpty ||
              a.first['kind'] != 'room' ||
              a.first['mode'] != 'Berperingkat') {
            throw const FormatException();
          }
          for (final team in [
            fixture.teamA,
            if (fixture.teamB != null) fixture.teamB!,
          ]) {
            if ([
                  team.id,
                  team.name,
                  team.captainId,
                  team.captainName,
                ].any((s) => s.trim().isEmpty) ||
                team.name.length > 60) {
              throw const FormatException();
            }
          }
          if (fixture.teamB != null &&
              (fixture.teamA.id == fixture.teamB!.id ||
                  fixture.teamA.captainId == fixture.teamB!.captainId)) {
            throw const FormatException();
          }
        }
      }
      if (data['checkoutPreviews'] != null) {
        for (final entry in (data['checkoutPreviews'] as Map).entries) {
          final order = CheckoutPreview.fromJson(
            Map<String, dynamic>.from(entry.value as Map),
          );
          if (!ids.contains(entry.key) ||
              order.activityId != entry.key ||
              order.reference.isEmpty ||
              order.amount <= 0 ||
              order.amount > 100000000 ||
              !order.expiresAt.isAfter(order.createdAt) ||
              ![
                'pending',
                'demo_confirmed',
                'cancelled',
              ].contains(order.status)) {
            throw const FormatException();
          }
        }
      }
      for (final row in data['players'] as List) {
        final player = row as Map;
        for (final key in [
          'id',
          'name',
          'handle',
          'sport',
          'city',
          'level',
          'initials',
        ]) {
          if (player[key] is! String) throw const FormatException();
        }
      }
      for (final row in data['venues'] as List) {
        final venue = row as Map;
        for (final key in ['name', 'sport', 'address', 'description']) {
          if (venue[key] is! String) throw const FormatException();
        }
      }
      final results = data['results'] as Map;
      if (data['rankings'] != null) {
        for (final row in data['rankings'] as List) {
          final rank = row as Map;
          for (final key in [
            'sport',
            'type',
            'initials',
            'name',
            'detail',
            'points',
          ]) {
            if (rank[key] is! String) throw const FormatException();
          }
          if (!sports.contains(rank['sport']) ||
              !['Tim', 'Individu'].contains(rank['type']) ||
              rank['rank'] is! int ||
              (rank['rank'] as int) < 1 ||
              rank['highlight'] is! bool) {
            throw const FormatException();
          }
        }
      }
      for (final entry in results.entries) {
        final result = entry.value as Map;
        if (!ids.contains(entry.key) ||
            result['own'] is! int ||
            result['other'] is! int ||
            (result['own'] as int) < 0 ||
            (result['other'] as int) < 0 ||
            (result['own'] as int) > 999 ||
            (result['other'] as int) > 999 ||
            (result['schema'] != 2 &&
                result['status'] != 'Menunggu konfirmasi') ||
            DateTime.tryParse(result['at'] as String) == null) {
          throw const FormatException();
        }
        if (result['schema'] == 2) {
          final fixture = RankedMatch.read(data, entry.key as String);
          if (fixture?.ready != true) throw const FormatException();
          final submissions = result['submissions'] as Map;
          final captains = {fixture!.teamA.captainId, fixture.teamB!.captainId};
          if (submissions.isEmpty ||
              submissions.keys.any((k) => !captains.contains(k))) {
            throw const FormatException();
          }
          for (final raw in submissions.values) {
            final s = raw as Map;
            if (s['scoreA'] is! int ||
                s['scoreB'] is! int ||
                s['scoreA'] < 0 ||
                s['scoreB'] < 0 ||
                s['scoreA'] > 999 ||
                s['scoreB'] > 999 ||
                DateTime.tryParse(s['at'] as String) == null) {
              throw const FormatException();
            }
          }
          final first = submissions[fixture.teamA.captainId] as Map?;
          final second = submissions[fixture.teamB!.captainId] as Map?;
          final both = first != null && second != null;
          final agree =
              both &&
              first['scoreA'] == second['scoreA'] &&
              first['scoreB'] == second['scoreB'];
          final expected = agree
              ? 'Disahkan'
              : both
              ? 'Skor berbeda'
              : 'Menunggu konfirmasi';
          final canonical = first ?? second!;
          if (result['status'] != expected ||
              result['own'] != canonical['scoreA'] ||
              result['other'] != canonical['scoreB'] ||
              (agree &&
                  DateTime.tryParse(result['confirmedAt'] as String) == null) ||
              (!agree && result['confirmedAt'] != null)) {
            throw const FormatException();
          }
        }
      }
      return data;
    } on Object {
      throw const FormatException(
        'Struktur data lokal tidak valid. Data asli tidak dihapus.',
      );
    }
  }
}
