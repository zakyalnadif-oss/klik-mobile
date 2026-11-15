import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/providers/local_state.dart';
import '../../../data/models/ranked_match.dart';
import '../../../shared/components/match_result_card.dart';
import '../../../shared/components/activity_card.dart';
import '../../../shared/widgets/klik_ui.dart';

class MatchesScreen extends ConsumerStatefulWidget {
  const MatchesScreen({super.key});
  @override
  ConsumerState<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends ConsumerState<MatchesScreen> {
  String tab = 'Akan Datang';
  @override
  Widget build(BuildContext context) {
    final data = ref.watch(localStateProvider).requireValue;
    final joined = data['joined'] as List, results = data['results'] as Map;
    final activities = activitiesOf(data)
        .where((a) => joined.contains(a.id))
        .toList();
    final shown = activities
        .where(
          (a) => tab == 'Riwayat'
              ? results.containsKey(a.id) || a.startsAt.isBefore(DateTime.now())
              : !results.containsKey(a.id) &&
                    a.startsAt.isAfter(DateTime.now()),
        )
        .toList();
    return KPage(
      title: 'Tanding',
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final name in ['Akan Datang', 'Permintaan', 'Riwayat'])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(name),
                    selected: tab == name,
                    onSelected: (_) => setState(() => tab = name),
                  ),
                ),
            ],
          ),
        ),
        if (tab == 'Permintaan')
          const EmptyState(
            'Belum ada permintaan',
            'Undangan pertandingan dari pengguna lain memerlukan backend yang terhubung.',
          )
        else ...[
          SectionTitle(
            tab == 'Riwayat' ? 'Riwayat pertandingan' : 'Jadwal kamu',
          ),
          Text(
            '${shown.length} pertandingan',
            style: textStyle(12, color: secondary(context)),
          ),
          if (shown.isEmpty)
            EmptyState(
              tab == 'Riwayat' ? 'Belum ada riwayat' : 'Belum ada jadwal',
              'Cari kegiatan atau buat ruang untuk mulai bermain.',
              action: 'Cari ruang',
              onAction: () => context.push('/search'),
            ),
          for (final a in shown) ...[
            ActivityCard(a, joined: true),
            if (results[a.id] != null)
              MatchResultCard(
                result: results[a.id] as Map,
                fixture: RankedMatch.read(data, a.id),
              ),
          ],
        ],
        const LocalNotice(),
      ],
    );
  }
}
