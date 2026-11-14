import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers/local_state.dart';
import '../../../shared/widgets/klik_ui.dart';

class VenueScreen extends ConsumerWidget {
  const VenueScreen({required this.name, super.key});
  final String name;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final found = (ref.watch(localStateProvider).requireValue['venues'] as List)
        .cast<Map>()
        .where((v) => v['name'] == name);
    final venue = found.isEmpty ? null : found.first;
    return KPage(
      title: 'Detail lapangan',
      children: [
        Text(name, style: textStyle(26, weight: FontWeight.w800)),
        KCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on_outlined, size: 32),
              const SizedBox(height: 16),
              SelectableText(
                venue?['address'] as String? ??
                    'Alamat lengkap belum ditambahkan oleh pembuat kegiatan.',
              ),
              const SizedBox(height: 16),
              Text(
                venue?['description'] as String? ?? 'Lokasi ini dimasukkan secara manual. Pastikan alamat kepada penyelenggara sebelum berangkat.',
              ),
            ],
          ),
        ),
        if (venue != null)
          KButton(
            'Salin alamat',
            secondary: true,
            onPressed: () => perform(
              context,
              () => Clipboard.setData(
                ClipboardData(text: venue['address'] as String),
              ),
              success: 'Alamat disalin.',
            ),
          ),
        const Text(
          'Peta, ketersediaan lapangan, dan pemesanan belum terhubung ke penyedia layanan.',
        ),
        const LocalNotice(),
      ],
    );
  }
}
