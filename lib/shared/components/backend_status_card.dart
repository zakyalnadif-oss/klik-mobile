import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BackendStatusCard extends ConsumerWidget {
  const BackendStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Backend: REST API + PostgreSQL'),
            SizedBox(height: 8),
            Text(
              'Autentikasi menggunakan server API. Pastikan server berjalan di alamat yang dikonfigurasi.',
            ),
          ],
        ),
      ),
    );
  }
}
