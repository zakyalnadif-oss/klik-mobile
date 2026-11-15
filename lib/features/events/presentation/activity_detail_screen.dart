import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formatters.dart';
import '../../../data/providers/local_state.dart';
import '../../../data/models/ranked_match.dart';
import '../../../features/tanding/logic/match_rules.dart';
import '../../../shared/components/match_result_card.dart';
import '../../../shared/widgets/klik_ui.dart';

class ActivityDetailScreen extends ConsumerStatefulWidget {
  const ActivityDetailScreen({required this.id, super.key});
  final String id;
  @override
  ConsumerState<ActivityDetailScreen> createState() =>
      _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends ConsumerState<ActivityDetailScreen> {
  bool busy = false;
  @override
  Widget build(BuildContext context) {
    final data = ref.watch(localStateProvider).requireValue;
    final matches = activitiesOf(data).where((a) => a.id == widget.id);
    if (matches.isEmpty) {
      return const KPage(
        title: 'Kegiatan tidak ditemukan',
        children: [
          EmptyState(
            'Kegiatan tidak tersedia',
            'Kembali dan pilih kegiatan lain.',
          ),
        ],
      );
    }
    final a = matches.first,
        joined = (data['joined'] as List).contains(widget.id);
    final result = (data['results'] as Map)[a.id] as Map?;
    final ranked = MatchRules.rankedRoom(a);
    final fixture = RankedMatch.read(data, a.id);
    final captain = MatchRules.isCaptain(data, a.id);
    return KPage(
      title: a.isEvent ? 'Detail Event' : 'Detail Ruang',
      children: [
        if (a.sport == 'Futsal')
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: AspectRatio(
              aspectRatio: 308 / 190,
              child: Image.asset('assets/figma/futsal.png', fit: BoxFit.cover),
            ),
          ),
        Row(
          children: [KBadge(a.sport), const SizedBox(width: 8), KBadge(a.mode)],
        ),
        Text(a.title, style: textStyle(26, weight: FontWeight.w800)),
        Text(
          'Oleh ${a.owner}',
          style: textStyle(12, color: secondary(context)),
        ),
        KCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today_outlined),
                title: Text(dayLabel(a.startsAt)),
                subtitle: Text(
                  '${timeLabel(a.startsAt)}–${timeLabel(a.endsAt)} • Waktu perangkat',
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.location_on_outlined),
                title: Text(a.venue),
                subtitle: Text(a.city),
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    context.push('/venue/${Uri.encodeComponent(a.venue)}'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.people_outline),
                title: Text('${a.occupied}/${a.capacity} peserta'),
                subtitle: Text('${a.remaining} slot tersedia'),
              ),
              Text(
                '${rupiah(a.price)} / peserta',
                style: textStyle(18, weight: FontWeight.w700),
              ),
            ],
          ),
        ),
        Text('Tentang kegiatan', style: textStyle(18, weight: FontWeight.w700)),
        Text(a.description),
        Text(
          'Jadwal dan peraturan',
          style: textStyle(18, weight: FontWeight.w700),
        ),
        Text(
          'Datang 30 menit sebelum kegiatan. Bawa perlengkapan pribadi. Hormati peserta lain dan keputusan penyelenggara.',
          style: textStyle(13, color: secondary(context)),
        ),
        if (ranked) ...[
          const SectionTitle('Tim pertandingan'),
          KCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fixture == null
                      ? 'Tim A belum terdaftar'
                      : '${fixture.teamA.name} • Ketua: ${fixture.teamA.captainName}',
                ),
                const SizedBox(height: 12),
                Text(
                  fixture?.teamB == null
                      ? 'Menunggu tim lawan'
                      : '${fixture!.teamB!.name} • Ketua: ${fixture.teamB!.captainName}',
                ),
              ],
            ),
          ),
          KButton(
            'Tim dan ketua pertandingan',
            secondary: true,
            onPressed: () => context.push('/match-teams/${a.id}'),
          ),
          if (fixture?.ready != true)
            const Text(
              'Input hasil tersedia setelah kedua ketua terdaftar dan pertandingan selesai.',
            ),
        ],
        if (joined)
          KCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  color: Color(0xFF32965C),
                ),
                const SizedBox(height: 8),
                Text(
                  'Kamu sudah bergabung',
                  style: textStyle(16, weight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  'Pendaftaran ini hanya untuk uji coba di perangkat. Tidak ada reservasi lapangan atau pembayaran nyata.',
                  style: textStyle(12, color: secondary(context)),
                ),
              ],
            ),
          ),
        if (result != null) MatchResultCard(result: result, fixture: fixture),
        if (!joined)
          KButton(
            a.remaining == 0
                ? 'Kegiatan penuh'
                : a.isEvent
                ? 'Daftar Event'
                : 'Gabung Ruang',
            busy: busy,
            onPressed: a.remaining == 0
                ? null
                : () async {
                    if (a.price > 0) {
                      context.push('/checkout/${a.id}');
                      return;
                    }
                    if (!await confirmAction(
                      context,
                      a.isEvent ? 'Tinjau pendaftaran' : 'Gabung ruang ini?',
                      'Pertandingan ini gratis. Lanjutkan bergabung?',
                    )) {
                      return;
                    }
                    if (!context.mounted) return;
                    setState(() => busy = true);
                    await perform(
                      context,
                      () => ref.read(localStateProvider.notifier).join(a.id),
                      success: 'Berhasil bergabung dalam uji coba lokal.',
                    );
                    if (context.mounted) setState(() => busy = false);
                  },
          ),
        if (captain &&
            result?['status'] != 'Disahkan' &&
            (result == null || result['schema'] == 2))
          KButton(
            ((result?['submissions'] as Map?)?.containsKey(
                      localPlayerId(data),
                    ) ??
                    false)
                ? 'Perbarui skor saya'
                : 'Input hasil pertandingan',
            onPressed: DateTime.now().isBefore(a.endsAt)
                ? null
                : () => context.push('/score/${a.id}'),
          ),
        if (captain &&
            result?['status'] != 'Disahkan' &&
            DateTime.now().isBefore(a.endsAt))
          Text(
            'Input hasil tersedia setelah ${dayLabel(a.endsAt)} pukul ${timeLabel(a.endsAt)}.',
            style: textStyle(12, color: secondary(context)),
          ),
        if (joined && !a.owned && result == null)
          KButton(
            'Keluar dari kegiatan',
            secondary: true,
            busy: busy,
            onPressed: () async {
              if (!await confirmAction(
                context,
                'Keluar dari kegiatan?',
                'Slotmu akan tersedia kembali.',
              )) {
                return;
              }
              if (!context.mounted) return;
              setState(() => busy = true);
              await perform(
                context,
                () => ref.read(localStateProvider.notifier).leave(a.id),
              );
              if (context.mounted) setState(() => busy = false);
            },
          ),
        const LocalNotice(),
      ],
    );
  }
}
