import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/backend_provider.dart';

class BackendStatusCard extends ConsumerWidget {
  const BackendStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ref
            .watch(backendProvider)
            .when(
              loading: () => const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Menyiapkan Supabase…'),
                ],
              ),
              error: (error, stack) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Konfigurasi Supabase belum berhasil dimuat.'),
                  const SizedBox(height: 12),
                  const Text(
                    'Periksa URL proyek, publishable key, dan koneksi jaringan.',
                  ),
                  TextButton(
                    onPressed: () => ref.invalidate(backendProvider),
                    child: const Text('Coba lagi'),
                  ),
                ],
              ),
              data: (client) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    client == null
                        ? 'Supabase belum dikonfigurasi'
                        : 'Konfigurasi Supabase dimuat',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    client == null
                        ? 'Isi SUPABASE_URL dan SUPABASE_PUBLISHABLE_KEY melalui dart-define. Panduan tersedia di README proyek.'
                        : 'Client siap digunakan. Akses database dan RLS akan diperiksa saat fitur pertama dihubungkan.',
                  ),
                ],
              ),
            ),
      ),
    );
  }
}
