import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:klik_mobile/core/routes/app_router.dart';
import 'package:klik_mobile/data/models/local_record.dart';
import 'package:klik_mobile/data/providers/local_state.dart';
import 'package:klik_mobile/features/events/logic/activity_rules.dart';
import 'package:klik_mobile/features/payments/logic/checkout_rules.dart';

import 'app_test.dart' show MemoryRepository, app;

void main() {
  final now = DateTime(2030, 1, 1, 12);
  Map<String, dynamic> record({int price = 35000}) {
    final data = MemoryRepository().record;
    data['activities'][0]['price'] = price;
    data['activities'][0]['startsAt'] = now
        .add(const Duration(days: 1))
        .toIso8601String();
    return data;
  }

  test('paid activities cannot join before checkout confirmation', () {
    final data = record();
    expect(() => ActivityRules.join(data, 'test-room', now), throwsStateError);
    CheckoutRules.open(data, 'test-room', now);
    expect(data['joined'], isEmpty);
    expect(data['activities'][0]['occupied'], 1);
    expect(CheckoutRules.read(data, 'test-room')!.amount, 35000);
    expect(LocalRecord.validate(data), same(data));
  });
  test('opening again reuses the pending code and its deadline', () {
    final data = record();
    CheckoutRules.open(data, 'test-room', now);
    final original = CheckoutRules.read(data, 'test-room')!;
    CheckoutRules.open(data, 'test-room', now.add(const Duration(minutes: 1)));
    expect(
      CheckoutRules.read(data, 'test-room')!.reference,
      original.reference,
    );
    expect(
      CheckoutRules.read(data, 'test-room')!.expiresAt,
      original.expiresAt,
    );
    final qr = jsonDecode(original.qrPayload) as Map;
    expect(qr['test_only'], isTrue);
    expect(qr['purpose'], 'checkout-preview');
    expect(qr['amount'], 35000);
  });
  test('confirmation is atomic and does not add a second participant', () {
    final data = record();
    CheckoutRules.open(data, 'test-room', now);
    final order = CheckoutRules.read(data, 'test-room')!;
    CheckoutRules.confirm(data, 'test-room', order.reference, now);
    CheckoutRules.confirm(data, 'test-room', order.reference, now);
    expect(data['joined'], ['test-room']);
    expect(data['activities'][0]['occupied'], 2);
    expect(CheckoutRules.read(data, 'test-room')!.confirmed, isTrue);
  });
  test('expired and cancelled codes cannot admit a participant', () {
    final data = record();
    CheckoutRules.open(data, 'test-room', now);
    final original = CheckoutRules.read(data, 'test-room')!;
    expect(
      () => CheckoutRules.confirm(
        data,
        'test-room',
        original.reference,
        now.add(const Duration(minutes: 15)),
      ),
      throwsStateError,
    );
    CheckoutRules.cancel(data, 'test-room');
    expect(
      () => CheckoutRules.confirm(data, 'test-room', original.reference, now),
      throwsStateError,
    );
    expect(data['joined'], isEmpty);
    CheckoutRules.open(data, 'test-room', now.add(const Duration(minutes: 16)));
    expect(
      CheckoutRules.read(data, 'test-room')!.reference,
      isNot(original.reference),
    );
  });
  test(
    'amount changes, wrong references, and full activities reject confirmation',
    () {
      for (final scenario in ['amount', 'reference', 'full']) {
        final data = record();
        CheckoutRules.open(data, 'test-room', now);
        final order = CheckoutRules.read(data, 'test-room')!;
        if (scenario == 'amount') data['activities'][0]['price'] = 45000;
        if (scenario == 'full') data['activities'][0]['occupied'] = 10;
        expect(
          () => CheckoutRules.confirm(
            data,
            'test-room',
            scenario == 'reference' ? 'another-reference' : order.reference,
            now,
          ),
          throwsStateError,
        );
        expect(data['joined'], isEmpty);
        expect(CheckoutRules.read(data, 'test-room')!.status, 'pending');
      }
    },
  );
  test('free activities keep their direct join flow', () {
    final data = record(price: 0);
    ActivityRules.join(data, 'test-room', now);
    expect(data['joined'], ['test-room']);
    expect(data['checkoutPreviews'], isNull);
  });
  test(
    'failed local write does not confirm checkout or consume a slot',
    () async {
      final repository = MemoryRepository();
      repository.record['activities'][0]['price'] = 35000;
      final container = ProviderContainer(
        overrides: [localRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      await container.read(localStateProvider.future);
      final notifier = container.read(localStateProvider.notifier);
      await notifier.openCheckout('test-room');
      final order = CheckoutRules.read(repository.record, 'test-room')!;
      repository.rejectWrite = true;
      await expectLater(
        notifier.confirmCheckout('test-room', order.reference),
        throwsStateError,
      );
      expect(repository.record['joined'], isEmpty);
      expect(repository.record['activities'][0]['occupied'], 1);
      expect(
        CheckoutRules.read(
          container.read(localStateProvider).requireValue,
          'test-room',
        )!.confirmed,
        isFalse,
      );
      repository.rejectWrite = false;
      await notifier.confirmCheckout('test-room', order.reference);
      expect(repository.record['joined'], ['test-room']);
    },
  );
  test('malformed saved checkout is rejected without deleting the source', () {
    final data = record();
    CheckoutRules.open(data, 'test-room', now);
    data['checkoutPreviews']['test-room']['amount'] = -1;
    expect(() => LocalRecord.validate(data), throwsFormatException);
    expect(data['checkoutPreviews']['test-room']['amount'], -1);
  });
  testWidgets('paid join immediately shows QR and waits for confirmation', (
    tester,
  ) async {
    final repository = MemoryRepository();
    repository.record['activities'][0]['price'] = 35000;
    await tester.pumpWidget(app(repository));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Gabung'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gabung'));
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('QRIS'), findsOneWidget);
    expect(find.textContaining('Simulasi'), findsNothing);
    expect(repository.record['joined'], isEmpty);
    await tester.scrollUntilVisible(
      find.text('Konfirmasi pembayaran'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Konfirmasi pembayaran'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('checkout-complete')), findsOneWidget);
    expect(repository.record['joined'], ['test-room']);
    expect(repository.record['activities'][0]['occupied'], 2);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('cancelling checkout returns without joining', (tester) async {
    final repository = MemoryRepository();
    repository.record['activities'][0]['price'] = 35000;
    await tester.pumpWidget(app(repository));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    container.read(appRouterProvider).go('/checkout/test-room');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Batalkan'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Batalkan'));
    await tester.pumpAndSettle();
    expect(repository.record['joined'], isEmpty);
    expect(
      CheckoutRules.read(repository.record, 'test-room')!.status,
      'cancelled',
    );
    expect(find.byType(QrImageView), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
