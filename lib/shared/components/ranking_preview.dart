import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers/local_state.dart';
import '../widgets/klik_ui.dart';

class RankingPreview extends ConsumerWidget {
  const RankingPreview({
    required this.sport,
    this.type = 'Tim',
    this.link = true,
    super.key,
  });
  final String sport, type;
  final bool link;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(localStateProvider).requireValue;
    final rows = ((data['rankings'] as List?) ?? []).cast<Map>().where(
      (r) => r['sport'] == sport && r['type'] == type,
    );
    return KCard(
      padding: 12,
      onTap: link ? () => context.push('/leaderboard') : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Papan Peringkat · $sport',
                  style: textStyle(15, weight: FontWeight.w700),
                ),
              ),
              if (link)
                TextButton(
                  onPressed: () => context.push('/leaderboard'),
                  child: Text(
                    'Lihat peringkat',
                    style: textStyle(11, weight: FontWeight.w700),
                  ),
                ),
            ],
          ),
          for (final r in rows)
            Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: EdgeInsets.symmetric(
                horizontal: r['highlight'] == true ? 10 : 4,
                vertical: r['highlight'] == true ? 10 : 6,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: r['highlight'] == true
                    ? accent.withValues(alpha: 0.08)
                    : null,
                border: r['highlight'] == true
                    ? Border.all(color: accent, width: 1.5)
                    : null,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    child: Text(
                      '${r['rank']}',
                      textAlign: TextAlign.center,
                      style: textStyle(
                        15,
                        weight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  UserAvatar(
                    name: r['name'] as String? ?? '',
                    initials: r['initials'] as String?,
                    size: 32,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r['name'] as String,
                          style: textStyle(13, weight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          r['detail'] as String,
                          style: textStyle(11, color: secondary(context)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    r['points'] as String,
                    textAlign: TextAlign.right,
                    style: textStyle(
                      16,
                      weight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('Belum ada peringkat untuk pilihan ini.'),
            ),
        ],
      ),
    );
  }
}
