import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../data/models/ranked_match.dart';
import '../../../data/providers/local_state.dart';
import '../../../shared/widgets/klik_ui.dart';
import '../logic/match_rules.dart';

class MatchTeamsScreen extends ConsumerStatefulWidget {
  const MatchTeamsScreen({required this.id, super.key});
  final String id;
  @override
  ConsumerState<MatchTeamsScreen> createState() => _MatchTeamsScreenState();
}

class _MatchTeamsScreenState extends ConsumerState<MatchTeamsScreen> {
  final _name = TextEditingController();
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _name.text =
        ref.read(localStateProvider).requireValue['teamName'] as String? ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(localStateProvider).requireValue;
    final a = MatchRules.activityOf(data, widget.id);
    if (a == null || !MatchRules.rankedRoom(a)) {
      return const KPage(
        title: 'Tim pertandingan',
        children: [
          EmptyState(
            'Tidak tersedia',
            'Pendaftaran dua tim hanya tersedia di room Berperingkat.',
          ),
        ],
      );
    }
    final fixture = RankedMatch.read(data, widget.id);
    final mine = fixture?.teamFor(localPlayerId(data));
    final joined = (data['joined'] as List).contains(widget.id);
    final before = DateTime.now().isBefore(a.startsAt);
    final canRegister =
        joined &&
        before &&
        mine == null &&
        ((fixture == null && a.owned) ||
            (fixture != null && fixture.teamB == null));
    return KPage(
      title: 'Tim pertandingan',
      subtitle: a.title,
      children: [
        for (final side in [0, 1])
          KCard(
            child: Builder(
              builder: (context) {
                final team = side == 0 ? fixture?.teamA : fixture?.teamB;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      side == 0 ? 'Tim A' : 'Tim B',
                      style: textStyle(15, weight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(team?.name ?? 'Belum terdaftar'),
                    if (team != null) Text('Ketua: ${team.captainName}'),
                  ],
                );
              },
            ),
          ),
        if (mine != null) Text('Kamu terdaftar sebagai ketua ${mine.name}.'),
        if (canRegister) ...[
          TextFormField(
            controller: _name,
            maxLength: 60,
            decoration: const InputDecoration(labelText: 'Nama tim kamu'),
          ),
          const Text(
            'Kamu akan didaftarkan sebagai ketua tim ini. Ketua kedua tim harus berbeda.',
          ),
          KButton(
            'Daftarkan tim saya',
            busy: _busy,
            onPressed: () async {
              setState(() => _busy = true);
              await perform(
                context,
                () => ref
                    .read(localStateProvider.notifier)
                    .registerMatchTeam(widget.id, _name.text),
                success: 'Tim dan ketua terdaftar.',
              );
              if (mounted) setState(() => _busy = false);
            },
          ),
        ],
        if (!joined)
          const Text('Gabung room terlebih dahulu untuk mendaftarkan tim.'),
        if (!before)
          const Text(
            'Pendaftaran ketua tim sudah ditutup karena pertandingan telah dimulai.',
          ),
        const Text(
          'Hanya ketua kedua tim terdaftar yang dapat mengisi skor, setelah pertandingan selesai.',
        ),
        const LocalNotice(),
      ],
    );
  }
}
