import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/api/office_repository.dart';
import 'package:mr_nyama_vendor/core/routing/routes.dart';
import 'package:mr_nyama_vendor/shared/widgets/sheet.dart';
import 'package:mr_nyama_vendor/shared/widgets/states.dart';

import 'office_money_test.dart' show MoneyOffice, openMoney, tapVisible;

const _json = {
  'period': 'day',
  'from': '2026-10-21',
  'to': '2026-10-21',
  'totals': {
    'sales': 120000,
    'verified_sales': 90000,
    'expenses': 135000,
    'pending_expenses': 4000,
    'balance': -15000
  },
  'expense_categories': [
    {'category': 'Mkaa', 'amount': 100000, 'share': 74.1},
    {'category': 'Mafuta', 'amount': 35000, 'share': 25.9},
  ],
  'stations': [
    {
      'station': {'id': 's1', 'code': 'KA01', 'name': 'Kariakoo'},
      'sales': 120000,
      'verified_sales': 90000,
      'expenses': 35000,
      'pending_expenses': 4000,
      'balance': 85000,
      'expense_categories': [
        {'category': 'Mafuta', 'amount': 35000, 'share': 100.0}
      ]
    },
    {
      'station': {'id': 's2', 'code': 'SI01', 'name': 'Sinza'},
      'sales': 0,
      'verified_sales': 0,
      'expenses': 100000,
      'pending_expenses': 0,
      'balance': -100000,
      'expense_categories': [
        {'category': 'Mkaa', 'amount': 100000, 'share': 100.0}
      ]
    },
  ],
};

/// The shared fake plus the owner report; records the periods asked for.
class ReportOffice extends MoneyOffice implements OwnerReportsRepository {
  final asked = <OwnerPeriod>[];
  final dates = <String?>[];

  /// When set, answers wait for it (the server is still working).
  Completer<void>? gate;
  @override
  Future<OwnerMoneyOverview> moneyOverview(OwnerPeriod period,
      {String? date}) async {
    asked.add(period);
    dates.add(date);
    await gate?.future;
    final day = date ?? _json['from'];
    return OwnerMoneyOverview.fromJson(
        {..._json, 'period': period.wire, 'from': day, 'to': day});
  }
}

void main() {
  test('the overview parses totals, categories and stations', () {
    final o = OwnerMoneyOverview.fromJson(_json);
    expect(o.period, OwnerPeriod.day);
    expect(o.totals.sales, 120000);
    expect(o.totals.balance, -15000);
    expect(o.categories.map((c) => c.category), ['Mkaa', 'Mafuta']);
    expect(o.categories.first.share, 74.1);
    expect(o.stations.map((s) => s.code), ['KA01', 'SI01']);
    expect(o.openStations, isNull);
    expect(
        OwnerMoneyOverview.fromJson({..._json, 'open_stations': 2})
            .openStations,
        2);
    expect(o.stations.last.categories.single.amount, 100000);
    // Missing fields never break parsing.
    final empty = OwnerMoneyOverview.fromJson(const {});
    expect(empty.totals.sales, 0);
    expect(empty.stations, isEmpty);
    expect(empty.categories, isEmpty);
  });

  testWidgets(
      'the owner sees all stations, the largest expenses and each '
      'station', (tester) async {
    final office = ReportOffice()..signedIn = true;
    await openMoney(tester, office,
        roles: const ['business_owner'], route: MNRoutes.officeMoneyReport);
    expect(find.text('Mapato na matumizi'), findsOneWidget);
    expect(find.text('Vituo vyote · Mapato'), findsOneWidget);
    expect(find.text('120,000'), findsWidgets);
    expect(find.text('Yaliyothibitishwa: 90,000'), findsOneWidget);
    expect(find.text('−15,000'), findsOneWidget);
    expect(find.text('Matumizi yanayosubiri idhini: 4,000'), findsWidgets);
    expect(find.text('Matumizi makubwa'), findsOneWidget);
    expect(find.text('74.1%'), findsOneWidget);
    expect(find.text('Kariakoo · KA01'), findsOneWidget);
    expect(find.text('Sinza · SI01'), findsOneWidget);
    expect(find.text('−100,000'), findsOneWidget);

    // A station opens to show its own expense categories.
    expect(find.text('100.0%'), findsNothing);
    await tapVisible(tester, find.text('Sinza · SI01'));
    expect(find.text('100.0%'), findsOneWidget);

    await tapVisible(tester, find.text('Mwezi huu'));
    expect(office.asked.last, OwnerPeriod.month);
  });

  testWidgets('Muhtasari shows Jana or a chosen day, and the report follows',
      (tester) async {
    final office = ReportOffice()..signedIn = true;
    await openMoney(tester, office, roles: const ['business_owner']);
    expect(find.text('Mauzo leo'), findsOneWidget);
    expect(office.dates.first, isNull); // today
    await tapVisible(tester, find.text('Leo'));
    await tapVisible(tester,
        find.descendant(of: find.byType(MNSheet), matching: find.text('Jana')));
    await tapVisible(tester, find.text('Tumia tarehe hii'));
    // Yesterday's sales, compared with the day before.
    expect(find.text('Jana'), findsOneWidget);
    expect(find.text('Mauzo jana'), findsOneWidget);
    expect(office.dates, containsAllInOrder(['2026-10-20', '2026-10-19']));
    await tapVisible(tester, find.text('120,000'));
    expect(find.text('Siku'), findsOneWidget);
    expect(office.dates.last, '2026-10-20');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a new day shows skeletons until its figures arrive',
      (tester) async {
    final office = ReportOffice()..signedIn = true;
    await openMoney(tester, office, roles: const ['business_owner']);
    expect(find.byType(MNSkeleton), findsNothing);
    await tapVisible(tester, find.text('Leo'));
    await tapVisible(tester,
        find.descendant(of: find.byType(MNSheet), matching: find.text('Jana')));
    office.gate = Completer<void>();
    await tester.tap(find.text('Tumia tarehe hii'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    // Sales, change and both metrics wait; yesterday's label is already up.
    expect(find.byType(MNSkeleton), findsNWidgets(3));
    expect(find.text('120,000'), findsNothing);
    expect(find.text('Mauzo jana'), findsOneWidget);
    office.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(MNSkeleton), findsNothing);
    expect(find.text('120,000'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a day already seen comes back at once, without a request',
      (tester) async {
    final office = ReportOffice()..signedIn = true;
    await openMoney(tester, office, roles: const ['business_owner']);
    Future<void> choose(String chip) async {
      await tapVisible(tester, find.text(chip == 'Jana' ? 'Leo' : 'Jana'));
      await tapVisible(tester,
          find.descendant(of: find.byType(MNSheet), matching: find.text(chip)));
      await tester.tap(find.text('Tumia tarehe hii'));
    }

    await choose('Jana');
    await tester.pumpAndSettle();
    final asked = office.dates.length;
    // Back to today and to yesterday again: both are kept.
    office.gate = Completer<void>(); // a request now would hang
    await choose('Leo');
    await tester.pump();
    expect(find.byType(MNSkeleton), findsNothing);
    expect(find.text('Mauzo leo'), findsOneWidget);
    await tester.pumpAndSettle();
    await choose('Jana');
    await tester.pump();
    expect(find.byType(MNSkeleton), findsNothing);
    expect(find.text('120,000'), findsOneWidget);
    expect(office.dates.length, asked);
    office.gate!.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('staff other than the owner are refused', (tester) async {
    final office = ReportOffice()..signedIn = true;
    await openMoney(tester, office,
        roles: const ['finance'], route: MNRoutes.officeMoneyReport);
    expect(find.text('Matumizi makubwa'), findsNothing);
    expect(office.asked, isEmpty);
  });

  testWidgets('the report fits a small phone at 2x text', (tester) async {
    final office = ReportOffice()..signedIn = true;
    await openMoney(tester, office,
        roles: const ['business_owner'],
        route: MNRoutes.officeMoneyReport,
        size: const Size(320, 640),
        textScale: 2);
    expect(tester.takeException(), isNull);
    await tapVisible(tester, find.text('Kariakoo · KA01'));
    expect(tester.takeException(), isNull);
  });
}
