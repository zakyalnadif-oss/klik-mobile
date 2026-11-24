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

    final conversations = ((data['conversations'] as List?) ?? []).cast<Map>();
    final convMap = <String, Map<String, dynamic>>{};
    for (final c in conversations) {
      final pid = c['playerId'] as String?;
      if (pid != null) convMap[pid] = Map<String, dynamic>.from(c);
    }

    final friendPlayers = people.where((p) => friends.contains(p['id'])).toList()
      ..sort((a, b) {
        final aConv = convMap[a['id']];
        final bConv = convMap[b['id']];
        final aUnread = aConv?['unreadCount'] as int? ?? 0;
        final bUnread = bConv?['unreadCount'] as int? ?? 0;

        // 1. Yang punya unread chat ditaruh paling atas
        if (aUnread > 0 && bUnread == 0) return -1;
        if (bUnread > 0 && aUnread == 0) return 1;

        // 2. Jika sama-sama unread atau sama-sama read, urutkan berdasarkan waktu pesan terakhir
        final aTime = aConv?['lastMessageAt'] as String?;
        final bTime = bConv?['lastMessageAt'] as String?;
        if (aTime != null && bTime != null) {
          return bTime.compareTo(aTime);
        }
        if (aTime != null) return -1;
        if (bTime != null) return 1;

        return (a['name'] as String? ?? '').compareTo(b['name'] as String? ?? '');
      });
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
              PlayerTile(
                Map<String, dynamic>.from(person),
                isFriend: true,
                unreadChatCount: convMap[person['id']]?['unreadCount'] as int? ?? 0,
              ),
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
            'Komunitas Olahraga',
            style: textStyle(18, weight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Temukan rekan bermain, info mabar, dan ikuti kegiatan olahraga favoritmu.',
            style: textStyle(13, color: secondary(context)),
          ),
          const SizedBox(height: 12),
          for (final s in sports) CommunityTile(sport: s),
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
              UserAvatar(
                name: p['name'] as String? ?? 'Pemain',
                avatarUrl: p['avatar_url'] as String?,
                initials: p['initials'] as String?,
                size: 40,
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
  const PlayerTile(
    this.person, {
    this.isFriend = false,
    this.unreadChatCount = 0,
    super.key,
  });
  final Map<String, dynamic> person;
  final bool isFriend;
  final int unreadChatCount;
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
              UserAvatar(
                name: p['name'] as String? ?? 'Pemain',
                avatarUrl: p['avatar_url'] as String?,
                initials: p['initials'] as String?,
                size: 40,
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
              if (isAlreadyFriend) ...[
                if (widget.unreadChatCount > 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.mark_chat_unread_rounded,
                          size: 14,
                          color: Color(0xFF171B12),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.unreadChatCount} pesan baru',
                          style: textStyle(
                            11,
                            weight: FontWeight.w800,
                            color: const Color(0xFF171B12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
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
              ],
            ],
          ),
          const SizedBox(height: 12),
          if (isAlreadyFriend)
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 42,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: const Color(0xFF171B12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        // Langsung tandai percakapan sebagai sudah dibaca di state lokal
                        ref
                            .read(localStateProvider.notifier)
                            .markConversationRead(p['id'] as String);

                        final q = {
                          'name': p['name'] as String? ?? 'Teman',
                          if (p['avatar_url'] != null)
                            'avatarUrl': p['avatar_url'] as String,
                          if (p['initials'] != null)
                            'initials': p['initials'] as String,
                          if (p['sport'] != null) 'sport': p['sport'] as String,
                        };
                        final uri = Uri(
                          path: '/chat/${p['id']}',
                          queryParameters: q,
                        );
                        context.push(uri.toString());
                      },
                      icon: Icon(
                        widget.unreadChatCount > 0
                            ? Icons.mark_chat_unread_rounded
                            : Icons.chat_bubble_outline_rounded,
                        size: 17,
                      ),
                      label: Text(
                        widget.unreadChatCount > 0 ? 'Balas Chat' : 'Chat Teman',
                        style: textStyle(13, weight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 42,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: Theme.of(context)
                              .colorScheme
                              .error
                              .withValues(alpha: 0.5),
                          width: 1,
                        ),
                        foregroundColor: Theme.of(context).colorScheme.error,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: busy
                          ? null
                          : () async {
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
                                  success:
                                      'Pertemanan dengan ${p['name']} dihapus.',
                                );
                              }
                              if (context.mounted) setState(() => busy = false);
                            },
                      child: busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              'Hapus',
                              style: textStyle(12, weight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                    ),
                  ),
                ),
              ],
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

  String _getCommunityDescription(String sport) {
    switch (sport) {
      case 'Futsal':
        return 'Komunitas futsal terbesar untuk mabar rutin, cari lawan sparring, dan turnamen lokal.';
      case 'Basket':
        return 'Wadah pecinta bola basket 3x3 maupun 5on5. Rutin main tiap pekan di lapangan terdekat.';
      case 'Biliar':
        return 'Kumpulan pemain biliar dari santai hingga kompetitif. Temukan teman main 9-ball & 8-ball.';
      case 'Voli':
        return 'Komunitas voli untuk seru-seruan latihan servis, spike, dan laga persahabatan antar tim.';
      case 'Padel':
        return 'Komunitas padel tenis yang berkembang pesat. Cocok untuk semua level pemula hingga mahir.';
      case 'Bulu Tangkis':
        return 'Klub bulu tangkis aktif. Sewa lapangan bareng, latihan rally, ganda putra/campuran.';
      case 'Sepak Bola':
        return 'Komunitas sepak bola 11 vs 11 lapangan besar, info uji tanding dan liga komunitas.';
      default:
        return 'Komunitas olahraga untuk terhubung dengan pemain sehobi dan mabar rutin.';
    }
  }

  String _getSportIconName(String sport) {
    final idx = sports.indexOf(sport);
    if (idx >= 0 && idx < sportIcons.length) {
      return sportIcons[idx];
    }
    return 'football';
  }

  @override
  Widget build(BuildContext context) {
    final joined =
        (ref.watch(localStateProvider).requireValue['communities'] as List)
            .contains(widget.sport);
    final iconName = _getSportIconName(widget.sport);

    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: joined
                      ? accent.withValues(alpha: 0.15)
                      : Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: joined
                        ? accent
                        : Theme.of(context).dividerColor.withValues(alpha: 0.2),
                  ),
                ),
                child: Center(
                  child: FigmaIcon(
                    iconName,
                    color: joined
                        ? accent
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Komunitas ${widget.sport}',
                            style: textStyle(16, weight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (joined) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Tergabung',
                              style: textStyle(
                                10,
                                weight: FontWeight.w700,
                                color: accent,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      joined ? 'Status: Anggota Aktif' : 'Status: Terbuka untuk umum',
                      style: textStyle(11, color: secondary(context)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _getCommunityDescription(widget.sport),
            style: textStyle(12, color: secondary(context)),
          ),
          const SizedBox(height: 14),
          if (joined) ...[
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 42,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: const Color(0xFF171B12),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => context.push(
                        '/community-chat?sport=${Uri.encodeComponent(widget.sport)}',
                      ),
                      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 17),
                      label: Text(
                        'Chat Grup',
                        style: textStyle(13, weight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 42,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.error.withValues(alpha: 0.5),
                          width: 1,
                        ),
                        foregroundColor: Theme.of(context).colorScheme.error,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: busy
                          ? null
                          : () async {
                              setState(() => busy = true);
                              await perform(
                                context,
                                () => ref
                                    .read(localStateProvider.notifier)
                                    .toggleCommunity(widget.sport),
                                success: 'Anda telah keluar dari Komunitas ${widget.sport}.',
                              );
                              if (context.mounted) setState(() => busy = false);
                            },
                      child: busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              'Keluar',
                              style: textStyle(12, weight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            SizedBox(
              height: 42,
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: const Color(0xFF171B12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: busy
                    ? null
                    : () async {
                        setState(() => busy = true);
                        await perform(
                          context,
                          () => ref
                              .read(localStateProvider.notifier)
                              .toggleCommunity(widget.sport),
                          success: 'Selamat! Anda resmi bergabung dengan Komunitas ${widget.sport}.',
                        );
                        if (context.mounted) {
                          setState(() => busy = false);
                          context.push('/community-chat?sport=${Uri.encodeComponent(widget.sport)}');
                        }
                      },
                icon: busy
                    ? const SizedBox.shrink()
                    : const Icon(Icons.group_add_rounded, size: 18),
                label: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        'Gabung Komunitas',
                        style: textStyle(13, weight: FontWeight.w700),
                      ),
              ),
            ),
          ],
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
