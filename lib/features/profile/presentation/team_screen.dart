import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../data/providers/local_state.dart';
import '../../../shared/widgets/klik_ui.dart';

class TeamScreen extends ConsumerStatefulWidget {
  const TeamScreen({super.key});
  @override
  ConsumerState<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends ConsumerState<TeamScreen> {
  final form = GlobalKey<FormState>();
  late TextEditingController name;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    name = TextEditingController(
      text:
          ref.read(localStateProvider).requireValue['teamName'] as String? ??
          '',
    );
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(localStateProvider).requireValue;
    return KPage(
      title: 'Tim Saya',
      children: [
        Form(
          key: form,
          child: TextFormField(
            controller: name,
            maxLength: 60,
            validator: requiredText,
            decoration: const InputDecoration(labelText: 'Nama tim'),
          ),
        ),
        KButton(
          'Simpan tim',
          busy: busy,
          onPressed: () async {
            if (!form.currentState!.validate()) return;
            setState(() => busy = true);
            await perform(
              context,
              () => ref
                  .read(localStateProvider.notifier)
                  .change((j) => j['teamName'] = name.text.trim()),
              success: 'Tim tersimpan di perangkat.',
            );
            if (context.mounted) setState(() => busy = false);
          },
        ),
        KCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Kapten: ${data['name']}',
                style: textStyle(16, weight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              const Text(
                '1 anggota lokal. Undangan dan penerimaan anggota lain memerlukan database PostgreSQL yang terhubung. Tim belum dapat mengikuti pertandingan resmi.',
              ),
            ],
          ),
        ),
        const LocalNotice(),
      ],
    );
  }
}
