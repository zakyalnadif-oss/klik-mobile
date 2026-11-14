import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/providers/local_state.dart';
import '../../../shared/widgets/klik_ui.dart';

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

  @override
  Widget build(BuildContext context) {
    final j = ref.watch(localStateProvider).requireValue;
    final found = activitiesOf(j).where((a) => a.id == widget.id);
    if (found.isEmpty || !found.first.owned) {
      return const KPage(
        title: 'Input hasil',
        children: [
          EmptyState(
            'Tidak memiliki wewenang',
            'Hanya pembuat kegiatan yang dapat mengirim hasil.',
          ),
        ],
      );
    }
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: own,
                        validator: validate,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Tim kamu',
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.all(14),
                      child: Text('–'),
                    ),
                    Expanded(
                      child: TextFormField(
                        controller: other,
                        validator: validate,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Tim lawan',
                        ),
                      ),
                    ),
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
            'Saya mengisi skor yang benar dan memahami hasil harus dikonfirmasi lawan.',
          ),
        ),
        KButton(
          'Kirim hasil',
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
        const Text(
          'Dalam mode lokal, hasil tetap menunggu konfirmasi dan tidak mengubah poin resmi.',
        ),
        const LocalNotice(),
      ],
    );
  }
}
