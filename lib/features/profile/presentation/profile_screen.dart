import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/providers/local_state.dart';
import '../../../shared/widgets/klik_ui.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(localStateProvider).requireValue;
    final results = data['results'] as Map;
    final count = (data['joined'] as List).length;
    return KPage(
      title: 'Profil',
      actions: [
        IconButton(
          tooltip: 'Pengaturan',
          onPressed: () => context.push('/settings'),
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
      children: [
        KCard(
          child: Column(
            children: [
              UserAvatar(
                name: data['name'] as String? ?? 'Pemain',
                avatarUrl: data['avatarUrl'] as String?,
                size: 80,
              ),
              const SizedBox(height: 14),
              Text(
                data['name'] as String,
                style: textStyle(24, weight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                '${data['city']}\n${data['sport']} • ${data['level']}',
                textAlign: TextAlign.center,
                style: textStyle(13, color: secondary(context)),
              ),
              const SizedBox(height: 16),
              KButton(
                'Edit profil',
                secondary: true,
                onPressed: () => context.push('/edit-profile'),
              ),
            ],
          ),
        ),
        KCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Skor kepercayaan',
                style: textStyle(16, weight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Belum tersedia',
                style: textStyle(24, weight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Dihitung dari kehadiran dan hasil terverifikasi. Tidak ada skor buatan pada mode uji coba.',
                style: textStyle(12, color: secondary(context)),
              ),
            ],
          ),
        ),
        Row(
          children: [
            Expanded(child: _Stat('Kegiatan', '$count', 'Tergabung lokal')),
            const SizedBox(width: 12),
            Expanded(
              child: _Stat('Hasil', '${results.length}', 'Menunggu lawan'),
            ),
          ],
        ),
        KButton(
          'Lihat Papan Peringkat',
          secondary: true,
          onPressed: () => context.push('/leaderboard'),
        ),
        KButton(
          'Riwayat pertandingan',
          secondary: true,
          onPressed: () => context.go('/matches'),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.title, this.value, this.detail);
  final String title, value, detail;
  @override
  Widget build(BuildContext context) => KCard(
    padding: 12,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: textStyle(12, color: secondary(context))),
        const SizedBox(height: 8),
        Text(value, style: textStyle(26, weight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(detail, style: textStyle(10, color: secondary(context))),
      ],
    ),
  );
}
