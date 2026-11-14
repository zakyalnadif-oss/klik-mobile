import 'package:material_ui/material_ui.dart';

import '../../../shared/widgets/klik_ui.dart';
import '../../../shared/components/ranking_preview.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});
  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  String sport = 'Futsal', type = 'Tim';
  @override
  Widget build(BuildContext context) => KPage(
    title: 'Papan Peringkat',
    children: [
      Wrap(
        spacing: 8,
        children: [
          for (final t in ['Individu', 'Tim'])
            ChoiceChip(
              label: Text(t),
              selected: type == t,
              onSelected: (_) => setState(() => type = t),
            ),
        ],
      ),
      DropdownButtonFormField<String>(
        initialValue: sport,
        decoration: const InputDecoration(labelText: 'Olahraga'),
        items: sports
            .map((s) => DropdownMenuItem(value: s, child: Text(s)))
            .toList(),
        onChanged: (v) => setState(() => sport = v!),
      ),
      RankingPreview(sport: sport, type: type, link: false),
      const Text(
        'Hasil uji coba tidak mengubah contoh peringkat ini. Peringkat resmi memerlukan backend dan hasil yang dikonfirmasi lawan.',
      ),
      const LocalNotice(),
    ],
  );
}
