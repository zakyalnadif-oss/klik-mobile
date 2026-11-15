import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/local_record.dart';
import '../models/ranked_match.dart';

class LocalRepository {
  static const storageKey = 'klik.local.testing.v2';
  Future<Map<String, dynamic>> load() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(storageKey);
    if (raw != null) {
      try {
        final parsed = jsonDecode(raw);
        if (parsed is Map<String, dynamic> && parsed['version'] == 2) {
          LocalRecord.validate(parsed);
          if (_prepareRankedData(parsed)) {
            LocalRecord.validate(parsed);
            await save(parsed);
          }
          return parsed;
        }
      } on FormatException {
        // Preserve an unreadable record for inspection rather than overwriting it.
        throw const FormatException('Data lokal tidak dapat dibaca.');
      }
      throw const FormatException('Versi data lokal belum didukung.');
    }
    final catalog = jsonDecode(
      await rootBundle.loadString('assets/demo/catalog.json'),
    ) as Map<String, dynamic>;
    final now = DateTime.now();
    final activities = (catalog['activities'] as List).map((value) {
      final j = Map<String, dynamic>.from(value as Map);
      final day = now.add(Duration(days: j.remove('dayOffset') as int));
      j['startsAt'] = DateTime(
        day.year,
        day.month,
        day.day,
        j.remove('hour') as int,
      ).toUtc().toIso8601String();
      j['demo'] = true;
      return j;
    }).toList();
    final record = <String, dynamic>{
      'version': 2,
      'onboarded': false,
      'name': 'Pemain KLIK',
      'city': 'Jakarta Selatan',
      'sport': 'Futsal',
      'level': 'Menengah',
      'theme': 'system',
      'activities': activities,
      'players': catalog['players'],
      'rankings': catalog['rankings'] ?? <dynamic>[],
      'venues': catalog['venues'],
      'joined': <String>[],
      'friends': <String>[],
      'requested': <String>[],
      'communities': <String>[],
      'results': <String, dynamic>{},
      'readNotifications': false,
    };
    _prepareRankedData(record);
    return record;
  }

  bool _prepareRankedData(Map<String, dynamic> data) {
    var changed = false;
    if (data['playerId'] == null) {
      data['playerId'] =
          'local-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(0x100000000).toRadixString(16)}';
      changed = true;
    }
    final matches = data['rankedMatches'] as Map? ?? <String, dynamic>{};
    for (final a in (data['activities'] as List).cast<Map>()) {
      if (a['id'] == 'room-cilandak' &&
          a['demo'] == true &&
          a['owned'] != true &&
          a['mode'] == 'Berperingkat' &&
          !matches.containsKey(a['id'])) {
        matches[a['id']] = const RankedMatch(
          teamA: MatchTeam(
            id: 'example-team-rizky',
            name: 'Tim Rizky',
            captainId: 'example-captain-rizky',
            captainName: 'Rizky Saputra',
          ),
        ).toJson();
        changed = true;
      }
    }
    if (matches.isNotEmpty) data['rankedMatches'] = matches;
    return changed;
  }

  Future<void> save(Map<String, dynamic> value) async {
    final preferences = await SharedPreferences.getInstance();
    if (!await preferences.setString(storageKey, jsonEncode(value))) {
      throw StateError('Data belum berhasil disimpan ke perangkat.');
    }
  }
}
