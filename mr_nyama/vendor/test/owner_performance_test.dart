import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:mr_nyama_vendor/shared/widgets/workflow_help.dart';
import 'office_design_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/api/office_repository.dart';
import 'package:mr_nyama_vendor/core/auth/session.dart' show clockProvider;
import 'package:mr_nyama_vendor/core/l10n/strings.dart';
import 'package:mr_nyama_vendor/core/routing/routes.dart';
import 'package:mr_nyama_vendor/features/office/owner_home_tab.dart';
import 'package:mr_nyama_vendor/features/owner/performance_screens.dart'
    show performanceWindowProvider;

import 'office_verification_test.dart'
    show VerificationOffice, openAs, tapVisible;

const sw = Strings('sw');

/// The verification fake plus the owner's performance routes, in memory.
class PerformanceOffice extends VerificationOffice
    implements OwnerPerformanceRepository {
  PerformanceOverview overview = const PerformanceOverview();
  Scorecard vendorCard = const Scorecard();
  Scorecard staffCard = const Scorecard(isVendor: false);
  StationPerformanceDetail station = const StationPerformanceDetail();
  final rated = <String>[];
  final dayCards = <String, Scorecard>{};
  final history = <AreaRating>[];
  OfficeError? refuseRating;
  Object? historyFailure;
  final overviewCalls = <String>[];
  final moneyDayRows = <OfficeMoneyDay>[];
  final handoverRows = <OfficeHandover>[];
  final expenseRows = <OfficeExpense>[];
  final expenseDecisions = <String>[];

  @override
  Future<PerformanceOverview> performanceOverview(PerformancePeriod period,
      {String? date, int attentionLimit = 20}) async {
    overviewCalls.add('${period.wire} $date');
    return overview;
  }

  @override
  Future<Scorecard> vendorScorecard(String vendorId, PerformancePeriod period,
          {String? date}) async =>
      period == PerformancePeriod.day
          ? dayCards[date] ?? vendorCard
          : vendorCard;

  @override
  Future<Scorecard> staffScorecard(String staffId, PerformancePeriod period,
          {String? date}) async =>
      staffCard;

  @override
  Future<StationPerformanceDetail> stationPerformance(
          String stationId, PerformancePeriod period,
          {String? date}) async =>
      station;

  @override
  Future<OwnerRating> rate(
      {String? vendorId,
      String? staffId,
      required int stars,
      String? comment}) async {
    rated.add('${vendorId ?? staffId} $stars ${comment ?? ''}');
    return OwnerRating(id: 'r1', stars: stars, comment: comment);
  }

  @override
  Future<List<OwnerRating>> ratings(
          {String? vendorId, String? staffId}) async =>
      const [];

  @override
  Future<AreaRating> rateArea(
      {String? vendorId,
      String? staffId,
      required String date,
      required String area,
      required int score}) async {
    if (refuseRating != null) throw refuseRating!;
    rated.add('${vendorId ?? staffId} $date $area $score');
    final row = AreaRating(
        id: 'a${history.length}',
        area: area,
        score: score,
        previousScore: 50,
        ratedBy: const MoneyParty(id: 'o', name: 'Owner'));
    history.insert(0, row);
    return row;
  }

  @override
  Future<List<AreaRating>> areaRatings(
      {String? vendorId, String? staffId, required String date}) async {
    if (historyFailure != null) throw historyFailure!;
    return history;
  }

  @override
  Future<List<OfficeMoneyDay>> moneyDays(
          {required String stationId, required String businessDate}) async =>
      moneyDayRows;

  @override
  Future<List<OfficeHandover>> handovers(
          {String? stationId,
          String? vendorId,
          String? from,
          String? to,
          String? status}) async =>
      handoverRows;

  @override
  Future<List<OfficeExpense>> expenses(
          {String? stationId,
          String? from,
          String? to,
          String? status,
          String? paidBy}) async =>
      expenseRows;

  @override
  Future<OfficeExpense> decideExpense(String expenseId,
      {required bool approve, required String reason}) async {
    expenseDecisions.add('$expenseId:$approve:$reason');
    final index = expenseRows.indexWhere((row) => row.id == expenseId);
    final original = expenseRows[index];
    final decided = OfficeExpense(
        id: original.id,
        station: original.station,
        businessDate: original.businessDate,
        category: original.category,
        item: original.item,
        amount: original.amount,
        note: original.note,
        paidBy: original.paidBy,
        vendor: original.vendor,
        recordedBy: original.recordedBy,
        status: approve ? 'approved' : 'rejected',
        decidedBy: const MoneyParty(id: 'owner', name: 'Owner'),
        decidedAt: DateTime.utc(2026, 11, 1, 12),
        decisionReason: reason,
        createdAt: original.createdAt);
    expenseRows[index] = decided;
    return decided;
  }
}

const juma = MoneyParty(id: 'v1', name: 'Juma Ali', code: 'V-0001');
const neema = MoneyParty(id: 'st9', name: 'Neema Said');
const kariakoo = MoneyParty(id: 's1', name: 'Kariakoo', code: 'KRK');

final _fullOverview = PerformanceOverview.fromJson(const {
  'from': '2026-10-26',
  'to': '2026-11-01',
  'totals': {
    'sales': 144000,
    'chickens': '16',
    'profit': 43000,
    'profit_unknown_days': 1,
    'bonus_earned': 1000,
    'bonus_estimated': 600,
    'bonus_adjustments': 0,
  },
  'stations': [
    {
      'station': {'id': 's1', 'code': 'KRK', 'name': 'Kariakoo'},
      'sales': 144000,
      'chickens': '16',
      'profit': 43000,
      'profit_target': 45000,
      'vendors': [
        {'id': 'v1', 'name': 'Juma Ali', 'code': 'V-0001'}
      ],
    }
  ],
  'attention': [
    {
      'kind': 'money_short',
      'station': {'id': 's1', 'code': 'KRK', 'name': 'Kariakoo'},
      'vendor': {'id': 'v1', 'name': 'Juma Ali', 'code': 'V-0001'},
      'business_date': '2026-10-25',
      'detail': {
        'status': 'outstanding',
        'due': 10000,
        'received': 6000,
        'remaining': 4000,
      },
    },
    {
      'kind': 'not_synced',
      'station': {'id': 's1', 'code': 'KRK', 'name': 'Kariakoo'},
      'vendor': {'id': 'v1', 'name': 'Juma Ali', 'code': 'V-0001'},
      'business_date': '2026-10-25',
      'detail': {'last_synced_at': '2026-10-30T09:00:00Z'},
    },
    {
      'kind': 'expense_pending',
      'station': {'id': 's1', 'code': 'KRK', 'name': 'Kariakoo'},
      'vendor': {'id': 'v1', 'name': 'Juma Ali', 'code': 'V-0001'},
      'business_date': '2026-10-25',
      'detail': {
        'expense_id': 'e1',
        'amount': 3000,
        'category': 'transport',
        'item': 'Matatu',
      },
    },
  ],
  'attention_counts': {'money_short': 1, 'not_synced': 1, 'expense_pending': 3},
  'ranking': [
    {
      'kind': 'vendor',
      'person': {'id': 'v1', 'name': 'Juma Ali', 'code': 'V-0001'},
      'card': 'vendor',
      'score': 86,
      'stars': 4,
      'days': 1,
    },
    {
      'kind': 'staff',
      'person': {'id': 'st9', 'name': 'Neema Said'},
      'card': 'supervisor',
      'score': 72,
      'stars': 3,
      'days': 1,
    },
  ],
});

final _jumaCard = Scorecard.fromJson(const {
  'vendor': {'id': 'v1', 'name': 'Juma Ali', 'code': 'V-0001'},
  'from': '2026-10-26',
  'to': '2026-11-01',
  'score': 86,
  'stars': 4,
  'areas': {'sales': 100, 'money': 50, 'stock': null},
  'weights': {'sales': 50, 'money': 50, 'stock': 0},
  'days': [
    {
      'business_date': '2026-10-26',
      'station': {'id': 's1', 'code': 'KRK', 'name': 'Kariakoo'},
      'score': 86,
      'stars': 4,
      'areas': {'sales': 100, 'money': 50, 'stock': null},
      'reasons': {'money': 'Handed over 54,000 of 108,000'},
    }
  ],
  'bonus': {
    'earned': 1000,
    'estimated': 0,
    'adjustments': 0,
    'chicken_equivalents': '12'
  },
});

PerformanceOffice office() => PerformanceOffice()
  ..verificationList.add(
      const OfficeVerificationStation(id: 's1', code: 'KRK', name: 'Kariakoo'))
  ..overview = _fullOverview
  ..moneyDayRows.add(OfficeMoneyDay(
      vendorDayId: 'vd1',
      vendor: juma,
      businessDate: DateTime.utc(2026, 10, 25),
      cashDue: 10000,
      handedOver: 6000,
      confirmed: 6000,
      remaining: 4000,
      state: MoneyDayState.short))
  ..handoverRows.add(OfficeHandover(
      id: 'h1',
      vendor: juma,
      station: kariakoo,
      businessDate: DateTime.utc(2026, 10, 25),
      amount: 6000,
      receivedAt: DateTime.utc(2026, 10, 25, 16),
      recordedBy: const MoneyParty(id: 'finance', name: 'Finance'),
      status: 'recorded'))
  ..expenseRows.add(OfficeExpense(
      id: 'e1',
      station: kariakoo,
      businessDate: DateTime.utc(2026, 10, 25),
      category: 'transport',
      item: 'Matatu',
      amount: 3000,
      note: 'Goods pickup',
      paidBy: 'vendor',
      vendor: juma,
      recordedBy: juma,
      status: 'pending',
      createdAt: DateTime.utc(2026, 10, 25, 15)))
  ..vendorCard = _jumaCard
  ..staffCard = Scorecard.fromJson(const {
    'staff': {'id': 'st9', 'name': 'Neema Said'},
    'card': 'supervisor',
    'score': 72,
    'stars': 3,
    'areas': {'stations': 86, 'speed': 100, 'rating': null},
    'weights': {'stations': 50, 'speed': 50},
    'days': [],
  })
  ..station = StationPerformanceDetail.fromJson(const {
    'station': {'id': 's1', 'code': 'KRK', 'name': 'Kariakoo'},
    'sales': 144000,
    'verified_sales': 144000,
    'expenses': 5000,
    'chickens': '16',
    'profit': 43000,
    'profit_target': 45000,
    'open_exceptions': 2,
    'days': [
      {
        'business_date': '2026-10-26',
        'sales': 144000,
        'expenses': 5000,
        'profit': 43000,
        'chickens': '16',
        'vendors_sharing': 1
      }
    ],
    'vendors': [
      {
        'vendor': {'id': 'v1', 'name': 'Juma Ali', 'code': 'V-0001'},
        'chickens': '16',
        'earned': 1000,
        'estimated': 0,
        'days': 1
      }
    ],
  });

/// 26 October 2026, noon in Dar es Salaam.
final _clock =
    clockProvider.overrideWithValue(() => DateTime.utc(2026, 10, 26, 9));

const _owner = ['business_owner'];

void main() {
  for (final language in ['sw', 'en']) {
    testWidgets(
        'station performance starts with totals and keeps guidance in help in $language',
        (tester) async {
      if (const bool.fromEnvironment('PERFORMANCE_CAPTURES')) {
        final loader = FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
        await tester.runAsync(loader.load);
      }
      final app = await openAs(tester, office(),
          roles: _owner,
          route: MNRoutes.officePerformanceStation('s1'),
          overrides: [_clock]);
      app.container.read(languageProvider.notifier).state = language;
      await tester.pumpAndSettle();
      final s = Strings(language);
      expect(find.text(s.opStationPerformanceHelp), findsNothing);
      expect(find.text(s.opTarget('TSh 45,000')), findsNothing);
      expect(find.text('Juma Ali'), findsOneWidget);
      expect(find.text(s.opOpenProblemsShort), findsOneWidget);
      if (const bool.fromEnvironment('PERFORMANCE_CAPTURES')) {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byType(RepaintBoundary).first);
        boundary.markNeedsPaint();
        await tester.pump();
        final image =
            (await tester.runAsync(() => boundary.toImage(pixelRatio: 2)))!;
        final bytes = await tester
            .runAsync(() => image.toByteData(format: ui.ImageByteFormat.png));
        await tester.runAsync(() async {
          final dir = Directory('../reviews/2026-10-29/station-performance');
          await dir.create(recursive: true);
          await File('${dir.path}/station-$language.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
        });
        image.dispose();
      }
      await tester.tap(find.byType(MNWorkflowHelp));
      await tester.pumpAndSettle();
      expect(find.text(s.opStationPerformanceHelp), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('the overview shows totals, attention and the ranking',
      (tester) async {
    final o = office();
    await openAs(tester, o,
        roles: _owner, route: MNRoutes.officePerformance, overrides: [_clock]);
    expect(o.overviewCalls.single, 'week null');
    expect(find.text('TSh 144,000'), findsWidgets);
    expect(find.text(sw.opPieces('16')), findsOneWidget);
    expect(find.text(sw.opProfitUnknown(1)), findsOneWidget);
    expect(find.text('TSh 1,000'), findsOneWidget);
    expect(find.text(sw.attentionKindName('expense_pending')), findsOneWidget);
    expect(find.text(sw.opAttentionReview), findsOneWidget);
    expect(find.text(sw.opAttentionSync), findsOneWidget);
    expect(find.text(sw.opAttentionPendingReview), findsOneWidget);
    await tester.tap(find.text(sw.opViewAll));
    await tester.pumpAndSettle();
    expect(find.text(sw.attentionMore(2)), findsOneWidget);
    await expandOfficeDetails(tester, sw.opRanking);
    await tester.scrollUntilVisible(find.text('Neema Said'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('86 · ${sw.opStars(4)}'), findsOneWidget);
    expect(find.text(sw.opScoresNotSet), findsNothing);
    // Switching to the month asks the server again.
    await tester.scrollUntilVisible(find.text(sw.opPeriodMonth), -200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text(sw.opPeriodMonth));
    await tester.pumpAndSettle();
    expect(o.overviewCalls.last, 'month null');
    expect(tester.takeException(), isNull);
  });

  testWidgets('cash attention opens from performance and shows the open state',
      (tester) async {
    final o = office();
    await openAs(tester, o,
        roles: _owner, route: MNRoutes.officePerformance, overrides: [_clock]);
    await tester.tap(find.text(sw.attentionKindName('money_short')));
    await tester.pumpAndSettle();
    expect(find.text(sw.opCashNeedsReview), findsOneWidget);
    expect(find.text(sw.opCashDetails), findsOneWidget);
    expect(find.text('TSh 10,000'), findsOneWidget);
    expect(find.text('TSh 4,000'), findsOneWidget);
    expect(find.text(sw.moneyHandoverWaiting), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cash attention shows the server-resolved state', (tester) async {
    final o = office();
    o.moneyDayRows[0] = OfficeMoneyDay(
        vendorDayId: 'vd1',
        vendor: juma,
        businessDate: DateTime.utc(2026, 10, 25),
        cashDue: 10000,
        handedOver: 10000,
        confirmed: 10000,
        remaining: 0,
        state: MoneyDayState.full);
    await openAs(tester, o,
        roles: _owner,
        route: MNRoutes.officePerformanceAttention(
            kind: 'money_short',
            stationId: 's1',
            vendorId: 'v1',
            date: '2026-10-25'),
        overrides: [_clock]);
    expect(find.text(sw.opDifferenceResolved), findsOneWidget);
    expect(find.text(sw.moneyFull), findsOneWidget);
    expect(find.text(sw.opReviewDifference), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone sync shows waiting and recovered states from overview',
      (tester) async {
    final waiting = office();
    await openAs(tester, waiting,
        roles: _owner,
        route: MNRoutes.officePerformanceAttention(
            kind: 'not_synced',
            stationId: 's1',
            vendorId: 'v1',
            lastSyncedAt: '2026-10-30T09:00:00Z'),
        overrides: [_clock]);
    expect(find.text(sw.opWaitingForDevice), findsOneWidget);
    expect(find.text(sw.opSyncPendingPhone), findsOneWidget);
    expect(find.text(sw.opSyncHistoryUnavailable), findsOneWidget);
    expect(find.textContaining(sw.opLastSync), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    final recovered = office()
      ..overview = PerformanceOverview.fromJson(const {
        'attention': [],
        'attention_counts': {},
      });
    await openAs(tester, recovered,
        roles: _owner,
        route: MNRoutes.officePerformanceAttention(
            kind: 'not_synced', stationId: 's1', vendorId: 'v1'),
        overrides: [_clock]);
    expect(find.text(sw.opSyncNoAlertTitle), findsOneWidget);
    expect(find.text(sw.opNoCurrentSyncAlert), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('expense attention records approval and shows its audit state',
      (tester) async {
    final o = office();
    await openAs(tester, o,
        roles: _owner,
        route: MNRoutes.officePerformanceAttention(
            kind: 'expense_pending',
            stationId: 's1',
            vendorId: 'v1',
            recordId: 'e1',
            date: '2026-10-25'),
        overrides: [_clock]);
    expect(find.text(sw.opAwaitingApproval), findsOneWidget);
    expect(find.text(sw.moneyApproveExpense), findsOneWidget);
    expect(find.text(sw.moneyRejectExpense), findsOneWidget);

    await tester.tap(find.text(sw.moneyApproveExpense));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'receipt reviewed');
    await tester.tap(find.text(sw.moneyApproveExpense).last);
    await tester.pumpAndSettle();

    expect(o.expenseDecisions, ['e1:true:receipt reviewed']);
    expect(find.text(sw.moneyExpenseApproved), findsOneWidget);
    expect(find.text('receipt reviewed'), findsOneWidget);
    expect(find.text(sw.moneyRejectExpense), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('overview matches the reference scroll states and navigation',
      (tester) async {
    final app = await openAs(tester, office(),
        roles: _owner, route: MNRoutes.officePerformance, overrides: [_clock]);
    expect(find.text(sw.opTitle), findsOneWidget);
    expect(find.text(sw.opPeriodWeek), findsOneWidget);
    expect(
        find.text(sw.opRange(sw.date(DateTime.utc(2026, 10, 26)),
            sw.date(DateTime.utc(2026, 11, 1)))),
        findsOneWidget);
    expect(find.text(sw.ownerSummary), findsOneWidget);
    expect(find.text(sw.stations), findsNWidgets(2));
    expect(find.text(sw.ownerAccount), findsOneWidget);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(find.text(sw.opTitle), findsNWidgets(2));
    await tester.tap(find.text(sw.stations).last);
    await tester.pumpAndSettle();
    expect(app.container.read(ownerHomeTabProvider), 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a ranked vendor opens their scorecard', (tester) async {
    final o = office();
    await openAs(tester, o,
        roles: _owner, route: MNRoutes.officePerformance, overrides: [_clock]);
    await expandOfficeDetails(tester, sw.opRanking);
    await tapVisible(tester, find.text('Juma Ali').last);
    expect(find.text('Juma Ali'), findsWidgets);
    expect(find.text(sw.opAreaValue(null)), findsWidgets); // stock not measured
    expect(find.text(sw.opPayments), findsOneWidget);
    await tester.scrollUntilVisible(find.textContaining('Kariakoo'), 200,
        scrollable: find.byType(Scrollable).first);
  });

  testWidgets('without weights the scorecard says scores are not set',
      (tester) async {
    final o = office()
      ..vendorCard = Scorecard.fromJson(const {
        'vendor': {'id': 'v1', 'name': 'Juma Ali'},
        'score': null,
        'stars': null,
        'areas': {'sales': 100},
        'weights': null,
        'days': [],
      })
      ..overview = PerformanceOverview.fromJson(const {
        'totals': {},
        'ranking': [
          {
            'kind': 'vendor',
            'person': {'id': 'v1', 'name': 'Juma Ali'},
            'card': 'vendor',
            'score': null,
            'stars': null
          }
        ]
      });
    await openAs(tester, o,
        roles: _owner, route: MNRoutes.officePerformance, overrides: [_clock]);
    await expandOfficeDetails(tester, sw.opRanking);
    await tester.scrollUntilVisible(find.text(sw.opScoresNotSet), 200,
        scrollable: find.byType(Scrollable).first);
    await tapVisible(tester, find.text('Juma Ali'));
    expect(find.text(sw.opNoScore), findsOneWidget);
    expect(find.text(sw.opWeightsNotSet), findsOneWidget);
  });

  testWidgets('station warnings stay visible beside station figures',
      (tester) async {
    final o = office()
      ..station = StationPerformanceDetail.fromJson(const {
        'station': {'id': 's1', 'name': 'Kariakoo'},
        'sales': 40000,
        'verified_sales': 20000,
        'expenses': 0,
        'pending_expenses': 1000,
        'chickens': '1',
        'profit': null,
        'profit_unknown_days': 2,
        'open_exceptions': 2,
        'days': [],
        'vendors': [],
      });
    await openAs(tester, o,
        roles: _owner,
        route: MNRoutes.officePerformanceStation('s1'),
        overrides: [_clock]);
    expect(find.text(sw.opProfitIncomplete), findsOneWidget);
    expect(find.text(sw.opProfitMissingDays(2)), findsOneWidget);
    expect(find.text('TSh 1,000'), findsOneWidget);
    expect(find.text(sw.opOpenProblemsShort), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text(sw.opTargetUnset), findsNothing);
  });

  testWidgets('the station page shows summaries and selecting a day filters it',
      (tester) async {
    final app = await openAs(tester, office(),
        roles: _owner,
        route: MNRoutes.officePerformanceStation('s1'),
        overrides: [_clock]);
    expect(find.text(sw.opPeriodWeek), findsOneWidget);
    expect(
        find.text(sw.opRange(sw.date(DateTime.utc(2026, 10, 26)),
            sw.date(DateTime.utc(2026, 11, 1)))),
        findsOneWidget);
    expect(find.text(sw.opExpenses), findsOneWidget);
    expect(find.text(sw.opVerifiedChickens), findsOneWidget);
    expect(find.text(sw.opPendingExpensesLabel), findsOneWidget);
    expect(find.text(sw.opTarget('TSh 45,000')), findsNothing);
    expect(find.text('Juma Ali'), findsOneWidget);
    expect(find.text(sw.opVendorVerifiedChickens('16')), findsOneWidget);
    expect(find.text(sw.opVendorBonusEarned('TSh 1,000')), findsOneWidget);
    expect(find.text(sw.opStationDayReviewHint), findsOneWidget);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Kariakoo'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Kariakoo')).dy, lessThan(100));
    final date = find.text(sw.date(DateTime.utc(2026, 10, 26)));
    await tester.ensureVisible(date);
    await tester.tap(date);
    await tester.pumpAndSettle();
    expect(app.container.read(performanceWindowProvider),
        (period: PerformancePeriod.day, day: DateTime.utc(2026, 10, 26)));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a supervisor card for staff', (tester) async {
    final o = office();
    await openAs(tester, o,
        roles: _owner,
        route: MNRoutes.officePerformanceStaff('st9'),
        overrides: [_clock]);
    expect(find.text(sw.opCardName('supervisor')), findsOneWidget);
    expect(find.text(sw.opAreaName('speed')), findsOneWidget);
  });

  testWidgets('only the owner sees performance', (tester) async {
    final app = await openAs(tester, office(), overrides: [_clock]);
    for (final route in [
      MNRoutes.officePerformance,
      MNRoutes.officePerformanceVendor('v1'),
      MNRoutes.officePerformanceStation('s1'),
      MNRoutes.officePerformanceAttention(
          kind: 'money_short',
          stationId: 's1',
          vendorId: 'v1',
          date: '2026-10-25'),
    ]) {
      app.router.go(route);
      await tester.pumpAndSettle();
      expect(find.text(sw.notAllowed), findsOneWidget, reason: route);
    }
  });

  testWidgets('performance screens fit 320 px at 2× text', (tester) async {
    final app = await openAs(tester, office(),
        roles: _owner,
        size: const Size(320, 640),
        textScale: 2,
        overrides: [_clock]);
    for (final route in [
      MNRoutes.officePerformance,
      MNRoutes.officePerformanceVendor('v1'),
      MNRoutes.officePerformanceStaff('st9'),
      MNRoutes.officePerformanceStation('s1'),
      MNRoutes.officePerformanceAttention(
          kind: 'money_short',
          stationId: 's1',
          vendorId: 'v1',
          date: '2026-10-25'),
      MNRoutes.officePerformanceAttention(
          kind: 'not_synced', stationId: 's1', vendorId: 'v1'),
      MNRoutes.officePerformanceAttention(
          kind: 'expense_pending',
          stationId: 's1',
          vendorId: 'v1',
          recordId: 'e1',
          date: '2026-10-25'),
    ]) {
      app.router.go(route);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: route);
    }
  });
}
