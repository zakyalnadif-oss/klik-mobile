import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../data/providers/backend_provider.dart';
import '../../../data/providers/local_state.dart';
import '../../../shared/widgets/klik_ui.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return KPage(
      title: 'Pengaturan',
      children: [
        const SectionTitle('Tampilan'),
        KCard(
          child: Column(
            children: [
              for (final pair in [
                (ThemeMode.system, 'Ikuti perangkat'),
                (ThemeMode.light, 'Terang'),
                (ThemeMode.dark, 'Gelap'),
              ])
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(pair.$2),
                  trailing: Icon(
                    mode == pair.$1
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                  ),
                  onTap: () => perform(
                    context,
                    () => ref.read(themeModeProvider.notifier).select(pair.$1),
                  ),
                ),
            ],
          ),
        ),
        const SectionTitle('Penyimpanan data'),
        const KCard(
          child: Text(
            'Data uji coba disimpan melalui SharedPreferences di perangkat ini, bukan server. Menghapus data aplikasi atau uninstall dapat menghilangkannya. Belum ada sinkronisasi atau pencadangan cloud. Jangan gunakan data sensitif untuk pengujian.',
          ),
        ),
        const SectionTitle('Versi aplikasi'),
        const Text('KLIK 0.4.2 • Uji coba lokal'),
        KButton(
          'Akun dan login',
          secondary: true,
          onPressed: () => context.push('/login'),
        ),
        KButton(
          'Keluar dari sesi',
          secondary: true,
          onPressed: () async {
            if (!await confirmAction(
              context,
              'Keluar dari sesi?',
              'Data uji coba akan tetap tersimpan di perangkat.',
            )) {
              return;
            }
            try {
              final client = await ref.read(backendProvider.future);
              if (client != null) await client.auth.signOut();
              await ref
                  .read(localStateProvider.notifier)
                  .change((j) => j['onboarded'] = false);
              if (context.mounted) context.go('/welcome');
            } catch (_) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Sesi belum berhasil diakhiri. Coba lagi.'),
                  ),
                );
              }
            }
          },
        ),
      ],
    );
  }
}
