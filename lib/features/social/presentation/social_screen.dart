import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/providers/local_state.dart';
import '../../../shared/widgets/klik_ui.dart';

class SocialScreen extends ConsumerStatefulWidget {
  const SocialScreen({super.key});
  @override
  ConsumerState<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends ConsumerState<SocialScreen> {
  String tab = 'Teman';
  @override
  Widget build(BuildContext context) {
    final data = ref.watch(localStateProvider).requireValue;
    final people = (data['players'] as List).cast<Map>();
    final requested = data['requested'] as List;
    return KPage(
      title: 'Sosial',
      children: [
        Wrap(
          spacing: 8,
          children: [
            for (final name in ['Teman', 'Permintaan', 'Komunitas'])
              ChoiceChip(
                label: Text(name),
                selected: tab == name,
                onSelected: (_) => setState(() => tab = name),
              ),
          ],
        ),
        if (tab == 'Teman') ...[
          EmptyState(
            'Belum ada teman',
            'Tambah teman dari profil pemain. Mereka akan muncul di sini setelah menerima permintaanmu.',
            action: 'Cari pemain',
            onAction: () => context.push('/search?tab=Rekan'),
          ),
          const SectionTitle('Rekomendasi pemain'),
          for (final person in people)
            PlayerTile(Map<String, dynamic>.from(person)),
        ],
        if (tab == 'Permintaan') ...[
          const EmptyState(
            'Belum ada permintaan masuk',
            'Penerimaan oleh pengguna lain memerlukan backend Supabase. Permintaan uji coba disimpan di perangkat ini.',
          ),
          if (requested.isNotEmpty) ...[
            const SectionTitle('Permintaan terkirim'),
            for (final person in people.where(
              (p) => requested.contains(p['id']),
            ))
              PlayerTile(Map<String, dynamic>.from(person)),
          ],
        ],
        if (tab == 'Komunitas') ...[
          Text(
            'Komunitas olahraga',
            style: textStyle(18, weight: FontWeight.w700),
          ),
          for (final sport in sports.take(3)) CommunityTile(sport: sport),
        ],
        const LocalNotice(),
      ],
    );
  }
}

class PlayerTile extends ConsumerStatefulWidget {
  const PlayerTile(this.person, {super.key});
  final Map<String, dynamic> person;
  @override
  ConsumerState<PlayerTile> createState() => _PlayerTileState();
}

class _PlayerTileState extends ConsumerState<PlayerTile> {
  bool busy = false;
  @override
  Widget build(BuildContext context) {
    final p = widget.person;
    final requested =
        (ref.watch(localStateProvider).requireValue['requested'] as List)
            .contains(p['id']);
    return KCard(
      onTap: () => context.push('/player/${p['id']}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: accent,
                child: Text(
                  p['initials'] as String,
                  textScaler: TextScaler.noScaling,
                  style: textStyle(
                    15,
                    weight: FontWeight.w800,
                    color: const Color(0xFF171B12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p['name'] as String,
                      style: textStyle(15, weight: FontWeight.w700),
                    ),
                    Text(
                      '${p['sport']} • ${p['level']}',
                      style: textStyle(12, color: secondary(context)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          KButton(
            requested ? 'Batalkan permintaan' : 'Tambah teman',
            secondary: requested,
            busy: busy,
            onPressed: () async {
              setState(() => busy = true);
              await perform(
                context,
                () => ref
                    .read(localStateProvider.notifier)
                    .requestFriend(p['id'] as String),
                success: requested ? 'Permintaan lokal dibatalkan.' : 'Permintaan disimpan lokal; belum terkirim ke pengguna nyata.',
              );
              if (context.mounted) setState(() => busy = false);
            },
          ),
        ],
      ),
    );
  }
}

class CommunityTile extends ConsumerStatefulWidget {
  const CommunityTile({required this.sport, super.key});
  final String sport;
  @override
  ConsumerState<CommunityTile> createState() => _CommunityTileState();
}

class _CommunityTileState extends ConsumerState<CommunityTile> {
  bool busy = false;
  @override
  Widget build(BuildContext context) {
    final joined =
        (ref.watch(localStateProvider).requireValue['communities'] as List)
            .contains(widget.sport);
    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Komunitas ${widget.sport}',
            style: textStyle(16, weight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Komunitas contoh untuk mencoba pilihan bergabung. Belum terhubung ke komunitas nyata.',
          ),
          const SizedBox(height: 16),
          KButton(
            joined ? 'Keluar komunitas' : 'Gabung komunitas',
            secondary: joined,
            busy: busy,
            onPressed: () async {
              setState(() => busy = true);
              await perform(
                context,
                () => ref
                    .read(localStateProvider.notifier)
                    .toggleCommunity(widget.sport),
              );
              if (context.mounted) setState(() => busy = false);
            },
          ),
        ],
      ),
    );
  }
}

class PlayerScreen extends ConsumerWidget {
  const PlayerScreen({required this.id, super.key});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matches =
        (ref.watch(localStateProvider).requireValue['players'] as List)
            .cast<Map>()
            .where((p) => p['id'] == id);
    if (matches.isEmpty) {
      return const KPage(
        title: 'Pemain',
        children: [
          EmptyState('Pemain tidak ditemukan', 'Kembali ke daftar pemain.'),
        ],
      );
    }
    final p = matches.first;
    return KPage(
      title: 'Profil pemain',
      children: [
        PlayerTile(Map<String, dynamic>.from(p)),
        KCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                p['handle'] as String,
                style: textStyle(20, weight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Text('${p['city']}\n${p['sport']} • ${p['level']}'),
            ],
          ),
        ),
        const EmptyState(
          'Belum ada hasil terverifikasi',
          'Statistik dan trust score tidak dibuat tanpa riwayat pertandingan yang sah.',
        ),
        const LocalNotice(),
      ],
    );
  }
}
