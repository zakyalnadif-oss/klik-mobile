import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/klik_ui.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) => KPage(
    title: 'klik',
    children: [
      const SizedBox(height: 24),
      Text(
        'Temukan rekan.\nMulai bermain.',
        style: textStyle(40, weight: FontWeight.w800),
      ),
      Text(
        'Olahraga favoritmu, teman baru, dan pertandingan yang adil. Semua berawal dari satu klik.',
        style: textStyle(16, color: secondary(context)),
      ),
      const SizedBox(height: 16),
      KCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.sports_soccer, size: 40, color: accent),
            const SizedBox(height: 20),
            Text(
              'Siap bermain?',
              style: textStyle(24, weight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            const Text(
              'Terhubung langsung ke server database KLIK. Masuk atau daftar akun untuk mulai mencari rekan dan berteman.',
            ),
          ],
        ),
      ),
      KButton(
        'Masuk',
        onPressed: () => context.push('/login'),
      ),
      KButton(
        'Daftar Akun Baru',
        secondary: true,
        onPressed: () => context.push('/register'),
      ),
      const LocalNotice(),
    ],
  );
}
