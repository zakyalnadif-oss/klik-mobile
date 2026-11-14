import 'package:material_ui/material_ui.dart';

import '../../core/utils/formatters.dart';
import '../../data/models/activity.dart';
import '../widgets/klik_ui.dart';

class ActivityCard extends StatelessWidget {
  const ActivityCard(
    this.activity, {
    this.joined = false,
    this.fillHeight = false,
    super.key,
  });
  final Activity activity;
  final bool joined, fillHeight;

  Widget _footer(BuildContext context, List<Widget> children) {
    final stack =
        MediaQuery.sizeOf(context).width < 360 &&
        MediaQuery.textScalerOf(context).scale(11) > 16;
    return SizedBox(
      width: double.infinity,
      child: stack
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                children.first,
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerRight, child: children.last),
              ],
            )
          : Row(
              children: [
                Expanded(child: children.first),
                const SizedBox(width: 10),
                children.last,
              ],
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = activity;
    return KCard(
      padding: a.isEvent ? 12 : 14,
      onTap: () => openActivity(context, a.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (a.isEvent && a.sport == 'Futsal') ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 308 / 190,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset('assets/figma/futsal.png', fit: BoxFit.cover),
                    Positioned(
                      top: 12,
                      left: 12,
                      child: KBadge(a.sport.toUpperCase()),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  a.title,
                  style: textStyle(
                    a.isEvent ? 14 : 15,
                    weight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (a.isEvent)
                Flexible(
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Text(
                      '${rupiah(a.price)} / peserta',
                      textAlign: TextAlign.right,
                      style: textStyle(
                        10,
                        weight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                )
              else
                Flexible(
                  child: Align(
                    alignment: Alignment.topRight,
                    child: KBadge(
                      a.mode,
                      key: ValueKey('activity-mode-${a.id}'),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${a.sport} • ${a.isEvent ? 'Turnamen kompetitif' : a.mode}',
            style: textStyle(11, color: secondary(context)),
          ),
          const SizedBox(height: 6),
          Text(
            '${dayLabel(a.startsAt)} • ${timeLabel(a.startsAt)}\n${a.venue}${a.isEvent ? ' • Oleh ${a.owner}' : ''}',
            style: textStyle(11, color: secondary(context)),
          ),
          if (fillHeight) const Spacer(),
          const SizedBox(height: 12),
          _footer(context, [
            SizedBox(
              width: 140,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (a.isEvent)
                    Text(
                      'Pendaftaran Dibuka',
                      style: textStyle(
                        10,
                        weight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  if (a.isEvent)
                    Text(
                      '${a.occupied}/${a.capacity} peserta',
                      style: textStyle(10, color: secondary(context)),
                    )
                  else
                    Row(
                      children: [
                        const FigmaIcon('status'),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: '${a.remaining} slot',
                                  style: textStyle(12),
                                ),
                                TextSpan(
                                  text: ' tersisa',
                                  style: textStyle(
                                    11,
                                    color: secondary(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            FilledButton(
              key: ValueKey('activity-action-${a.id}'),
              onPressed: () => openActivity(context, a.id),
              child: Text(
                a.isEvent
                    ? (joined ? 'Lihat Detail' : 'Lihat Acara')
                    : 'Gabung',
                style: textStyle(11, weight: FontWeight.w600),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
