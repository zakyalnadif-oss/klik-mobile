import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers/local_state.dart';
import '../widgets/klik_ui.dart';

class RankingPreview extends ConsumerStatefulWidget {
  const RankingPreview({
    required this.sport,
    this.type = 'Tim',
    this.link = true,
    super.key,
  });
  final String sport, type;
  final bool link;

  @override
  ConsumerState<RankingPreview> createState() => _RankingPreviewState();
}

class _RankingPreviewState extends ConsumerState<RankingPreview> {
  String? _hoveredName;

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(localStateProvider).requireValue;
    final rows = ((data['rankings'] as List?) ?? []).cast<Map>().where(
      (r) => r['sport'] == widget.sport && r['type'] == widget.type,
    );
    return KCard(
      padding: 12,
      onTap: widget.link ? () => context.push('/leaderboard') : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Papan Peringkat · ${widget.sport}',
                  style: textStyle(15, weight: FontWeight.w700),
                ),
              ),
              if (widget.link)
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
            Builder(
              builder: (context) {
                final name = r['name'] as String? ?? '';
                final isHighlighted = _hoveredName == name;

                return MouseRegion(
                  cursor: SystemMouseCursors.click,
                  onEnter: (_) => setState(() => _hoveredName = name),
                  onExit: (_) => setState(() {
                    if (_hoveredName == name) _hoveredName = null;
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeInOut,
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: isHighlighted
                          ? accent.withValues(alpha: 0.08)
                          : Colors.transparent,
                      border: Border.all(
                        color: isHighlighted ? accent : Colors.transparent,
                        width: 1.5,
                      ),
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
                          name: name,
                          initials: r['initials'] as String?,
                          size: 32,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: textStyle(13, weight: FontWeight.w700),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                r['detail'] as String? ?? '',
                                style: textStyle(11, color: secondary(context)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          r['points'] as String? ?? '0',
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
                );
              },
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
