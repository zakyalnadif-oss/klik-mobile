import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/providers/local_state.dart';
import '../../../shared/widgets/klik_ui.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(localStateProvider).requireValue;
    final joined = data['joined'] as List;
    final items = activitiesOf(data)
        .where((a) => joined.contains(a.id))
        .toList();
    return KPage(
      title: 'Notifikasi',
      children: [
        if (items.isEmpty)
          const EmptyState(
            'Belum ada notifikasi',
            'Kegiatan yang kamu ikuti akan tampil di sini.',
          ),
        for (final a in items)
          KCard(
            onTap: () => context.push('/activity/${a.id}'),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_available_outlined),
              title: Text('Kamu bergabung: ${a.title}'),
              subtitle: const Text('Catatan lokal • bukan push notification'),
            ),
          ),
        const LocalNotice(),
      ],
    );
  }
}
