import '../../../data/models/activity.dart';
import '../../../data/models/local_record.dart';
import '../../../data/models/ranked_match.dart';

abstract final class ActivityRules {
  static void validateNew(Activity activity, DateTime now) {
    if (activity.id.trim().isEmpty ||
        !['room', 'event'].contains(activity.kind)) {
      throw ArgumentError('Jenis kegiatan tidak valid.');
    }
    if (!LocalRecord.sports.contains(activity.sport) ||
        !['Kasual', 'Berperingkat'].contains(activity.mode)) {
      throw ArgumentError('Olahraga atau mode tidak valid.');
    }
    if (activity.title.trim().isEmpty || activity.title.length > 80) {
      throw ArgumentError('Nama kegiatan wajib diisi, maksimal 80 karakter.');
    }
    if (activity.venue.trim().isEmpty || activity.description.trim().isEmpty) {
      throw ArgumentError('Lokasi dan deskripsi wajib diisi.');
    }
    if (activity.capacity < 2 ||
        activity.capacity > 100 ||
        activity.occupied != 1) {
      throw ArgumentError('Kapasitas harus 2–100 peserta.');
    }
    if (activity.price < 0 || activity.price > 100000000) {
      throw ArgumentError('Biaya tidak valid.');
    }
    if (activity.durationMinutes < 15 || activity.durationMinutes > 1440) {
      throw ArgumentError('Durasi harus 15 menit hingga 24 jam.');
    }
    if (!activity.startsAt.isAfter(now)) {
      throw ArgumentError('Pilih jadwal yang belum lewat.');
    }
  }

  static void join(
    Map<String, dynamic> data,
    String id,
    DateTime now, {
    bool previewPaymentConfirmed = false,
  }) {
    final list = data['joined'] as List;
    if (list.contains(id)) return;
    final found = (data['activities'] as List)
        .cast<Map<String, dynamic>>()
        .where((a) => a['id'] == id);
    if (found.isEmpty) throw StateError('Kegiatan tidak ditemukan.');
    final row = found.first;
    if ((row['price'] as int) > 0 && !previewPaymentConfirmed) {
      throw StateError('Lanjutkan pembayaran terlebih dahulu.');
    }
    if ((row['occupied'] as int) >= (row['capacity'] as int)) {
      throw StateError('Kegiatan sudah penuh.');
    }
    if (!DateTime.parse(row['startsAt'] as String).isAfter(now)) {
      throw StateError('Kegiatan sudah lewat.');
    }
    list.add(id);
    row['occupied'] = (row['occupied'] as int) + 1;
  }

  static void leave(Map<String, dynamic> data, String id, {DateTime? now}) {
    final found = (data['activities'] as List)
        .cast<Map<String, dynamic>>()
        .where((a) => a['id'] == id);
    if (found.isEmpty) throw StateError('Kegiatan tidak ditemukan.');
    final row = found.first;
    if (row['owned'] == true) {
      throw StateError(
        'Pembuat kegiatan tidak dapat meninggalkan kegiatannya.',
      );
    }
    if ((data['results'] as Map).containsKey(id)) {
      throw StateError('Hasil kegiatan sudah dikirim.');
    }
    final fixture = RankedMatch.read(data, id);
    final captainB = fixture?.teamB?.captainId == localPlayerId(data);
    if (captainB &&
        !(now ?? DateTime.now()).isBefore(
          DateTime.parse(row['startsAt'] as String),
        )) {
      throw StateError(
        'Ketua tim tidak dapat keluar setelah pertandingan dimulai.',
      );
    }
    if ((data['joined'] as List).remove(id)) {
      row['occupied'] = ((row['occupied'] as int) - 1).clamp(
        0,
        row['capacity'] as int,
      );
      if (captainB) ((data['rankedMatches'] as Map)[id] as Map)['teamB'] = null;
    }
  }
}
