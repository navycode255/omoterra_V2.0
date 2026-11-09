import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/theme/theme.dart';
import 'package:mr_nyama_vendor/shared/widgets/icon.dart';
import 'package:mr_nyama_vendor/shared/widgets/input_field.dart';
import 'package:mr_nyama_vendor/shared/widgets/number_sheet.dart';
import 'package:mr_nyama_vendor/shared/widgets/reference_card.dart';
import 'package:mr_nyama_vendor/shared/widgets/rows.dart';
import 'package:mr_nyama_vendor/shared/widgets/states.dart';

import 'helpers.dart';

Widget _view(AsyncValue<List<int>> value,
        {bool refreshing = false, VoidCallback? onRetry}) =>
    wrap(SizedBox(
      height: 500,
      child: MNAsyncView<List<int>>(
        value: value,
        isEmpty: (v) => v.isEmpty,
        refreshing: refreshing,
        onRetry: onRetry,
        empty: (_) =>
            const MNEmptyState(icon: MNIconData.list, title: 'Hakuna kitu'),
        data: (v) => Text('Vitu ${v.length}'),
      ),
    ));

void main() {
  group('async view', () {
    testWidgets('first load shows skeleton rows', (tester) async {
      setScreen(tester, reducedMotion: true);
      await tester.pumpWidget(_view(const AsyncLoading()));
      expect(find.byType(MNLoadingState), findsOneWidget);
    });

    testWidgets('data goes to the builder', (tester) async {
      await tester.pumpWidget(_view(const AsyncData([1, 2])));
      expect(find.text('Vitu 2'), findsOneWidget);
    });

    testWidgets('empty data shows the empty state', (tester) async {
      await tester.pumpWidget(_view(const AsyncData([])));
      expect(find.text('Hakuna kitu'), findsOneWidget);
    });

    testWidgets('empty data while refreshing keeps loading, not "empty"',
        (tester) async {
      setScreen(tester, reducedMotion: true);
      await tester.pumpWidget(_view(const AsyncData([]), refreshing: true));
      expect(find.text('Hakuna kitu'), findsNothing);
      expect(find.byType(MNLoadingState), findsOneWidget);
    });

    testWidgets('refreshing never hides data that is already there',
        (tester) async {
      await tester.pumpWidget(_view(const AsyncData([1]), refreshing: true));
      expect(find.text('Vitu 1'), findsOneWidget);
    });

    testWidgets('an error retries on a swipe, with no button', (tester) async {
      var retried = 0;
      await tester.pumpWidget(_view(
          AsyncError<List<int>>(StateError('x'), StackTrace.empty),
          onRetry: () => retried++));
      expect(find.text('Jaribu tena'), findsNothing);
      await tester.drag(find.text('Imeshindikana'), const Offset(0, 300));
      await tester.pumpAndSettle();
      expect(retried, 1);
    });
  });

  group('reference action', () {
    testWidgets('one button for screen readers, and it taps', (tester) async {
      var taps = 0;
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(wrap(Padding(
          padding: const EdgeInsets.all(16),
          child: MNReferenceAction(
              icon: MNIconData.truck,
              label: 'Pokea Bidhaa',
              subtitle: 'Thibitisha mzigo',
              onTap: () => taps++))));
      expect(find.bySemanticsLabel('Pokea Bidhaa, Thibitisha mzigo'),
          findsOneWidget);
      expect(find.bySemanticsLabel('Pokea Bidhaa'), findsNothing);
      await tester.tap(find.text('Pokea Bidhaa'));
      expect(taps, 1);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      semantics.dispose();
    });

    testWidgets('without onTap it ignores taps', (tester) async {
      await tester.pumpWidget(wrap(const MNReferenceAction(
          icon: MNIconData.box, label: 'Soko', subtitle: 'Bei', onTap: null)));
      await tester.tap(find.text('Soko'));
      await tester.pumpAndSettle();
    });
  });

  testWidgets('transaction row icon follows mobileMoney, not the wording',
      (tester) async {
    MNIcon paymentIcon() =>
        tester.widgetList<MNIcon>(find.byType(MNIcon)).firstWhere(
            (i) => i.icon == MNIconData.phone || i.icon == MNIconData.cash);
    Future<void> pump(bool mobileMoney) => tester.pumpWidget(wrap(
        MNTransactionRow(
            time: '10:42',
            product: 'Kuku',
            quantity: 1,
            // Wording an older comparison would have misread.
            paymentMethod: 'Lipa kwa simu',
            mobileMoney: mobileMoney,
            amount: 9000),
        scroll: true));
    await pump(true);
    expect(paymentIcon().icon, MNIconData.phone);
    await pump(false);
    expect(paymentIcon().icon, MNIconData.cash);
  });

  testWidgets('text field takes focus from an outside focus node',
      (tester) async {
    final node = FocusNode();
    addTearDown(node.dispose);
    await tester.pumpWidget(wrap(Padding(
        padding: const EdgeInsets.all(16),
        child: MNTextField(label: 'Maelezo', focusNode: node))));
    Border border() => (tester
            .widget<AnimatedContainer>(find.byType(AnimatedContainer))
            .decoration as BoxDecoration)
        .border as Border;
    expect(border().top.color, MNColors.borderStrong);
    node.requestFocus();
    await tester.pumpAndSettle();
    expect(border().top.color, MNColors.ink);
    // Removing the field must not dispose a node the caller owns.
    await tester.pumpWidget(wrap(const SizedBox()));
    node.requestFocus();
  });

  testWidgets('number sheet clamps a starting value above max', (tester) async {
    setScreen(tester);
    int? result;
    await tester.pumpWidget(wrap(Builder(
        builder: (context) => TextButton(
            onPressed: () async => result = await showNumberSheet(context,
                title: 'Idadi', initial: 40, max: 12),
            child: const Text('Fungua')))));
    await tester.tap(find.text('Fungua'));
    await tester.pumpAndSettle();
    expect(find.text('12'), findsOneWidget);
    await tester.tap(find.text('Weka idadi'));
    await tester.pumpAndSettle();
    expect(result, 12);
  });
}
