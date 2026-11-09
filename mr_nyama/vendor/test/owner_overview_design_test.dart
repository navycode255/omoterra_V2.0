import 'package:mr_nyama_vendor/shared/widgets/icon.dart';
import 'package:mr_nyama_vendor/core/theme/icon_data.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/api/office_repository.dart';
import 'package:mr_nyama_vendor/core/auth/office_session.dart';
import 'package:mr_nyama_vendor/core/l10n/strings.dart';
import 'package:mr_nyama_vendor/features/office/office_home.dart';
import 'package:mr_nyama_vendor/features/office/owner_overview.dart';
import 'package:mr_nyama_vendor/features/office/owner_reference.dart';
import 'helpers.dart';
import 'office_test.dart' show FakeOfficeRepository;

const populated = OwnerOverview(
    sales: 345000,
    supervisorFunds: 12000,
    openStations: 3,
    totalStations: 5,
    changePercent: 12,
    supervisorFundsChangePercent: -8);
const empty = OwnerOverview(
    sales: 0, supervisorFunds: 0, openStations: 0, totalStations: 5);

/// The server's day report, with the cash still with supervisors.
class _ReportOffice extends FakeOfficeRepository
    implements OwnerReportsRepository {
  final int? withSupervisor;
  _ReportOffice(this.withSupervisor);
  @override
  Future<OwnerMoneyOverview> moneyOverview(OwnerPeriod period,
          {String? date}) async =>
      OwnerMoneyOverview.fromJson({
        'period': 'day',
        'totals': {'sales': 50000},
        if (withSupervisor != null) 'with_supervisor': withSupervisor,
      });
}

Future<void> openOverview(WidgetTester tester, OwnerOverview data,
    {String language = 'sw',
    Size size = const Size(390, 844),
    double scale = 1}) async {
  final office = FakeOfficeRepository()..signedIn = true;
  final app = await pumpApp(tester,
      startAs: StartAs.signedOut,
      office: office,
      size: size,
      textScale: scale,
      overrides: [
        languageProvider.overrideWith((ref) => language),
        ownerOverviewProvider.overrideWith((ref) => AsyncData(data)),
      ]);
  await app.container
      .read(officeSessionProvider.notifier)
      .signedIn(office.owner);
  await tester.pumpAndSettle();
}

Future<void> capture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('OVERVIEW_CAPTURES')) return;
  final boundary = tester
      .renderObject<RenderRepaintBoundary>(find.byType(RepaintBoundary).first);
  final image = (await tester.runAsync(() => boundary.toImage(pixelRatio: 2)))!;
  final bytes = await tester
      .runAsync(() => image.toByteData(format: ui.ImageByteFormat.png));
  await tester.runAsync(() async {
    final dir = Directory('../reviews/2026-10-28/overview');
    await dir.create(recursive: true);
    await File('${dir.path}/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
  });
  image.dispose();
}

void main() {
  for (final language in ['sw', 'en']) {
    testWidgets('populated overview uses neutral trends in $language',
        (tester) async {
      await openOverview(tester, populated, language: language);
      expect(find.text('345,000'), findsOneWidget);
      expect(find.text(language == 'sw' ? 'Faida ghafi' : 'Gross profit'),
          findsNothing);
      expect(find.text('TZS 12,000'), findsOneWidget);
      expect(find.byType(OwnerOverviewTrend), findsNWidgets(2));
      expect(
          find.byWidgetPredicate(
              (w) => w is MNIcon && w.icon == MNIconData.overviewUp),
          findsOneWidget);
      expect(
          find.byWidgetPredicate(
              (w) => w is MNIcon && w.icon == MNIconData.overviewDown),
          findsOneWidget);
      for (final icon in tester.widgetList<MNIcon>(find.byWidgetPredicate((w) =>
          w is MNIcon &&
          [MNIconData.overviewUp, MNIconData.overviewDown].contains(w.icon)))) {
        expect(icon.color, OwnerStyle.ink);
      }
      expect(
          find.textContaining(
              language == 'sw' ? 'tofauti za fedha' : 'money differences'),
          findsNothing);
      expect(find.text(language == 'sw' ? 'Fedha' : 'Money'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await capture(tester, 'populated-$language');
    });
    testWidgets('empty overview has concise $language states and no trends',
        (tester) async {
      await openOverview(tester, empty, language: language);
      expect(find.text(language == 'sw' ? 'Hakuna mauzo bado' : 'No sales yet'),
          findsOneWidget);
      expect(
          find.text(language == 'sw'
              ? 'Hakuna kituo kilichofunguliwa'
              : 'No station has opened yet'),
          findsOneWidget);
      expect(find.byType(OwnerOverviewTrend), findsNothing);
      expect(
          find.byWidgetPredicate((w) => w is OwnerGlyph && w.name == 'warning'),
          findsNothing);
      expect(tester.takeException(), isNull);
      await capture(tester, 'empty-$language');
    });
  }
  testWidgets('Kwa msimamizi shows the server figure, not yet confirmed',
      (tester) async {
    final office = _ReportOffice(77000)..signedIn = true;
    final app =
        await pumpApp(tester, startAs: StartAs.signedOut, office: office);
    await app.container
        .read(officeSessionProvider.notifier)
        .signedIn(office.owner);
    await tester.pumpAndSettle();
    expect(find.text('Kwa msimamizi'), findsOneWidget);
    expect(find.text('TZS 77,000'), findsOneWidget);
    expect(find.text('Bado haijathibitishwa'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('a past day shows a dash for Kwa msimamizi', (tester) async {
    final office = _ReportOffice(77000)..signedIn = true;
    final app =
        await pumpApp(tester, startAs: StartAs.signedOut, office: office);
    app.container.read(ownerDayProvider.notifier).state =
        DateTime.utc(2020, 1, 5);
    await app.container
        .read(officeSessionProvider.notifier)
        .signedIn(office.owner);
    await tester.pumpAndSettle();
    expect(find.text('TZS 77,000'), findsNothing);
    expect(find.text('Bado haijathibitishwa'), findsNothing);
    expect(find.text('TZS —'), findsWidgets);
  });
  testWidgets('without the server figure Kwa msimamizi stays a dash',
      (tester) async {
    final office = _ReportOffice(null)..signedIn = true;
    final app =
        await pumpApp(tester, startAs: StartAs.signedOut, office: office);
    await app.container
        .read(officeSessionProvider.notifier)
        .signedIn(office.owner);
    await tester.pumpAndSettle();
    expect(find.text('Bado haijathibitishwa'), findsNothing);
    expect(find.text('TZS —'), findsWidgets);
  });
  testWidgets('unavailable metrics stay distinct from confirmed zero',
      (tester) async {
    await openOverview(
        tester,
        const OwnerOverview(
            totalStations: 5,
            changePercent: 12,
            supervisorFundsChangePercent: -8));
    expect(find.text('Hakuna mauzo bado'), findsNothing);
    expect(find.text('Hakuna kituo kilichofunguliwa'), findsNothing);
    expect(find.text('TZS —'), findsOneWidget);
    expect(find.byType(OwnerOverviewTrend), findsNothing);
  });
  testWidgets('overview controls meet Android touch target sizes',
      (tester) async {
    await openOverview(tester, populated);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  });
  testWidgets('negative sales trend remains neutral', (tester) async {
    await openOverview(
        tester, const OwnerOverview(sales: 12000, changePercent: -12));
    expect(
        tester
            .widget<MNIcon>(find.byWidgetPredicate(
                (w) => w is MNIcon && w.icon == MNIconData.overviewDown))
            .color,
        OwnerStyle.ink);
    expect(find.text('12%'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^−12%')), findsOneWidget);
  });
  for (final language in ['sw', 'en']) {
    testWidgets('overview fits a small phone at double text in $language',
        (tester) async {
      await openOverview(tester, populated,
          language: language, size: const Size(320, 568), scale: 2);
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(ListView).first, const Offset(0, -700));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
