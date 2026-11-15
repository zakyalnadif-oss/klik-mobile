import '../../../data/models/activity.dart';
import '../../../data/models/checkout_preview.dart';
import '../../events/logic/activity_rules.dart';

abstract final class CheckoutRules {
  static Activity _activity(Map<String, dynamic> data, String id) {
    final found = (data['activities'] as List).cast<Map>().where(
      (a) => a['id'] == id,
    );
    if (found.isEmpty) throw StateError('Pertandingan tidak ditemukan.');
    return Activity.fromJson(Map<String, dynamic>.from(found.first));
  }

  static void _eligible(Activity a, DateTime now) {
    if (a.price <= 0) {
      throw StateError('Pertandingan ini tidak memerlukan pembayaran.');
    }
    if (!a.startsAt.isAfter(now)) {
      throw StateError('Pertandingan sudah dimulai.');
    }
    if (a.remaining == 0) throw StateError('Pertandingan sudah penuh.');
  }

  static CheckoutPreview? read(Map<String, dynamic> data, String id) {
    final raw = (data['checkoutPreviews'] as Map?)?[id];
    return raw == null
        ? null
        : CheckoutPreview.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  static void open(Map<String, dynamic> data, String id, DateTime now) {
    if ((data['joined'] as List).contains(id)) {
      throw StateError('Kamu sudah bergabung.');
    }
    final a = _activity(data, id);
    _eligible(a, now);
    final existing = read(data, id);
    if (existing != null &&
        existing.status == 'pending' &&
        !existing.expired(now) &&
        existing.amount == a.price) {
      return;
    }
    final order = CheckoutPreview(
      reference:
          'KLIK-${now.microsecondsSinceEpoch.toRadixString(36).toUpperCase()}',
      activityId: id,
      amount: a.price,
      createdAt: now,
      expiresAt: now.add(const Duration(minutes: 15)),
    );
    (data.putIfAbsent('checkoutPreviews', () => <String, dynamic>{})
        as Map)[id] = order
        .toJson();
  }

  static void confirm(
    Map<String, dynamic> data,
    String id,
    String reference,
    DateTime now,
  ) {
    final order = read(data, id);
    if (order == null || order.reference != reference) {
      throw StateError(
        'Kode pembayaran tidak sesuai. Buka kembali pembayaran.',
      );
    }
    if (order.confirmed && (data['joined'] as List).contains(id)) return;
    if (order.status != 'pending') {
      throw StateError('Pembayaran ini sudah ditutup.');
    }
    if (order.expired(now)) {
      throw StateError('Kode QR kedaluwarsa. Buat kode baru.');
    }
    final a = _activity(data, id);
    _eligible(a, now);
    if (order.amount != a.price) {
      throw StateError('Biaya pertandingan berubah. Buat kode baru.');
    }
    // This local preview never verifies or records a real financial settlement.
    ActivityRules.join(data, id, now, previewPaymentConfirmed: true);
    ((data['checkoutPreviews'] as Map)[id] as Map)['status'] = 'demo_confirmed';
  }

  static void cancel(Map<String, dynamic> data, String id) {
    final raw = (data['checkoutPreviews'] as Map?)?[id] as Map?;
    if (raw?['status'] == 'pending') raw!['status'] = 'cancelled';
  }
}
