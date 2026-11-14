import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:klik_mobile/app.dart';
import 'package:klik_mobile/core/routes/app_router.dart';
import 'package:klik_mobile/core/theme/theme_controller.dart';
import 'package:klik_mobile/data/models/activity.dart';
import 'package:klik_mobile/data/providers/local_state.dart';
import 'package:klik_mobile/data/repositories/local_repository.dart';

import 'app_test.dart' show MemoryRepository;

void main() {
  testWidgets('render principal routes in both themes and large text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(402, 874);
    tester.view.padding = const FakeViewPadding(top: 62, bottom: 24);
    tester.view.viewPadding = const FakeViewPadding(top: 62, bottom: 24);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    SharedPreferences.setMockInitialValues({});
    final data = await tester.runAsync(() async {
      final font = FontLoader('Inter')
        ..addFont(rootBundle.load('assets/fonts/Inter.ttf'));
      await font.load();
      return LocalRepository().load();
    });
    final repository = MemoryRepository()
      ..record = {...data!, 'onboarded': true, 'theme': 'light'};
    const captureKey = ValueKey('review-boundary');
    await tester.pumpWidget(
      RepaintBoundary(
        key: captureKey,
        child: ProviderScope(
          overrides: [localRepositoryProvider.overrideWithValue(repository)],
          child: const KlikApp(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(KlikApp)),
    );
    await tester.runAsync(() async {
      final context = tester.element(find.byType(KlikApp));
      await precacheImage(const AssetImage('assets/figma/avatar.png'), context);
      if (context.mounted) {
        await precacheImage(
          const AssetImage('assets/figma/futsal.png'),
          context,
        );
      }
    });
    final router = container.read(appRouterProvider);
    Future<void> capture(String name) async {
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: name);
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(captureKey),
      );
      await tester.runAsync(() async {
        final rendered = await boundary.toImage(pixelRatio: 1);
        final bytes = await rendered.toByteData(format: ui.ImageByteFormat.png);
        if (bytes == null) throw StateError('Unable to capture $name');
        final file = File('build/review/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes.buffer.asUint8List());
        rendered.dispose();
      });
    }

    const routes = {
      'home': '/',
      'social': '/social',
      'create': '/create',
      'matches': '/matches',
      'profile': '/profile',
      'search': '/search',
      'events': '/search?tab=Acara',
      'event': '/activity/event-cilandak',
      'room': '/activity/room-cilandak',
      'new-room': '/new/room',
      'new-event': '/new/event',
      'edit-profile': '/edit-profile',
      'leaderboard': '/leaderboard',
      'team': '/team',
      'venue': '/venue/Futsal%20Cilandak',
      'player': '/player/adi',
      'settings': '/settings',
      'login': '/login',
      'register': '/register',
      'reset-password': '/reset-password',
      'notifications': '/notifications',
      'welcome': '/welcome',
    };
    for (final theme in [ThemeMode.light, ThemeMode.dark]) {
      await container.read(themeModeProvider.notifier).select(theme);
      for (final entry in routes.entries) {
        router.go(entry.value);
        await capture('${entry.key}-${theme.name}');
        if (entry.key == 'home') {
          await tester.drag(
            find.byType(ListView).first,
            const Offset(0, -1800),
          );
          await capture('home-bottom-${theme.name}');
        }
      }
    }
    final ended = Activity(
      id: 'review-ended',
      kind: 'room',
      title: 'Uji tampilan hasil',
      sport: 'Futsal',
      venue: 'Futsal Cilandak',
      city: 'Jakarta Selatan',
      mode: 'Kasual',
      startsAt: DateTime.now().subtract(const Duration(hours: 3)),
      capacity: 10,
      occupied: 2,
      price: 0,
      owner: 'Pemain KLIK',
      description: 'Data fixture untuk pemeriksaan tampilan.',
      owned: true,
      demo: true,
    );
    await container.read(localStateProvider.notifier).change((j) {
      (j['activities'] as List).add(ended.toJson());
      (j['joined'] as List).add(ended.id);
    });
    router.go('/score/${ended.id}');
    await capture('input-score-dark');
    await tester.enterText(find.byType(TextFormField).at(0), '5');
    await tester.enterText(find.byType(TextFormField).at(1), '3');
    await tester.tap(find.byType(CheckboxListTile));
    await tester.scrollUntilVisible(
      find.text('Kirim hasil'),
      200,
      scrollable: find.descendant(
        of: find.byType(ListView).first,
        matching: find.byType(Scrollable),
      ).first,
    );
    await tester.tap(find.text('Kirim hasil'));
    await tester.pumpAndSettle();
    router.go('/activity/${ended.id}');
    await capture('pending-result-dark');
    tester.view.physicalSize = const Size(320, 568);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    for (final entry in routes.entries.where(
      (e) => [
        'home',
        'social',
        'create',
        'matches',
        'profile',
        'room',
        'event',
        'search',
        'leaderboard',
        'edit-profile',
        'settings',
      ].contains(e.key),
    )) {
      router.go(entry.value);
      await capture('${entry.key}-small-large-text');
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
