import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/local_record.dart';

class LocalRepository {
  static const storageKey = 'klik.local.testing.v2';
  Future<Map<String, dynamic>> load() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(storageKey);
    if (raw != null) {
      try {
        final parsed = jsonDecode(raw);
        if (parsed is Map<String, dynamic> && parsed['version'] == 2) {
          return LocalRecord.validate(parsed);
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
    return {
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
  }

  Future<void> save(Map<String, dynamic> value) async {
    final preferences = await SharedPreferences.getInstance();
    if (!await preferences.setString(storageKey, jsonEncode(value))) {
      throw StateError('Data belum berhasil disimpan ke perangkat.');
    }
  }
}
