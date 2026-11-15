import '../../../data/models/activity.dart';
import '../../../data/models/ranked_match.dart';

abstract final class MatchRules {
  static Activity? activityOf(Map<String, dynamic> data, String id) {
    final found = (data['activities'] as List).cast<Map>().where(
      (a) => a['id'] == id,
    );
    return found.isEmpty
        ? null
        : Activity.fromJson(Map<String, dynamic>.from(found.first));
  }

  static bool rankedRoom(Activity a) =>
      a.kind == 'room' && a.mode == 'Berperingkat';

  static void registerTeam(
    Map<String, dynamic> data,
    String id,
    String name,
    DateTime now,
  ) {
    final a = activityOf(data, id);
    if (a == null || !rankedRoom(a)) {
      throw StateError('Pendaftaran tim hanya untuk room Berperingkat.');
    }
    if (!(data['joined'] as List).contains(id)) {
      throw StateError('Gabung room terlebih dahulu.');
    }
    if (!now.isBefore(a.startsAt)) {
      throw StateError(
        'Ketua tim harus terdaftar sebelum pertandingan dimulai.',
      );
    }
    if (name.trim().isEmpty || name.trim().length > 60) {
      throw ArgumentError('Isi nama tim, maksimal 60 karakter.');
    }
    final player = localPlayerId(data);
    data.putIfAbsent('playerId', () => player);
    final team = MatchTeam(
      id: data['teamId'] as String? ?? 'team-$player',
      name: name.trim(),
      captainId: player,
      captainName: data['name'] as String,
    );
    final fixture = RankedMatch.read(data, id);
    RankedMatch next;
    if (fixture == null) {
      if (!a.owned) throw StateError('Tim pembuat room belum terdaftar.');
      next = RankedMatch(teamA: team);
    } else {
      if (fixture.teamFor(player) != null) {
        throw StateError('Tim kamu sudah terdaftar.');
      }
      if (fixture.teamB != null) throw StateError('Kedua tim sudah terdaftar.');
      if (team.id == fixture.teamA.id) {
        throw StateError('Tim lawan harus berbeda.');
      }
      next = RankedMatch(teamA: fixture.teamA, teamB: team);
    }
    (data.putIfAbsent('rankedMatches', () => <String, dynamic>{}) as Map)[id] =
        next.toJson();
    data['teamName'] = team.name;
    data['teamId'] = team.id;
  }

  static bool isCaptain(Map<String, dynamic> data, String id) {
    final a = activityOf(data, id), fixture = RankedMatch.read(data, id);
    return a != null &&
        rankedRoom(a) &&
        fixture?.ready == true &&
        (data['joined'] as List).contains(id) &&
        fixture!.teamFor(localPlayerId(data)) != null;
  }

  static String? denial(Map<String, dynamic> data, String id, DateTime now) {
    final a = activityOf(data, id);
    if (a == null) return 'Room tidak ditemukan.';
    if (!rankedRoom(a)) {
      return 'Input skor hanya tersedia di room Berperingkat.';
    }
    if (!(data['joined'] as List).contains(id)) {
      return 'Gabung room terlebih dahulu.';
    }
    final fixture = RankedMatch.read(data, id);
    if (fixture?.ready != true) {
      return 'Kedua tim dan ketuanya harus terdaftar terlebih dahulu.';
    }
    if (fixture!.teamFor(localPlayerId(data)) == null) {
      return 'Hanya ketua kedua tim yang dapat menginput skor.';
    }
    if (now.isBefore(a.endsAt)) return 'Pertandingan belum selesai.';
    final existing = (data['results'] as Map)[id] as Map?;
    if (existing != null && existing['schema'] != 2) {
      return 'Hasil versi lama hanya dapat dibaca.';
    }
    return null;
  }

  static void submit(
    Map<String, dynamic> data,
    String id,
    int scoreA,
    int scoreB,
    DateTime now,
  ) {
    final reason = denial(data, id, now);
    if (reason != null) throw StateError(reason);
    if (scoreA < 0 || scoreB < 0 || scoreA > 999 || scoreB > 999) {
      throw ArgumentError('Skor harus antara 0 dan 999.');
    }
    final fixture = RankedMatch.read(data, id)!;
    final player = localPlayerId(data);
    data.putIfAbsent('playerId', () => player);
    final results = data['results'] as Map;
    final old = results[id] as Map?;
    if (old?['status'] == 'Disahkan') {
      final previous = (old!['submissions'] as Map)[player] as Map?;
      if (previous?['scoreA'] == scoreA && previous?['scoreB'] == scoreB) {
        return;
      }
      throw StateError('Skor sudah disahkan dan tidak dapat diubah.');
    }
    final submissions = <String, dynamic>{
      ...?((old?['submissions'] as Map?)?.cast<String, dynamic>()),
      player: {
        'scoreA': scoreA,
        'scoreB': scoreB,
        'at': now.toUtc().toIso8601String(),
      },
    };
    final first = submissions[fixture.teamA.captainId] as Map?;
    final second = submissions[fixture.teamB!.captainId] as Map?;
    final both = first != null && second != null;
    final agree =
        both &&
        first['scoreA'] == second['scoreA'] &&
        first['scoreB'] == second['scoreB'];
    final canonical = first ?? second!;
    results[id] = {
      'schema': 2,
      'own': canonical['scoreA'],
      'other': canonical['scoreB'],
      'status': agree
          ? 'Disahkan'
          : both
          ? 'Skor berbeda'
          : 'Menunggu konfirmasi',
      'at': now.toUtc().toIso8601String(),
      'submissions': submissions,
      if (agree) 'confirmedAt': now.toUtc().toIso8601String(),
    };
  }
}
