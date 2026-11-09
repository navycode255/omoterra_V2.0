import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/api/vendor_repository.dart';
import 'package:mr_nyama_vendor/core/routing/routes.dart';
import 'package:mr_nyama_vendor/features/closing/count_entry_screen.dart';
import 'package:mr_nyama_vendor/features/sales/cart.dart';
import 'package:mr_nyama_vendor/shared/widgets/buttons.dart';
import 'package:mr_nyama_vendor/shared/widgets/quantity.dart';

import 'helpers.dart';
import 'history_flow_test.dart' show record, now;
import 'receiving_flow_test.dart' show delivery;

void main() {
  testWidgets('receiving enters count form and blocks unexplained differences',
      (tester) async {
    final app = await pumpApp(tester,
        api: FakeVendorRepository()..deliveryList = [delivery()]);
    app.router.push(MNRoutes.delivery('c1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pokea bidhaa'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<MNButton>(find.widgetWithText(MNButton, 'Hifadhi'))
            .onPressed,
        isNotNull);
    await tester.tap(find
        .byWidgetPredicate(
            (w) => w is MNQuantityButton && w.icon.name == 'minus')
        .first);
    await tester.pumpAndSettle();
    expect(find.text('Sababu ya tofauti (lazima)'), findsOneWidget);
    expect(
        tester
            .widget<MNButton>(find.widgetWithText(MNButton, 'Hifadhi'))
            .onPressed,
        isNull);
  });

  testWidgets('count page requires explicit entry and returns to progress list',
      (tester) async {
    final app = await pumpApp(tester,
        api: FakeVendorRepository()..catalogSnapshot = testCatalog);
    app.router.push(MNRoutes.closeDay);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kuku mzima'));
    await tester.pumpAndSettle();
    expect(find.byType(CountEntryScreen), findsOneWidget);
    expect(
        tester
            .widget<MNButton>(find.widgetWithText(MNButton, 'Hifadhi'))
            .onPressed,
        isNull);
    await tester.tap(find.text('2'));
    await tester.pumpAndSettle();
    // Blind count: the number alone is enough, no expected figure or reason.
    expect(find.text('Baki inayotarajiwa'), findsNothing);
    expect(find.text('Sababu ya tofauti (lazima)'), findsNothing);
    expect(
        tester
            .widget<MNButton>(find.widgetWithText(MNButton, 'Hifadhi'))
            .onPressed,
        isNotNull);
    await tester.tap(find.text('Hifadhi'));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 kati ya'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cart swipe removes a line and undo restores its quantity',
      (tester) async {
    final app = await pumpApp(tester,
        initial: MNRoutes.sales,
        api: FakeVendorRepository()..catalogSnapshot = testCatalog);
    app.container.read(cartProvider.notifier).add('kuku', 2);
    app.router.push(MNRoutes.cart);
    await tester.pumpAndSettle();
    await tester.drag(find.text('Kuku mzima'), const Offset(-200, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Futa'));
    await tester.pumpAndSettle();
    expect(app.container.read(cartProvider).isEmpty, isTrue);
    await tester.tap(find.text('Rudisha'));
    await tester.pumpAndSettle();
    expect(app.container.read(cartProvider).quantityOf('kuku'), 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('history applies payment filter and date-range chips',
      (tester) async {
    final app = await pumpApp(tester, now: now);
    await record(app, 'cash', now);
    await record(app, 'mpesa', now, payment: PaymentMethod.mpesa);
    app.router.push(MNRoutes.history);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Chuja'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Taslimu').last);
    await tester.tap(find.text('Tumia vichujio'));
    await tester.pumpAndSettle();
    expect(find.text('M-Pesa'), findsNothing);
    expect(find.text('Wiki hii'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sales filter matches the reference: period, payment, reset',
      (tester) async {
    final app = await pumpApp(tester, now: now);
    await record(app, 'cash', now);
    app.router.push(MNRoutes.history);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Chuja'));
    await tester.pumpAndSettle();
    for (final label in [
      'Muda',
      'Jana',
      'Jumatano 7',
      'Jumanne 6',
      'Mwezi huu',
      'Njia ya malipo',
      'Taslimu',
      'Mkopo',
      'Onyesha yasiyosawazishwa tu',
    ]) {
      expect(find.text(label), findsWidgets, reason: label);
    }
    // Payment choices are checks; "Weka upya" clears them.
    await tester.tap(find.text('Taslimu').last);
    await tester.pump();
    expect(tester.getSemantics(find.bySemanticsLabel('Taslimu').last),
        isSemantics(isChecked: true));
    await tester.tap(find.text('Weka upya'));
    await tester.pump();
    expect(tester.getSemantics(find.bySemanticsLabel('Taslimu').last),
        isSemantics(isChecked: false));
    // A named day becomes that date on the screen.
    await tester.tap(find.text('Jumanne 6'));
    await tester.tap(find.text('Tumia vichujio'));
    await tester.pumpAndSettle();
    expect(find.text('6 Okt 2026'), findsOneWidget);
    // "Tarehe maalum" opens the date wheel and shows the choice.
    await tester.tap(find.byTooltip('Chuja'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tarehe maalum').last);
    await tester.pumpAndSettle();
    expect(find.text('Tumia tarehe'), findsOneWidget);
    // It opens on the day already chosen (Jumanne 6); take the day before.
    await tester.tap(find.text('Jumatatu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tumia tarehe'));
    await tester.pumpAndSettle();
    expect(find.text('5 Okt 2026'), findsOneWidget);
    await tester.tap(find.text('Tumia vichujio'));
    await tester.pumpAndSettle();
    expect(find.text('5 Okt 2026'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
