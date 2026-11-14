import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/design_tokens.dart';
import '../../core/theme/theme_controller.dart';
import 'feature_status.dart';

class FeaturePage extends ConsumerWidget {
  const FeaturePage({
    required this.title,
    required this.description,
    required this.icon,
    this.children = const [],
    super.key,
  });

  final String title;
  final String description;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = Theme.of(context).brightness;
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Ganti tema',
            onPressed: () =>
                ref.read(themeModeProvider.notifier).toggle(brightness),
            icon: Icon(
              brightness == Brightness.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(DesignTokens.pagePadding),
          children: [
            FeatureStatus(title: title, description: description, icon: icon),
            for (final child in children) ...[
              const SizedBox(height: DesignTokens.spacing),
              child,
            ],
          ],
        ),
      ),
    );
  }
}
