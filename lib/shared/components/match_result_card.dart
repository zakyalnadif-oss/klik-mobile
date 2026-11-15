import 'package:material_ui/material_ui.dart';

import '../../data/models/ranked_match.dart';
import '../widgets/klik_ui.dart';

class MatchResultCard extends StatelessWidget {
  const MatchResultCard({required this.result, this.fixture, super.key});
  final Map result;
  final RankedMatch? fixture;
  @override
  Widget build(BuildContext context) {
    final modern = result['schema'] == 2 && fixture?.ready == true;
    final confirmed = modern && result['status'] == 'Disahkan';
    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            result['status'] as String,
            textAlign: TextAlign.center,
            style: textStyle(
              17,
              weight: FontWeight.w800,
              color: confirmed
                  ? const Color(0xFF32965C)
                  : Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          if (modern) ...[
            Text(
              '${fixture!.teamA.name} — ${fixture!.teamB!.name}',
              textAlign: TextAlign.center,
              style: textStyle(13, weight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            for (final team in [fixture!.teamA, fixture!.teamB!]) ...[
              Builder(
                builder: (context) {
                  final submitted =
                      (result['submissions'] as Map)[team.captainId] as Map?;
                  return Text(
                    '${team.captainName} (${team.name})\n${submitted == null ? 'Belum mengisi skor' : '${submitted['scoreA']} – ${submitted['scoreB']}'}',
                    style: textStyle(13),
                  );
                },
              ),
              const SizedBox(height: 12),
            ],
          ],
          if (confirmed || !modern)
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${result['own']} – ${result['other']}',
                style: textStyle(32, weight: FontWeight.w800),
              ),
            ),
          if (modern && result['status'] == 'Skor berbeda')
            const Text(
              'Skor kedua ketua belum sama. Masing-masing ketua dapat memperbaiki inputnya; hasil belum disahkan.',
            ),
          if (confirmed)
            const Text(
              'Kedua ketua memasukkan skor yang sama. Hasil telah disahkan pada data lokal. Poin resmi belum berubah.',
            ),
          if (!modern)
            const Text(
              'Catatan hasil versi sebelumnya. Poin resmi belum berubah.',
            ),
        ],
      ),
    );
  }
}
