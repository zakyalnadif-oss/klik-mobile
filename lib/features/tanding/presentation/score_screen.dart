import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/providers/local_state.dart';
import '../../../data/models/ranked_match.dart';
import '../../../shared/components/match_result_card.dart';
import '../../../shared/widgets/klik_ui.dart';
import '../logic/match_rules.dart';

class ScoreScreen extends ConsumerStatefulWidget {
  const ScoreScreen({required this.id, super.key});
  final String id;
  @override
  ConsumerState<ScoreScreen> createState() => _ScoreScreenState();
}

class _ScoreScreenState extends ConsumerState<ScoreScreen> {
  final form = GlobalKey<FormState>(),
      own = TextEditingController(),
      other = TextEditingController();
  bool busy = false, agree = false;
  @override
  void dispose() {
    own.dispose();
    other.dispose();
    super.dispose();
  }

  String? validate(String? v) {
    final n = int.tryParse(v ?? '');
    return n == null || n < 0 || n > 999 ? 'Isi bilangan bulat 0–999' : null;
  }

  Widget scoreField(TextEditingController controller, String team) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(team, style: textStyle(14, weight: FontWeight.w700)),
      const SizedBox(height: 8),
      TextFormField(
        controller: controller,
        validator: validate,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Skor'),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final j = ref.watch(localStateProvider).requireValue;
    final found = activitiesOf(j).where((a) => a.id == widget.id);
    final reason = MatchRules.denial(j, widget.id, DateTime.now());
    if (reason != null) {
      return KPage(
        title: 'Input hasil',
        children: [EmptyState('Tidak memiliki wewenang', reason)],
      );
    }
    final fixture = RankedMatch.read(j, widget.id)!;
    final result = (j['results'] as Map)[widget.id] as Map?;
    if (result?['status'] == 'Disahkan') {
      return KPage(
        title: 'Hasil pertandingan',
        children: [
          MatchResultCard(result: result!, fixture: fixture),
          const Text('Skor yang telah disahkan tidak dapat diubah.'),
        ],
      );
    }
    final submitted =
        (result?['submissions'] as Map?)?.containsKey(localPlayerId(j)) ??
        false;
    final fieldA = scoreField(own, 'Tim A • ${fixture.teamA.name}');
    final fieldB = scoreField(other, 'Tim B • ${fixture.teamB!.name}');
    final stacked =
        MediaQuery.sizeOf(context).width < 360 ||
        MediaQuery.textScalerOf(context).scale(14) > 20;
    return KPage(
      title: 'Input hasil',
      subtitle: found.first.title,
      children: [
        KCard(
          child: Form(
            key: form,
            child: Column(
              children: [
                Text(
                  'Skor akhir',
                  style: textStyle(20, weight: FontWeight.w800),
                ),
                const SizedBox(height: 20),
                if (stacked)
                  Column(children: [fieldA, const SizedBox(height: 16), fieldB])
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: fieldA),
                      const Padding(
                        padding: EdgeInsets.all(14),
                        child: Text('–'),
                      ),
                      Expanded(child: fieldB),
                    ],
                  ),
              ],
            ),
          ),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: agree,
          onChanged: (v) => setState(() => agree = v ?? false),
          title: const Text(
            'Saya mengisi skor sesuai urutan nama tim. Hasil akan dibandingkan dengan input ketua lawan.',
          ),
        ),
        KButton(
          submitted ? 'Perbarui skor saya' : 'Kirim hasil',
          busy: busy,
          onPressed: !agree
              ? null
              : () async {
                  if (!form.currentState!.validate()) return;
                  setState(() => busy = true);
                  try {
                    await ref
                        .read(localStateProvider.notifier)
                        .submitScore(
                          widget.id,
                          int.parse(own.text),
                          int.parse(other.text),
                        );
                    if (context.mounted) {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/activity/${widget.id}');
                      }
                    }
                  } catch (e) {
                    if (context.mounted) {
                      setState(() => busy = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            e is StateError
                                ? e.message
                                : 'Hasil belum tersimpan.',
                          ),
                        ),
                      );
                    }
                  }
                },
        ),
        if (result != null) MatchResultCard(result: result, fixture: fixture),
        const Text(
          'Hasil disahkan jika kedua ketua mengisi skor yang sama. Poin resmi belum berubah pada mode lokal.',
        ),
        const LocalNotice(),
      ],
    );
  }
}
