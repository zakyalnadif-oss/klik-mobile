import 'dart:convert';

import 'package:material_ui/material_ui.dart';

import '../../../data/models/activity.dart';
import '../../../data/models/ranked_match.dart';
import '../../../shared/components/match_result_card.dart';
import '../../../shared/widgets/klik_ui.dart';
import '../logic/match_rules.dart';

class ScoreExampleScreen extends StatefulWidget {
  const ScoreExampleScreen({super.key});
  @override
  State<ScoreExampleScreen> createState() => _ScoreExampleScreenState();
}

class _ScoreExampleScreenState extends State<ScoreExampleScreen> {
  static const id = 'example-ranked-score';
  final scoreA = TextEditingController(), scoreB = TextEditingController();
  late Map<String, dynamic> data;
  bool captainA = true;
  @override
  void initState() {
    super.initState();
    _reset();
  }

  @override
  void dispose() {
    scoreA.dispose();
    scoreB.dispose();
    super.dispose();
  }

  void _reset() {
    final fixture = const RankedMatch(
      teamA: MatchTeam(
        id: 'example-red',
        name: 'Tim Merah',
        captainId: 'example-captain-a',
        captainName: 'Ketua Merah',
      ),
      teamB: MatchTeam(
        id: 'example-blue',
        name: 'Tim Biru',
        captainId: 'example-captain-b',
        captainName: 'Ketua Biru',
      ),
    );
    data = {
      'playerId': 'example-captain-a',
      'joined': [id],
      'results': <String, dynamic>{},
      'rankedMatches': {id: fixture.toJson()},
      'activities': [
        Activity(
          id: id,
          kind: 'room',
          title: 'Contoh room Berperingkat',
          sport: 'Futsal',
          venue: 'Lapangan contoh',
          city: 'Jakarta',
          mode: 'Berperingkat',
          startsAt: DateTime.now().subtract(const Duration(hours: 3)),
          capacity: 10,
          occupied: 10,
          price: 0,
          owner: 'Penyelenggara contoh',
          description: 'Contoh input dua ketua',
          demo: true,
        ).toJson(),
      ],
    };
    captainA = true;
    scoreA.clear();
    scoreB.clear();
  }

  void _select(bool first) {
    setState(() {
      captainA = first;
      data['playerId'] = first ? 'example-captain-a' : 'example-captain-b';
      final result = (data['results'] as Map)[id] as Map?;
      final input = (result?['submissions'] as Map?)?[data['playerId']] as Map?;
      scoreA.text = input?['scoreA']?.toString() ?? '';
      scoreB.text = input?['scoreB']?.toString() ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final fixture = RankedMatch.read(data, id)!;
    final result = (data['results'] as Map)[id] as Map?;
    final locked = result?['status'] == 'Disahkan';
    return KPage(
      title: 'Contoh input dua ketua',
      children: [
        const Text(
          'Ruang contoh untuk menguji dua ketua pada perangkat ini. Contoh ini tidak mengubah pertandingan atau peran pada room kamu.',
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Ketua Tim Merah'),
              selected: captainA,
              onSelected: (_) => _select(true),
            ),
            ChoiceChip(
              label: const Text('Ketua Tim Biru'),
              selected: !captainA,
              onSelected: (_) => _select(false),
            ),
          ],
        ),
        if (result != null) MatchResultCard(result: result, fixture: fixture),
        if (!locked) ...[
          const Text(
            'Isi sesuai urutan: Tim Merah, lalu Tim Biru. Ketua lawan mengisi dengan urutan yang sama.',
          ),
          TextFormField(
            controller: scoreA,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Skor Tim Merah'),
          ),
          TextFormField(
            controller: scoreB,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Skor Tim Biru'),
          ),
          KButton(
            'Kirim skor ketua',
            onPressed: () {
              final first = int.tryParse(scoreA.text),
                  second = int.tryParse(scoreB.text);
              if (first == null || second == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Isi skor berupa bilangan bulat 0–999.'),
                  ),
                );
                return;
              }
              try {
                final next =
                    jsonDecode(jsonEncode(data)) as Map<String, dynamic>;
                MatchRules.submit(next, id, first, second, DateTime.now());
                setState(() => data = next);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      e is StateError
                          ? e.message
                          : e is ArgumentError
                          ? e.message.toString()
                          : 'Periksa skor.',
                    ),
                  ),
                );
              }
            },
          ),
        ],
        KButton(
          'Ulangi contoh',
          secondary: true,
          onPressed: () => setState(_reset),
        ),
      ],
    );
  }
}
