import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/providers/local_state.dart';
import '../../../shared/widgets/klik_ui.dart';

import '../logic/session_provider.dart';

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});
  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  bool busy = false;
  @override
  Widget build(BuildContext context) => KPage(
    title: 'klik',
    children: [
      const SizedBox(height: 24),
      Text(
        'Temukan rekan.\nMulai bermain.',
        style: textStyle(40, weight: FontWeight.w800),
      ),
      Text(
        'Olahraga favoritmu, teman baru, dan pertandingan yang adil. Semua berawal dari satu klik.',
        style: textStyle(16, color: secondary(context)),
      ),
      const SizedBox(height: 16),
      KCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.sports_soccer, size: 40, color: accent),
            const SizedBox(height: 20),
            Text(
              'Siap bermain?',
              style: textStyle(24, weight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            const Text(
              'Terhubung langsung ke server database KLIK. Masuk atau daftar untuk berteman dan bermain dengan pemain lain secara real-time.',
            ),
          ],
        ),
      ),
      KButton(
        'Coba tanpa akun',
        busy: busy,
        onPressed: () async {
          setState(() => busy = true);
          try {
            final api = ref.read(authApiClientProvider);
            final syncData = await api.fetchSync();
            if (syncData != null) {
              await ref.read(localStateProvider.notifier).syncWithServer(syncData);
            }
            await ref.read(localStateProvider.notifier).start();
            if (context.mounted) context.go('/');
          } catch (_) {
            if (context.mounted) {
              setState(() => busy = false);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Mode uji coba belum dapat dimulai. Periksa penyimpanan perangkat.',
                  ),
                ),
              );
            }
          }
        },
      ),
      KButton(
        'Masuk',
        secondary: true,
        onPressed: () => context.push('/login'),
      ),
      TextButton(
        onPressed: () => context.push('/register'),
        child: const Text('Belum punya akun? Daftar'),
      ),
      const LocalNotice(),
    ],
  );
}
