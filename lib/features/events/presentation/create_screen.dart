import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/klik_ui.dart';

class CreateScreen extends StatelessWidget {
  const CreateScreen({super.key});
  @override
  Widget build(BuildContext context) => KPage(
    title: 'Buat',
    subtitle: 'Pilih kegiatan yang ingin kamu mulai.',
    children: [
      KCard(
        onTap: () => context.push('/new/room'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.groups_outlined, size: 32),
            const SizedBox(height: 16),
            Text('Buat Room', style: textStyle(20, weight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              'Temukan rekan untuk bermain bersama, kasual atau berperingkat.',
              style: textStyle(13, color: secondary(context)),
            ),
            const SizedBox(height: 20),
            KButton('Buat Ruang', onPressed: () => context.push('/new/room')),
          ],
        ),
      ),
      KCard(
        onTap: () => context.push('/new/event'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.emoji_events_outlined, size: 32),
            const SizedBox(height: 16),
            Text('Buat Event', style: textStyle(20, weight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              'Atur kompetisi dan pertemuan komunitas olahragamu.',
              style: textStyle(13, color: secondary(context)),
            ),
            const SizedBox(height: 20),
            KButton('Buat Event', onPressed: () => context.push('/new/event')),
          ],
        ),
      ),
      const LocalNotice(),
    ],
  );
}
