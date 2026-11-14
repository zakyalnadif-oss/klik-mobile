abstract final class MatchRules {
  static void submit(
    Map<String, dynamic> data,
    String id,
    int own,
    int other,
    DateTime now,
  ) {
    if (own < 0 || other < 0 || own > 999 || other > 999) {
      throw ArgumentError('Skor harus antara 0 dan 999.');
    }
    if (!(data['joined'] as List).contains(id)) {
      throw StateError('Gabung kegiatan terlebih dahulu.');
    }
    final found = (data['activities'] as List)
        .cast<Map<String, dynamic>>()
        .where((a) => a['id'] == id);
    if (found.isEmpty) throw StateError('Kegiatan tidak ditemukan.');
    if (found.first['owned'] != true) {
      throw StateError('Hanya pembuat kegiatan yang dapat mengirim hasil.');
    }
    final starts = DateTime.parse(found.first['startsAt'] as String);
    final duration =
        found.first['durationMinutes'] as int? ??
        (found.first['kind'] == 'event' ? 360 : 120);
    if (now.isBefore(starts.add(Duration(minutes: duration)))) {
      throw StateError('Pertandingan belum selesai.');
    }
    final results = data['results'] as Map;
    if (results.containsKey(id)) {
      throw StateError('Hasil sudah dikirim dan menunggu konfirmasi lawan.');
    }
    results[id] = {
      'own': own,
      'other': other,
      'status': 'Menunggu konfirmasi',
      'at': now.toIso8601String(),
    };
  }
}
