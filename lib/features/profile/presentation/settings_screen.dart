import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../data/providers/local_state.dart';
import '../../../shared/widgets/klik_ui.dart';
import '../../auth/logic/session_provider.dart';

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
        const SizedBox(height: 12),
        KButton(
          'Log Out',
          secondary: true,
          onPressed: () async {
            if (!await confirmAction(
              context,
              'Log Out?',
              'Apakah kamu yakin ingin keluar dari akun ini?',
            )) {
              return;
            }
            try {
              // Clear API token and local session
              ref.read(authApiClientProvider).logout();
              ref.read(sessionProvider.notifier).state = null;
              await ref
                  .read(localStateProvider.notifier)
                  .change((j) => j['onboarded'] = false);
              if (context.mounted) context.go('/welcome');
            } catch (_) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Gagal log out. Coba lagi.'),
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
