import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omoterra/core/theme/theme.dart';
import 'package:omoterra/shared/models/domain.dart';
import 'package:omoterra/shared/widgets/components.dart';

Widget host(SupplyListing listing) => MaterialApp(
    theme: omoterraTheme(),
    home: Scaffold(body: ListingCard(listing, onTap: () {})));

void main() {
  testWidgets('In stock is plain green text beside the name, not a pill',
      (tester) async {
    await tester.pumpWidget(host(const SupplyListing(
        id: '1',
        category: 'broilers',
        unitType: 'bird',
        region: 'Kibaha, Pwani',
        price: '11000',
        available: '240')));
    await tester.pump();
    final label = find.text('In stock');
    expect(label, findsOneWidget);
    // Same line as the category name.
    expect(tester.getCenter(label).dy,
        closeTo(tester.getCenter(find.text('Broilers')).dy, 4));
    // Nothing drawn behind it: the card's own box is its only decoration.
    expect(
        find.ancestor(
            of: label,
            matching: find.byWidgetPredicate((w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration as BoxDecoration).borderRadius != null)),
        findsOneWidget);
  });

  testWidgets('a long category name is shown in full, never cut short',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(const SupplyListing(
        id: '1',
        category: 'local_chicken',
        unitType: 'bird',
        region: 'Morogoro',
        price: '18000',
        available: '75')));
    await tester.pump();
    final name = tester.widget<Text>(find.text('Local Chicken'));
    expect(name.overflow, isNot(TextOverflow.ellipsis));
    expect(name.maxLines, isNull);
    expect(find.text('In stock'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('there is no separate View button — the whole card is tappable',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
        theme: omoterraTheme(),
        home: Scaffold(
            body: ListingCard(
                const SupplyListing(
                    id: '2',
                    category: 'cattle',
                    unitType: 'animal',
                    region: 'Pwani',
                    price: '1500000',
                    available: '6'),
                onTap: () => taps++))));
    await tester.pump();

    expect(find.text('View'), findsNothing);
    await tester.tap(find.byType(ListingCard));
    expect(taps, 1);
  });

  testWidgets('a long cattle price is shown in full, not truncated',
      (tester) async {
    // TZS 1,500,000 / animal is the longest price/unit combination in the
    // catalogue; without a View button crowding it, the price must still
    // render in full rather than being cut off.
    await tester.pumpWidget(host(const SupplyListing(
        id: '3',
        category: 'cattle',
        unitType: 'animal',
        region: 'Pwani',
        price: '1500000',
        available: '6')));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('1,500,000'), findsOneWidget);
  });

  testWidgets('the price stays on screen and unclipped at 320px width',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(host(const SupplyListing(
        id: '4',
        category: 'cattle',
        unitType: 'animal',
        region: 'Pwani',
        price: '1500000',
        available: '6')));
    await tester.pump();
    expect(tester.takeException(), isNull);

    // The price must shrink to fit rather than being cut off mid-number —
    // an ellipsis here would hide part of the amount, which is worse than a
    // smaller font.
    expect(find.textContaining('1,500,000'), findsOneWidget);
  });
}
