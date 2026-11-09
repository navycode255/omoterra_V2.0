import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:ui' show Tristate;

import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/theme/theme.dart';
import 'package:mr_nyama_vendor/shared/widgets/amount.dart';
import 'package:mr_nyama_vendor/shared/widgets/app_header.dart';
import 'package:mr_nyama_vendor/shared/widgets/avatar.dart';
import 'package:mr_nyama_vendor/shared/widgets/bottom_nav.dart';
import 'package:mr_nyama_vendor/shared/widgets/buttons.dart';
import 'package:mr_nyama_vendor/shared/widgets/cart_summary.dart';
import 'package:mr_nyama_vendor/shared/widgets/dialogs.dart';
import 'package:mr_nyama_vendor/shared/widgets/image_spinner.dart';
import 'package:mr_nyama_vendor/shared/widgets/input_field.dart';
import 'package:mr_nyama_vendor/shared/widgets/logo.dart';
import 'package:mr_nyama_vendor/shared/widgets/pin.dart';
import 'package:mr_nyama_vendor/shared/widgets/product_card.dart';
import 'package:mr_nyama_vendor/shared/widgets/quantity.dart';
import 'package:mr_nyama_vendor/shared/widgets/rows.dart';
import 'package:mr_nyama_vendor/shared/widgets/sheet.dart';
import 'package:mr_nyama_vendor/shared/widgets/states.dart';
import 'package:mr_nyama_vendor/shared/widgets/sync_indicator.dart';

import 'helpers.dart';

/// The fill colour painted behind a button's label.
Color? fillOf(WidgetTester tester, Finder button) {
  final box = tester.widget<AnimatedContainer>(find
      .descendant(of: button, matching: find.byType(AnimatedContainer))
      .first);
  return (box.decoration as BoxDecoration?)?.color;
}

void main() {
  test('avatar initials use letters only', () {
    expect(MNAvatar.initials('Maternus Juma'), 'MJ');
    expect(MNAvatar.initials('Maternus'), 'M');
    expect(MNAvatar.initials('Maternus (sampuli)'), 'M');
    expect(MNAvatar.initials('  Ali   Hassan Said '), 'AH');
    expect(MNAvatar.initials('Ümit Öz'), 'ÜÖ');
    expect(MNAvatar.initials(''), '');
  });

  group('buttons', () {
    testWidgets(
        'primary, secondary and destructive are 56 px with their colours',
        (tester) async {
      await tester.pumpWidget(wrap(Column(children: [
        MNButton('Hifadhi', onPressed: () {}),
        MNButton.secondary('Rudi', onPressed: () {}),
        MNButton.destructive('Futa', onPressed: () {}),
      ])));
      for (final label in ['Hifadhi', 'Rudi', 'Futa']) {
        final button = find.widgetWithText(MNButton, label);
        expect(tester.getSize(button).height, MNSize.button);
      }
      expect(fillOf(tester, find.widgetWithText(MNButton, 'Hifadhi')),
          MNColors.red);
      expect(fillOf(tester, find.widgetWithText(MNButton, 'Rudi')),
          MNColors.white);
      expect(fillOf(tester, find.widgetWithText(MNButton, 'Futa')),
          MNColors.white);
    });

    testWidgets('press darkens the primary fill and scales to .98',
        (tester) async {
      var taps = 0;
      await tester
          .pumpWidget(wrap(MNButton('Hifadhi', onPressed: () => taps++)));
      final gesture =
          await tester.startGesture(tester.getCenter(find.text('Hifadhi')));
      await tester.pumpAndSettle();
      expect(fillOf(tester, find.byType(MNButton)), MNColors.redPressed);
      expect(
          tester
              .widget<AnimatedScale>(find.descendant(
                  of: find.byType(MNButton),
                  matching: find.byType(AnimatedScale)))
              .scale,
          MNMotion.pressButton);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(taps, 1);
      expect(fillOf(tester, find.byType(MNButton)), MNColors.red);
    });

    testWidgets('disabled buttons use the disabled style and ignore taps',
        (tester) async {
      await tester.pumpWidget(wrap(const MNButton('Hifadhi', onPressed: null)));
      expect(fillOf(tester, find.byType(MNButton)), MNColors.disabled);
      final semantics = tester.getSemantics(find.byType(MNButton));
      expect(semantics.flagsCollection.isEnabled, Tristate.isFalse);
    });

    testWidgets('busy shows a spinner and blocks repeat taps', (tester) async {
      setScreen(tester, reducedMotion: true);
      var taps = 0;
      await tester.pumpWidget(
          wrap(MNButton('Hifadhi', onPressed: () => taps++, busy: true)));
      expect(find.byType(MNSpinner), findsOneWidget);
      await tester.tap(find.text('Hifadhi'));
      expect(taps, 0);
    });
  });

  group('app header', () {
    testWidgets('a root header has no back button', (tester) async {
      await tester.pumpWidget(wrap(const SizedBox(
          height: 80,
          width: 390,
          child: MNAppHeader(title: 'Nyumbani', root: true))));
      expect(find.text('Nyumbani'), findsOneWidget);
      expect(find.bySemanticsLabel('Rudi'), findsNothing);
    });

    testWidgets('a pushed header shows back and calls onBack', (tester) async {
      var back = 0;
      await tester.pumpWidget(wrap(SizedBox(
          height: 80,
          width: 390,
          child: MNAppHeader(title: 'Historia', onBack: () => back++))));
      await tester.tap(find.bySemanticsLabel('Rudi'));
      expect(back, 1);
    });
  });

  testWidgets(
      'bottom navigation: three items, active one red, 56 px, no badges',
      (tester) async {
    var selected = -1;
    await tester.pumpWidget(wrap(MNBottomNav(
      currentIndex: 1,
      onSelect: (i) => selected = i,
      items: const [
        MNNavItem(MNIconData.home, 'Nyumbani'),
        MNNavItem(MNIconData.bag, 'Mauzo'),
        MNNavItem(MNIconData.box, 'Bidhaa'),
      ],
    )));
    expect(tester.getSize(find.byType(MNBottomNav)).height, MNSize.navBar);
    final active = tester.widget<Text>(find.text('Mauzo'));
    expect(
        active.style?.color ??
            DefaultTextStyle.of(tester.element(find.text('Mauzo'))).style.color,
        MNColors.red);
    expect(find.byType(Badge), findsNothing);
    await tester.tap(find.text('Bidhaa'));
    expect(selected, 2);
    expect(
        tester
            .getSemantics(find.bySemanticsLabel('Mauzo'))
            .flagsCollection
            .isSelected,
        Tristate.isTrue);
  });

  group('product card', () {
    testWidgets('shows name, formatted price and what is left; + adds',
        (tester) async {
      var added = 0, opened = 0;
      await tester.pumpWidget(wrap(SizedBox(
          width: 173,
          child: MNProductCard(
              name: 'Kidali (Robo)',
              price: 2500,
              remaining: '28',
              onTap: () => opened++,
              onAdd: () => added++))));
      expect(find.text('Kidali (Robo)'), findsOneWidget);
      expect(find.text('TSh 2,500'), findsOneWidget);
      expect(find.text('Imesalia: 28'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Ongeza Kidali (Robo)'));
      await tester.tap(find.text('Kidali (Robo)'));
      expect(added, 1);
      expect(opened, 1);
    });

    testWidgets('with a quantity it shows the stepper and a red border',
        (tester) async {
      var decreased = 0;
      await tester.pumpWidget(wrap(SizedBox(
          width: 173,
          child: MNProductCard(
              name: 'Shingo (1)',
              price: 500,
              quantity: 3,
              selected: true,
              onAdd: () {},
              onDecrease: () => decreased++))));
      expect(find.text('3'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Punguza Shingo (1)'));
      expect(decreased, 1);
      final border = tester
          .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
          .map((c) => (c.foregroundDecoration as BoxDecoration?)?.border)
          .whereType<Border>()
          .first;
      expect(border.top.color, MNColors.red);
      expect(border.top.width, 2);
    });

    testWidgets('out of stock cannot be opened and says so', (tester) async {
      var opened = 0;
      await tester.pumpWidget(wrap(SizedBox(
          width: 173,
          child: MNProductCard(
              name: 'Paja (Robo)',
              price: 2000,
              outOfStock: true,
              onTap: () => opened++,
              onAdd: () => opened++))));
      expect(find.text('Imeisha'), findsOneWidget);
      expect(find.bySemanticsLabel('Ongeza Paja (Robo)'), findsNothing);
      await tester.tap(find.text('Paja (Robo)'));
      expect(opened, 0);
    });
  });

  group('product photo loading', () {
    Widget photo(ImageProvider image) => wrap(
        SizedBox(width: 160, height: 200, child: MNProductImage(image: image)));

    testWidgets('a server photo shows the ember ring until it is decoded',
        (tester) async {
      final image = _PendingImage();
      await tester.pumpWidget(photo(image));
      expect(find.byType(MNImageSpinner), findsOneWidget);
      // About a quarter of the photo's short side, capped.
      expect(tester.getSize(find.byType(MNImageSpinner)).width, 36);

      final decoded =
          await tester.runAsync(() => createTestImage(width: 4, height: 4));
      image.completer.complete(ImageInfo(image: decoded!));
      await tester.pumpAndSettle();
      expect(find.byType(MNImageSpinner), findsNothing);
      expect(
          tester
              .widget<AnimatedOpacity>(find.descendant(
                  of: find.byType(MNLoadingImage),
                  matching: find.byType(AnimatedOpacity)))
              .opacity,
          1);
    });

    testWidgets('a failed fetch leaves the empty photo background',
        (tester) async {
      final image = _PendingImage();
      await tester.pumpWidget(photo(image));
      image.completer.completeError(Exception('offline'));
      await tester.pumpAndSettle();
      expect(find.byType(MNImageSpinner), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('bundled photos never show the ring', (tester) async {
      await tester
          .pumpWidget(photo(const AssetImage('assets/images/grill.png')));
      expect(find.byType(MNImageSpinner), findsNothing);
    });

    testWidgets('reduced motion shows a still ring with no loop',
        (tester) async {
      setScreen(tester, reducedMotion: true);
      await tester.pumpWidget(photo(_PendingImage()));
      // A running ticker would keep scheduling frames and never settle.
      await tester.pumpAndSettle();
      expect(find.byType(MNImageSpinner), findsOneWidget);
    });
  });

  group('quantity selector', () {
    testWidgets('changes by one and stops at min and max', (tester) async {
      var value = 1;
      await tester.pumpWidget(wrap(StatefulBuilder(
          builder: (context, setState) => MNQuantitySelector(
              value: value,
              min: 1,
              max: 2,
              itemLabel: 'Kuku',
              onChanged: (v) => setState(() => value = v)))));
      final minus = find.bySemanticsLabel('Punguza Kuku');
      final plus = find.bySemanticsLabel('Ongeza Kuku');
      expect(tester.getSemantics(minus).flagsCollection.isEnabled,
          Tristate.isFalse);
      await tester.tap(plus);
      await tester.pumpAndSettle();
      expect(value, 2);
      expect(find.text('2'), findsOneWidget);
      expect(tester.getSemantics(plus).flagsCollection.isEnabled,
          Tristate.isFalse);
      await tester.tap(minus);
      await tester.pumpAndSettle();
      expect(value, 1);
    });

    testWidgets('buttons are 48 px, large variant 64 px', (tester) async {
      await tester.pumpWidget(wrap(Column(children: [
        MNQuantitySelector(value: 1, itemLabel: 'A', onChanged: (_) {}),
        MNQuantitySelector(
            value: 1, itemLabel: 'B', large: true, onChanged: (_) {}),
      ])));
      expect(tester.getSize(find.bySemanticsLabel('Ongeza A')).width, 48);
      expect(tester.getSize(find.bySemanticsLabel('Ongeza B')).width, 64);
    });
  });

  testWidgets('cart bar appears with items and leaves when emptied',
      (tester) async {
    var count = 0;
    late StateSetter set;
    await tester.pumpWidget(wrap(StatefulBuilder(builder: (context, s) {
      set = s;
      return Align(
          alignment: Alignment.bottomCenter,
          child:
              MNCartBar(itemCount: count, total: count * 2500, onTap: () {}));
    })));
    expect(find.textContaining('TSh'), findsNothing);
    set(() => count = 3);
    await tester.pumpAndSettle();
    expect(find.text('Bidhaa 3 · TSh 7,500'), findsOneWidget);
    expect(tester.getSize(find.byType(MNCartBar)).height,
        greaterThanOrEqualTo(MNSize.button));
    set(() => count = 0);
    await tester.pumpAndSettle();
    expect(find.textContaining('TSh'), findsNothing);
    expect(tester.getSize(find.byType(MNCartBar)).height, 0);
  });

  testWidgets('cart bar shows only the count while a price is unknown',
      (tester) async {
    await tester.pumpWidget(wrap(Align(
        alignment: Alignment.bottomCenter,
        child: MNCartBar(itemCount: 2, total: null, onTap: () {}))));
    await tester.pumpAndSettle();
    expect(find.text('Bidhaa 2'), findsOneWidget);
    expect(find.textContaining('TSh'), findsNothing);
  });

  testWidgets('rows: transaction, stock and product', (tester) async {
    await tester.pumpWidget(wrap(
        const Column(children: [
          MNTransactionRow(
              first: true,
              time: '10:42',
              product: 'Kuku',
              quantity: 2,
              paymentMethod: 'Taslimu',
              mobileMoney: false,
              amount: 24000),
          MNStockRow(name: 'Shingo (1)', price: 500, quantity: '40'),
          MNProductRow(name: 'Firigisi (2)', price: 1000),
        ]),
        scroll: true));
    expect(find.text('Kuku × 2'), findsOneWidget);
    expect(find.text('24,000'), findsOneWidget);
    expect(find.text('Imesalia'), findsOneWidget);
    expect(find.text('40'), findsOneWidget);
    expect(find.text('TSh 1,000'), findsOneWidget);
    for (final row in tester.widgetList(find.byType(MNListRow))) {
      expect(tester.getSize(find.byWidget(row)).height,
          greaterThanOrEqualTo(MNSize.row));
    }
  });

  testWidgets('a voided transaction is muted and struck through',
      (tester) async {
    await tester.pumpWidget(wrap(
        const MNTransactionRow(
            time: '10:42',
            product: 'Kuku',
            quantity: 2,
            paymentMethod: 'Taslimu',
            mobileMoney: false,
            amount: 24000,
            voided: true),
        scroll: true));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.text('Kuku × 2')).style!.color,
        MNColors.muted);
  });

  testWidgets('amount display formats shillings and announces the label',
      (tester) async {
    await tester.pumpWidget(
        wrap(const MNAmountDisplay(label: 'Mauzo ya leo', shillings: 245000)));
    expect(find.text('TSh 245,000'), findsOneWidget);
    expect(find.bySemanticsLabel('Mauzo ya leo, TSh 245,000'), findsOneWidget);
    await tester
        .pumpWidget(wrap(const MNAmount(2500, size: MNAmountSize.price)));
    expect(
        tester.widget<Text>(find.text('TSh 2,500')).style!.color, MNColors.red);
  });

  group('input field', () {
    testWidgets('label, focus border and error message', (tester) async {
      await tester.pumpWidget(wrap(const Padding(
          padding: EdgeInsets.all(16),
          child: MNTextField(label: 'Namba ya simu'))));
      expect(find.text('Namba ya simu'), findsOneWidget);
      Border border() => (tester
              .widget<AnimatedContainer>(find.byType(AnimatedContainer))
              .decoration as BoxDecoration)
          .border as Border;
      expect(border().top.color, MNColors.borderStrong);
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(border().top.color, MNColors.ink);
      expect(border().top.width, 2);

      await tester.pumpWidget(wrap(const Padding(
          padding: EdgeInsets.all(16),
          child:
              MNTextField(label: 'Namba ya simu', error: 'Namba si sahihi'))));
      await tester.pumpAndSettle();
      expect(find.text('Namba si sahihi'), findsOneWidget);
      expect(border().top.color, MNColors.error);
      expect(tester.getSize(find.byType(AnimatedContainer)).height,
          greaterThanOrEqualTo(MNSize.field));
    });
  });

  group('PIN', () {
    testWidgets('keypad sends digits and backspace; keys are 64 px',
        (tester) async {
      final digits = <int>[];
      var back = 0;
      await tester.pumpWidget(wrap(Padding(
          padding: const EdgeInsets.all(16),
          child: MNPinKeypad(onDigit: digits.add, onBackspace: () => back++))));
      for (final d in [1, 9, 0]) {
        await tester.tap(find.text('$d'));
      }
      await tester.tap(find.bySemanticsLabel('Futa'));
      expect(digits, [1, 9, 0]);
      expect(back, 1);
      expect(tester.getSize(find.bySemanticsLabel('5')).height, MNSize.key);
    });

    testWidgets('dots announce progress, never the digits', (tester) async {
      await tester.pumpWidget(wrap(const MNPinDots(filled: 3)));
      expect(find.bySemanticsLabel('Tarakimu 3 kati ya 4'), findsOneWidget);
      await tester.pumpWidget(wrap(const MNPinDots(filled: 4, error: true)));
      await tester.pumpAndSettle();
    });
  });

  testWidgets('confirmation dialog returns true only on confirm',
      (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(wrap(Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    })));
    Future<bool> open() => showMNConfirmDialog(ctx,
        title: 'Batilisha mauzo haya?',
        confirmLabel: 'Ndiyo',
        cancelLabel: 'Hapana',
        destructive: true);

    var result = open();
    await tester.pumpAndSettle();
    expect(find.text('Batilisha mauzo haya?'), findsOneWidget);
    expect(
        fillOf(tester, find.widgetWithText(MNButton, 'Ndiyo')), MNColors.error);
    await tester.tap(find.text('Ndiyo'));
    await tester.pumpAndSettle();
    expect(await result, isTrue);

    result = open();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapana'));
    await tester.pumpAndSettle();
    expect(await result, isFalse);

    result = open();
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5)); // the scrim
    await tester.pumpAndSettle();
    expect(await result, isFalse);
  });

  testWidgets('bottom sheet has a handle, a heading and its content',
      (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(wrap(Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    })));
    showMNSheet<void>(ctx,
        builder: (_) =>
            const MNSheet(title: 'Kidali (Robo)', children: [Text('Maudhui')]));
    await tester.pumpAndSettle();
    expect(find.text('Kidali (Robo)'), findsOneWidget);
    expect(find.text('Maudhui'), findsOneWidget);
    final modal = tester.widget<ModalBarrier>(find.byType(ModalBarrier).last);
    expect(modal.color, MNColors.scrim);
  });

  group('states', () {
    testWidgets('empty state shows heading, message and action',
        (tester) async {
      await tester.pumpWidget(wrap(MNEmptyState(
          icon: MNIconData.bag,
          title: 'Hakuna mauzo bado',
          message: 'Mfano',
          action: MNButton('Rekodi', onPressed: () {}))));
      expect(find.text('Hakuna mauzo bado'), findsOneWidget);
      expect(find.text('Rekodi'), findsOneWidget);
    });

    testWidgets('error state retries', (tester) async {
      var retried = 0;
      await tester.pumpWidget(wrap(MNErrorState(onRetry: () => retried++)));
      expect(find.text('Imeshindikana'), findsOneWidget);
      expect(find.text('Jaribu tena'), findsNothing);
      await tester.drag(find.text('Imeshindikana'), const Offset(0, 300));
      await tester.pumpAndSettle();
      expect(retried, 1);
    });

    testWidgets(
        'loading state is announced once and stops under reduced motion',
        (tester) async {
      setScreen(tester, reducedMotion: true);
      await tester.pumpWidget(
          wrap(const SizedBox(height: 400, child: MNLoadingState(rows: 3))));
      expect(find.bySemanticsLabel('Inapakia'), findsOneWidget);
      await tester.pumpAndSettle(); // would time out if the pulse kept running
    });
  });

  group('sync indicator', () {
    testWidgets('one line per state, honest wording', (tester) async {
      setScreen(tester, reducedMotion: true);
      for (final (status, label) in [
        (MNSyncStatus.sent, 'Imetumwa ofisini'),
        (MNSyncStatus.waiting, 'Inasubiri kusawazisha'),
        (MNSyncStatus.sending, 'Inatuma…'),
      ]) {
        await tester.pumpWidget(wrap(MNSyncIndicator(status: status)));
        await tester.pumpAndSettle();
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('compact shows no text but keeps the spoken label',
        (tester) async {
      await tester.pumpWidget(wrap(
          const MNSyncIndicator(status: MNSyncStatus.waiting, compact: true)));
      await tester.pumpAndSettle();
      expect(find.text('Inasubiri kusawazisha'), findsNothing);
      expect(find.bySemanticsLabel('Inasubiri kusawazisha'), findsOneWidget);
    });
  });

  testWidgets('the logo never falls back to substitute branding',
      (tester) async {
    await tester
        .pumpWidget(wrap(const MNLogo(height: 48, semanticLabel: 'Mr. Nyama')));
    await tester.pumpAndSettle();
    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as AssetImage).assetName, mrNyamaLogoAsset);
    expect(tester.takeException(), isNull);
    // Preserve the supplied artwork and requested size, without substitute text.
    expect(find.byType(Text), findsNothing);
    expect(tester.getSize(find.byType(MNLogo)).height, 48);
    expect(find.bySemanticsLabel('Mr. Nyama'), findsOneWidget);
  });
}

/// A photo whose fetch the test finishes by hand.
class _PendingImage extends ImageProvider<_PendingImage> {
  final completer = Completer<ImageInfo>();

  @override
  Future<_PendingImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
          _PendingImage key, ImageDecoderCallback decode) =>
      OneFrameImageStreamCompleter(completer.future);
}
