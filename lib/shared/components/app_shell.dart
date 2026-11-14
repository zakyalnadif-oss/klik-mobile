import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

import '../widgets/klik_ui.dart';

class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});
  final StatefulNavigationShell navigationShell;
  @override
  Widget build(BuildContext context) {
    const names = ['Beranda', 'Sosial', 'Buat', 'Tanding', 'Profil'];
    const icons = ['home', 'social', 'plus', 'matches', 'profile'];
    return Scaffold(
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Container(
            key: const ValueKey('main-navigation'),
            height: navigationHeight(context),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Row(
              children: List.generate(
                5,
                (i) => Expanded(
                  child: Semantics(
                    key: ValueKey('tab-${icons[i]}'),
                    selected: navigationShell.currentIndex == i,
                    button: true,
                    label: names[i],
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => navigationShell.goBranch(
                        i,
                        initialLocation: i == navigationShell.currentIndex,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: i == 2 ? 42 : 34,
                            height: 30,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: i == 2 ? accent : Colors.transparent,
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: FigmaIcon(
                              icons[i],
                              color: i == 2
                                  ? const Color(0xFF171B12)
                                  : navigationShell.currentIndex == i
                                  ? Theme.of(context).colorScheme.primary
                                  : secondary(context),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            names[i],
                            textAlign: TextAlign.center,
                            style: textStyle(
                              10,
                              weight: navigationShell.currentIndex == i
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: navigationShell.currentIndex == i
                                  ? Theme.of(context).colorScheme.primary
                                  : secondary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
