import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formatters.dart';
import '../../../data/providers/local_state.dart';
import '../../../shared/widgets/klik_ui.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});
  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final form = GlobalKey<FormState>();
  late TextEditingController name, city;
  late String sport, level;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    final j = ref.read(localStateProvider).requireValue;
    name = TextEditingController(text: j['name'] as String);
    city = TextEditingController(text: j['city'] as String);
    sport = j['sport'] as String;
    level = j['level'] as String;
  }

  @override
  void dispose() {
    name.dispose();
    city.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => KPage(
    title: 'Edit profil',
    children: [
      Form(
        key: form,
        child: Column(
          children: [
            TextFormField(
              controller: name,
              maxLength: 50,
              validator: requiredText,
              decoration: const InputDecoration(labelText: 'Nama pemain'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: city,
              maxLength: 80,
              validator: requiredText,
              decoration: const InputDecoration(labelText: 'Domisili'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: sport,
              decoration: const InputDecoration(labelText: 'Olahraga favorit'),
              items: sports
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() => sport = v!),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: level,
              decoration: const InputDecoration(labelText: 'Tingkat bermain'),
              items: [
                'Pemula',
                'Menengah',
                'Mahir',
              ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) => setState(() => level = v!),
            ),
          ],
        ),
      ),
      KButton(
        'Simpan perubahan',
        busy: busy,
        onPressed: () async {
          if (!form.currentState!.validate()) return;
          setState(() => busy = true);
          try {
            await ref
                .read(localStateProvider.notifier)
                .profile(name.text, city.text, sport, level);
            if (context.mounted) context.pop();
          } catch (_) {
            if (context.mounted) {
              setState(() => busy = false);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Profil belum berhasil disimpan.'),
                ),
              );
            }
          }
        },
      ),
      const LocalNotice(),
    ],
  );
}
