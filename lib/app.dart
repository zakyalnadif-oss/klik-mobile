import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/routes/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'data/providers/local_state.dart';

class KlikApp extends ConsumerWidget {
  const KlikApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: 'KLIK',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: ref.watch(themeModeProvider),
    routerConfig: ref.watch(appRouterProvider),
    builder: (context, child) => ref
        .watch(localStateProvider)
        .when(
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (e, st) => Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.storage_outlined, size: 40),
                      const SizedBox(height: 16),
                      const Text(
                        'Data perangkat belum bisa dimuat. Data lama tetap disimpan.',
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => ref.invalidate(localStateProvider),
                        child: const Text('Coba lagi'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          data: (_) => AnnotatedRegion<SystemUiOverlayStyle>(
            value:
                (Theme.of(context).brightness == Brightness.dark
                        ? SystemUiOverlayStyle.light
                        : SystemUiOverlayStyle.dark)
                    .copyWith(
                      statusBarColor: Colors.transparent,
                      systemNavigationBarColor: Theme.of(context)
                          .scaffoldBackgroundColor,
                    ),
            child: child ?? const SizedBox.shrink(),
          ),
        ),
  );
}
