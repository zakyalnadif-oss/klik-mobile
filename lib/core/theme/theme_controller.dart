import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/local_state.dart';

final themeModeProvider = NotifierProvider<ThemeController, ThemeMode>(
  ThemeController.new,
);

class ThemeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final mode = ref.watch(
      localStateProvider.select((s) => s.asData?.value['theme']),
    );
    return ThemeMode.values.firstWhere(
      (m) => m.name == mode,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> select(ThemeMode mode) async {
    final previous = state;
    state = mode;
    try {
      await ref
          .read(localStateProvider.notifier)
          .change((j) => j['theme'] = mode.name);
    } catch (_) {
      state = previous;
      rethrow;
    }
  }

  Future<void> toggle(Brightness current) =>
      select(current == Brightness.dark ? ThemeMode.light : ThemeMode.dark);
}
