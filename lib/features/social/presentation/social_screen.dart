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
  void initState() {
    super.initState();
    // Auto sync latest friends & incoming requests from PostgreSQL on view
    Future.microtask(() {
      if (mounted) {
        ref.read(localStateProvider.notifier).refreshSync();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(localStateProvider).requireValue;
    final people = (data['players'] as List).cast<Map>();
    final requested = (data['requested'] as List).cast<String>();
    final friends = (data['friends'] as List).cast<String>();
    final incoming = (data['incomingRequests'] as List? ?? []).cast<String>();
    final myPlayerId = data['playerId'] as String?;

    final friendPlayers = people.where((p) => friends.contains(p['id'])).toList();
    final nonFriendPlayers = people.where(
      (p) => p['id'] != myPlayerId && !friends.contains(p['id']),
    ).toList();
    final incomingPlayers = people.where((p) => incoming.contains(p['id'])).toList();
    final sentPlayers = people.where((p) => requested.contains(p['id'])).toList();

    return KPage(
      title: 'Sosial',
      children: [
        Wrap(
          spacing: 8,
          children: [
            for (final name in ['Teman', 'Permintaan', 'Komunitas'])
              ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(name),
                    if (name == 'Permintaan' && incoming.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.error,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${incoming.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                selected: tab == name,
                onSelected: (_) => setState(() => tab = name),
              ),
          ],
        ),
        if (tab == 'Teman') ...[
          if (friendPlayers.isNotEmpty) ...[
            SectionTitle('Teman saya (${friendPlayers.length})'),
            for (final person in friendPlayers)
              PlayerTile(Map<String, dynamic>.from(person), isFriend: true),
          ] else ...[
            EmptyState(
              'Belum ada teman',
              'Tambah teman dari rekomendasi di bawah atau cari pemain.',
              action: 'Cari pemain',
              onAction: () => context.push('/search?tab=Rekan'),
            ),
          ],
          if (nonFriendPlayers.isNotEmpty) ...[
            const SectionTitle('Rekomendasi pemain'),
            for (final person in nonFriendPlayers)
              PlayerTile(Map<String, dynamic>.from(person)),
          ],
        ],
        if (tab == 'Permintaan') ...[
          if (incomingPlayers.isNotEmpty) ...[
            SectionTitle('Permintaan masuk (${incomingPlayers.length})'),
            for (final person in incomingPlayers)
              IncomingRequestCard(person: Map<String, dynamic>.from(person)),
          ] else ...[
            const EmptyState(
              'Belum ada permintaan masuk',
              'Permintaan pertemanan dari pemain lain akan muncul di sini.',
            ),
          ],
          if (sentPlayers.isNotEmpty) ...[
            SectionTitle('Permintaan terkirim (${sentPlayers.length})'),
            for (final person in sentPlayers)
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

class IncomingRequestCard extends ConsumerStatefulWidget {
  const IncomingRequestCard({required this.person, super.key});
  final Map<String, dynamic> person;

  @override
  ConsumerState<IncomingRequestCard> createState() => _IncomingRequestCardState();
}

class _IncomingRequestCardState extends ConsumerState<IncomingRequestCard> {
  bool busy = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.person;
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
                  p['initials'] as String? ?? 'P',
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
          Row(
            children: [
              Expanded(
                child: KButton(
                  'Terima',
                  busy: busy,
                  onPressed: () async {
                    setState(() => busy = true);
                    await perform(
                      context,
                      () => ref
                          .read(localStateProvider.notifier)
                          .acceptFriend(p['id'] as String),
                      success: 'Sekarang kamu berteman dengan ${p['name']}!',
                    );
                    if (context.mounted) setState(() => busy = false);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: KButton(
                  'Tolak',
                  secondary: true,
                  busy: busy,
                  onPressed: () async {
                    setState(() => busy = true);
                    await perform(
                      context,
                      () => ref
                          .read(localStateProvider.notifier)
                          .rejectFriend(p['id'] as String),
                      success: 'Permintaan pertemanan ditolak.',
                    );
                    if (context.mounted) setState(() => busy = false);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class PlayerTile extends ConsumerStatefulWidget {
  const PlayerTile(this.person, {this.isFriend = false, super.key});
  final Map<String, dynamic> person;
  final bool isFriend;
  @override
  ConsumerState<PlayerTile> createState() => _PlayerTileState();
}

class _PlayerTileState extends ConsumerState<PlayerTile> {
  bool busy = false;
  @override
  Widget build(BuildContext context) {
    final p = widget.person;
    final stateData = ref.watch(localStateProvider).requireValue;
    final requested =
        (stateData['requested'] as List).contains(p['id']);
    final incoming =
        (stateData['incomingRequests'] as List? ?? []).contains(p['id']);
    final isAlreadyFriend =
        widget.isFriend || (stateData['friends'] as List).contains(p['id']);

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
                  p['initials'] as String? ?? 'P',
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
              if (isAlreadyFriend)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check, size: 14, color: Color(0xFF171B12)),
                      const SizedBox(width: 4),
                      Text(
                        'Teman',
                        style: textStyle(12, weight: FontWeight.w700, color: const Color(0xFF171B12)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (isAlreadyFriend)
            KButton(
              'Hapus pertemanan',
              secondary: true,
              busy: busy,
              onPressed: () async {
                final confirm = await confirmAction(
                  context,
                  'Hapus teman?',
                  'Apakah kamu yakin ingin menghapus ${p['name']} dari daftar teman?',
                );
                if (!confirm) return;
                setState(() => busy = true);
                if (context.mounted) {
                  await perform(
                    context,
                    () => ref
                        .read(localStateProvider.notifier)
                        .removeFriend(p['id'] as String),
                    success: 'Pertemanan dengan ${p['name']} dihapus.',
                  );
                }
                if (context.mounted) setState(() => busy = false);
              },
            )
          else if (incoming)
            Row(
              children: [
                Expanded(
                  child: KButton(
                    'Terima',
                    busy: busy,
                    onPressed: () async {
                      setState(() => busy = true);
                      await perform(
                        context,
                        () => ref
                            .read(localStateProvider.notifier)
                            .acceptFriend(p['id'] as String),
                        success: 'Sekarang kamu berteman dengan ${p['name']}!',
                      );
                      if (context.mounted) setState(() => busy = false);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: KButton(
                    'Tolak',
                    secondary: true,
                    busy: busy,
                    onPressed: () async {
                      setState(() => busy = true);
                      await perform(
                        context,
                        () => ref
                            .read(localStateProvider.notifier)
                            .rejectFriend(p['id'] as String),
                        success: 'Permintaan pertemanan ditolak.',
                      );
                      if (context.mounted) setState(() => busy = false);
                    },
                  ),
                ),
              ],
            )
          else
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
                  success: requested
                      ? 'Permintaan pertemanan dibatalkan.'
                      : 'Permintaan pertemanan terkirim ke ${p['name']}!',
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
            'Komunitas olahraga untuk mencoba pilihan bergabung. Terhubung dengan pemain sehobi.',
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
