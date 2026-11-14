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
              padding: EdgeInsets.symmetric(
                horizontal: r['highlight'] == true ? 12 : 0,
                vertical: r['highlight'] == true ? 12 : 7,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: r['highlight'] == true
                    ? Border.all(color: accent)
                    : null,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 18,
                    child: Text(
                      '${r['rank']}',
                      textAlign: TextAlign.center,
                      style: textStyle(
                        16,
                        weight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF26262A)
                          : const Color(0xFFECE7DF),
                    ),
                    child: Text(
                      r['initials'] as String,
                      textScaler: TextScaler.noScaling,
                      style: textStyle(12, weight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r['name'] as String,
                          style: textStyle(13, weight: FontWeight.w600),
                        ),
                        Text(
                          r['detail'] as String,
                          style: textStyle(10, color: secondary(context)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        r['points'] as String,
                        softWrap: false,
                        textAlign: TextAlign.right,
                        style: textStyle(
                          17,
                          weight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('Belum ada contoh peringkat untuk pilihan ini.'),
            ),
          const SizedBox(height: 8),
          Text(
            'Contoh dari prototipe Figma • bukan poin atau peringkat resmi.',
            style: textStyle(10, color: secondary(context)),
          ),
        ],
      ),
    );
  }
}
