import 'activity.dart';
import 'checkout_preview.dart';

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
            result['status'] != 'Menunggu konfirmasi' ||
            DateTime.tryParse(result['at'] as String) == null) {
          throw const FormatException();
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
