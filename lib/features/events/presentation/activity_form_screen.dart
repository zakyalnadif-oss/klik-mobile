import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formatters.dart';
import '../../../data/models/activity.dart';
import '../../../data/providers/local_state.dart';
import '../../../shared/widgets/klik_ui.dart';

class ActivityFormScreen extends ConsumerStatefulWidget {
  const ActivityFormScreen({required this.kind, super.key});
  final String kind;
  @override
  ConsumerState<ActivityFormScreen> createState() => _ActivityFormScreenState();
}

class _ActivityFormScreenState extends ConsumerState<ActivityFormScreen> {
  final form = GlobalKey<FormState>();
  final title = TextEditingController(),
      venue = TextEditingController(),
      capacity = TextEditingController(text: '10'),
      price = TextEditingController(text: '0'),
      description = TextEditingController();
  String sport = 'Futsal', mode = 'Kasual';
  int step = 0;
  bool busy = false, agree = false;
  DateTime day = DateTime.now().add(const Duration(days: 1));
  TimeOfDay time = const TimeOfDay(hour: 19, minute: 0);
  int duration = 120;
  @override
  void dispose() {
    for (final c in [title, venue, capacity, price, description]) {
      c.dispose();
    }
    super.dispose();
  }

  DateTime get starts =>
      DateTime(day.year, day.month, day.day, time.hour, time.minute);
  @override
  Widget build(BuildContext context) => KPage(
    title: widget.kind == 'event' ? 'Buat Event' : 'Buat Ruang',
    children: [
      Row(
        children: List.generate(
          3,
          (i) => Expanded(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: i <= step
                      ? accent
                      : Theme.of(context).colorScheme.surface,
                  child: Text(
                    '${i + 1}',
                    style: textStyle(
                      13,
                      color: i <= step ? const Color(0xFF171B12) : null,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(['Olahraga', 'Jadwal', 'Tinjau'][i], style: textStyle(11)),
              ],
            ),
          ),
        ),
      ),
      Text(
        'Langkah ${step + 1} dari 3',
        style: textStyle(13, color: secondary(context)),
      ),
      Form(
        key: form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (step == 0) ...[
              TextFormField(
                controller: title,
                validator: requiredText,
                maxLength: 80,
                decoration: const InputDecoration(labelText: 'Nama kegiatan'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: sport,
                decoration: const InputDecoration(labelText: 'Olahraga'),
                items: sports
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => setState(() => sport = v!),
              ),
              const SizedBox(height: 16),
              Text(
                'Mode pertandingan',
                style: textStyle(15, weight: FontWeight.w700),
              ),
              Wrap(
                spacing: 8,
                children: [
                  for (final m in ['Kasual', 'Berperingkat'])
                    ChoiceChip(
                      label: Text(m),
                      selected: mode == m,
                      onSelected: (_) => setState(() => mode = m),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Berperingkat memerlukan hasil yang dikonfirmasi kedua pihak. Mode uji coba tidak mengubah poin resmi.',
                style: textStyle(12, color: secondary(context)),
              ),
            ],
            if (step == 1) ...[
              TextFormField(
                controller: venue,
                validator: requiredText,
                maxLength: 120,
                decoration: const InputDecoration(
                  labelText: 'Nama lapangan / lokasi',
                ),
              ),
              const SizedBox(height: 16),
              KCard(
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Tanggal'),
                      subtitle: Text(dayLabel(day)),
                      trailing: const Icon(Icons.calendar_month),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: day,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 730),
                          ),
                        );
                        if (picked != null && mounted) {
                          setState(() => day = picked);
                        }
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Jam mulai'),
                      subtitle: Text(time.format(context)),
                      trailing: const Icon(Icons.schedule),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: time,
                        );
                        if (picked != null && mounted) {
                          setState(() => time = picked);
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: capacity,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Kapasitas peserta (2–100)',
                ),
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  return n == null || n < 2 || n > 100
                      ? 'Masukkan bilangan bulat 2–100'
                      : null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: duration,
                decoration: const InputDecoration(labelText: 'Durasi (menit)'),
                items: [60, 90, 120, 180, 240, 360, 480]
                    .map(
                      (m) =>
                          DropdownMenuItem(value: m, child: Text('$m menit')),
                    )
                    .toList(),
                onChanged: (v) => setState(() => duration = v!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: price,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Biaya per peserta (Rp)',
                ),
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  return n == null || n < 0 || n > 100000000
                      ? 'Masukkan biaya yang valid'
                      : null;
                },
              ),
            ],
            if (step == 2) ...[
              KCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.text,
                      style: textStyle(20, weight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '$sport • $mode\n${venue.text}\n${dayLabel(starts)} • ${timeLabel(starts)}\n${capacity.text} peserta • ${rupiah(int.tryParse(price.text) ?? 0)} / peserta',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: description,
                maxLines: 4,
                maxLength: 1000,
                decoration: const InputDecoration(
                  labelText: 'Deskripsi dan peraturan',
                ),
                validator: requiredText,
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: agree,
                onChanged: (v) => setState(() => agree = v ?? false),
                title: const Text(
                  'Saya memahami kegiatan ini tersimpan lokal dan belum dipublikasikan ke pengguna lain.',
                ),
              ),
            ],
          ],
        ),
      ),
      if (step > 0)
        KButton(
          'Kembali',
          secondary: true,
          onPressed: busy ? null : () => setState(() => step--),
        ),
      KButton(
        step < 2
            ? 'Lanjutkan'
            : 'Terbitkan ${widget.kind == 'event' ? 'Event' : 'Room'} uji coba',
        busy: busy,
        onPressed: step == 2 && !agree
            ? null
            : () async {
                if (!form.currentState!.validate()) return;
                if (step < 2) {
                  setState(() => step++);
                  return;
                }
                if (!starts.isAfter(DateTime.now())) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Pilih jadwal yang belum lewat.'),
                    ),
                  );
                  return;
                }
                setState(() => busy = true);
                final data = ref.read(localStateProvider).requireValue;
                final a = Activity(
                  id: 'local-${DateTime.now().microsecondsSinceEpoch}',
                  kind: widget.kind,
                  title: title.text.trim(),
                  sport: sport,
                  venue: venue.text.trim(),
                  city: data['city'] as String,
                  mode: mode,
                  startsAt: starts,
                  durationMinutes: duration,
                  capacity: int.parse(capacity.text),
                  occupied: 1,
                  price: int.parse(price.text),
                  owner: data['name'] as String,
                  description: description.text.trim(),
                  owned: true,
                );
                try {
                  await ref.read(localStateProvider.notifier).create(a);
                  if (context.mounted) context.replace('/activity/${a.id}');
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Kegiatan belum berhasil disimpan. Coba lagi.',
                        ),
                      ),
                    );
                    setState(() => busy = false);
                  }
                }
              },
      ),
      const LocalNotice(),
    ],
  );
}
