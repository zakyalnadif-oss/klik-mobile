import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:klik_mobile/core/theme/app_theme.dart';
import 'package:klik_mobile/data/models/activity.dart';
import 'package:klik_mobile/shared/components/activity_card.dart';
import 'package:klik_mobile/shared/components/event_carousel.dart';

Activity activity(
  String id, {
  bool event = false,
  String mode = 'Kasual',
  bool long = false,
}) => Activity(
  id: id,
  kind: event ? 'event' : 'room',
  title: long
      ? 'Kompetisi Futsal Komunitas Cilandak dan Teman Kampus'
      : 'lomba',
  sport: 'Futsal',
  venue: long ? 'Lapangan Futsal Cilandak, Jakarta Selatan' : 'cimahi',
  city: 'Jakarta Selatan',
  mode: mode,
  startsAt: DateTime.now().add(const Duration(days: 1)),
  capacity: 10,
  occupied: 1,
  price: 0,
  owner: 'Pemain KLIK',
  description: 'Uji tampilan',
);

Widget page(Widget child) => MaterialApp(
  theme: AppTheme.dark,
  home: Scaffold(
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: child,
    ),
  ),
);

void main() {
  testWidgets(
    'event cards with different content share height and button baseline',
    (tester) async {
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        page(
          EventCarousel(
            events: [
              activity('short', event: true),
              activity('long', event: true, long: true),
            ],
            joined: const {'short'},
          ),
        ),
      );
      await tester.pumpAndSettle();
      final cards = find.byType(ActivityCard);
      expect(tester.getSize(cards.at(0)), tester.getSize(cards.at(1)));
      expect(
        tester
            .getRect(find.byKey(const ValueKey('activity-action-short')))
            .bottom,
        closeTo(
          tester
              .getRect(find.byKey(const ValueKey('activity-action-long')))
              .bottom,
          1,
        ),
      );
      expect(find.text('Lihat Detail'), findsOneWidget);
      expect(find.text('Lihat Acara'), findsOneWidget);
      expect(
        find.text('Kompetisi Futsal Komunitas Cilandak dan Teman Kampus'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('room buttons and mode labels reach the same right edge', (
    tester,
  ) async {
    await tester.pumpWidget(
      page(
        Column(
          children: [
            ActivityCard(activity('casual'), joined: true),
            const SizedBox(height: 12),
            ActivityCard(activity('ranked', mode: 'Berperingkat', long: true)),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final id in ['casual', 'ranked']) {
      final button = tester.getRect(
        find.byKey(ValueKey('activity-action-$id')),
      );
      final mode = tester.getRect(find.byKey(ValueKey('activity-mode-$id')));
      final card = tester.getRect(
        find.byType(ActivityCard).at(id == 'casual' ? 0 : 1),
      );
      expect(button.right, closeTo(mode.right, 1));
      expect(card.right - button.right, lessThan(20));
    }
    expect(find.text('Gabung'), findsNWidgets(2));
    expect(find.text('Lihat Detail'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'equal event cards remain readable at 200 percent text on a small screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        page(
          EventCarousel(
            events: [
              activity('short', event: true),
              activity('long', event: true, long: true),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(ActivityCard).at(0)),
        tester.getSize(find.byType(ActivityCard).at(1)),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
