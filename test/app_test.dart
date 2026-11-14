import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klik_mobile/app.dart';
import 'package:klik_mobile/data/models/activity.dart';
import 'package:klik_mobile/data/providers/local_state.dart';
import 'package:klik_mobile/data/repositories/local_repository.dart';
import 'package:klik_mobile/features/home/presentation/home_screen.dart';

class MemoryRepository extends LocalRepository {
  MemoryRepository({bool onboarded = true})
    : record = {
        'version': 2,
        'onboarded': onboarded,
        'name': 'Pemain KLIK',
        'city': 'Jakarta Selatan',
        'sport': 'Futsal',
        'level': 'Menengah',
        'theme': 'light',
        'activities': [
          Activity(
            id: 'test-room',
            kind: 'room',
            title: 'Futsal Cilandak',
            sport: 'Futsal',
            venue: 'Cilandak',
            city: 'Jakarta Selatan',
            mode: 'Kasual',
            startsAt: DateTime.now().add(const Duration(days: 1)),
            capacity: 10,
            occupied: 1,
            price: 0,
            owner: 'Demo',
            description: 'Data uji',
          ).toJson(),
        ],
        'players': <Map<String, dynamic>>[],
        'venues': <Map<String, dynamic>>[],
        'joined': <String>[],
        'friends': <String>[],
        'requested': <String>[],
        'communities': <String>[],
        'results': <String, dynamic>{},
      };
  Map<String, dynamic> record;
  bool rejectWrite = false;
  @override
  Future<Map<String, dynamic>> load() async =>
      jsonDecode(jsonEncode(record)) as Map<String, dynamic>;
  @override
  Future<void> save(Map<String, dynamic> value) async {
    if (rejectWrite) throw StateError('Disk unavailable');
    record = jsonDecode(jsonEncode(value)) as Map<String, dynamic>;
  }
}

Widget app(MemoryRepository repository) => ProviderScope(
  overrides: [localRepositoryProvider.overrideWithValue(repository)],
  child: const KlikApp(),
);
void main() {
  testWidgets('five primary tabs, secondary search, and persistent dark mode', (
    tester,
  ) async {
    final repository = MemoryRepository();
    await tester.pumpWidget(app(repository));
    await tester.pumpAndSettle();
    for (final key in ['home', 'social', 'plus', 'matches', 'profile']) {
      expect(find.byKey(ValueKey('tab-$key')), findsOneWidget);
    }
    await tester.tap(find.text('Cari ruang, pemain, lapangan, acara…'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('main-navigation')), findsNothing);
    expect(find.text('Pencarian'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    for (final key in ['social', 'plus', 'matches', 'profile', 'home']) {
      await tester.tap(find.byKey(ValueKey('tab-$key')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    await tester.tap(find.byTooltip('Ganti tema'));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(HomeScreen))).brightness,
      Brightness.dark,
    );
    expect(repository.record['theme'], 'dark');
    expect(tester.takeException(), isNull);
  });
  testWidgets('small viewport and 200 percent text do not overflow the tabs', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(app(MemoryRepository()));
    await tester.pumpAndSettle();
    for (var theme = 0; theme < 2; theme++) {
      for (final key in ['social', 'plus', 'matches', 'profile', 'home']) {
        await tester.tap(find.byKey(ValueKey('tab-$key')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$key theme $theme');
      }
      await tester.tap(find.byTooltip('Ganti tema'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets('failed persistence does not enter the local app', (
    tester,
  ) async {
    final repository = MemoryRepository(onboarded: false)..rejectWrite = true;
    await tester.pumpWidget(app(repository));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Coba tanpa akun'), 200);
    await tester.tap(find.text('Coba tanpa akun'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('main-navigation')), findsNothing);
    expect(repository.record['onboarded'], isFalse);
    expect(tester.takeException(), isNull);
  });
  testWidgets('duplicate local joins persist one participant', (tester) async {
    final repository = MemoryRepository();
    final container = ProviderContainer(
      overrides: [localRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    await container.read(localStateProvider.future);
    final notifier = container.read(localStateProvider.notifier);
    await Future.wait([notifier.join('test-room'), notifier.join('test-room')]);
    expect(repository.record['joined'], ['test-room']);
    expect(repository.record['activities'][0]['occupied'], 2);
    repository.rejectWrite = true;
    await expectLater(notifier.leave('test-room'), throwsStateError);
    expect(container.read(localStateProvider).requireValue['joined'], [
      'test-room',
    ]);
  });
}
