import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/api/vendor_repository.dart';
import 'package:mr_nyama_vendor/core/data/database.dart';
import 'package:mr_nyama_vendor/core/l10n/strings.dart';
import 'package:mr_nyama_vendor/core/routing/routes.dart';

import 'helpers.dart';

const sw = Strings('sw');

/// A real queued record in the outbox, created at [at].
Future<void> queue(TestApp app, String id, DateTime at,
    {String status = 'waiting'}) async {
  await app.db.into(app.db.outbox).insert(OutboxCompanion.insert(
      opId: id,
      opType: 'sale',
      vendorId: 'v1',
      stationKey: 'S1',
      businessDate: '2026-10-01',
      payload: '{}',
      createdAt: at,
      status: Value(status)));
}

FakeVendorRepository offline() => FakeVendorRepository()
  ..syncFailure = const AuthFailure(AuthFailureKind.offline);

// 2026-10-31 10:00 in Dar es Salaam is 07:00 UTC.
final noon = DateTime.utc(2026, 10, 31, 7);

void main() {
  group('sync screen', () {
    testWidgets('unsent records: wait time and the plain consequence',
        (tester) async {
      final app = await pumpApp(tester, api: offline(), now: noon);
      await queue(app, 'a', noon.subtract(const Duration(hours: 5)));
      await queue(app, 'b', noon.subtract(const Duration(minutes: 10)));
      app.router.go(MNRoutes.sync);
      await tester.pumpAndSettle();
      expect(find.text(sw.unsentConsequence), findsOneWidget);
      expect(
          find.text(sw.unsentWaited(const Duration(hours: 5))), findsOneWidget);
      expect(sw.unsentConsequence,
          'Kumbukumbu hizi zipo kwenye simu hii tu. Simu ikipotea, zinapotea.');
    });

    testWidgets('nothing unsent: the all-sent line and no consequence',
        (tester) async {
      final app = await pumpApp(tester, now: noon);
      app.router.go(MNRoutes.sync);
      await tester.pumpAndSettle();
      expect(find.text(sw.allSent), findsOneWidget);
      expect(find.text(sw.unsentConsequence), findsNothing);
    });

    testWidgets('a record under office review is not unsent', (tester) async {
      final app = await pumpApp(tester, now: noon);
      await queue(app, 'c', noon.subtract(const Duration(days: 5)),
          status: 'conflict');
      app.router.go(MNRoutes.sync);
      await tester.pumpAndSettle();
      expect(find.text(sw.unsentConsequence), findsNothing);
    });
  });

  group('Nyumbani row', () {
    // Business dates in Tanzanian time: 21:30 UTC is already the next day.
    testWidgets('48 hours but only one business day apart: no row',
        (tester) async {
      final now = DateTime.utc(2026, 10, 31, 20); // 31 Oct 23:00
      final app = await pumpApp(tester, api: offline(), now: now);
      await queue(app, 'a', DateTime.utc(2026, 10, 29, 21, 10)); // 30 Oct 00:10
      await tester.pumpAndSettle();
      expect(find.text(sw.unsentSince(sw.date(DateTime(2026, 10, 30)))),
          findsNothing);
    });

    testWidgets(
        'a little over 24 hours but two business dates: row, opens sync',
        (tester) async {
      final now = DateTime.utc(2026, 10, 31, 21, 5); // 1 Nov 00:05
      final app = await pumpApp(tester, api: offline(), now: now);
      await queue(app, 'a', DateTime.utc(2026, 10, 30, 20, 55)); // 30 Oct 23:55
      await tester.pumpAndSettle();
      final row = find.text(sw.unsentSince(sw.date(DateTime(2026, 10, 30))));
      expect(row, findsOneWidget);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.text(sw.syncTitle), findsWidgets);
      expect(find.text(sw.unsentConsequence), findsOneWidget);
    });

    testWidgets('records waiting only today: no row', (tester) async {
      final app = await pumpApp(tester, api: offline(), now: noon);
      await queue(app, 'a', noon.subtract(const Duration(hours: 3)));
      await tester.pumpAndSettle();
      expect(find.textContaining('hazijatumwa tangu'), findsNothing);
    });

    testWidgets('old records under office review do not count', (tester) async {
      final app = await pumpApp(tester, now: noon);
      await queue(app, 'a', noon.subtract(const Duration(days: 6)),
          status: 'conflict');
      await tester.pumpAndSettle();
      expect(find.textContaining('hazijatumwa tangu'), findsNothing);
    });
  });

  testWidgets('Msaada lists the numbered steps', (tester) async {
    final app = await pumpApp(tester, now: noon);
    app.router.go(MNRoutes.profile);
    await tester.pumpAndSettle();
    await tester.tap(find.text(sw.help));
    await tester.pumpAndSettle();
    for (final step in sw.helpSteps) {
      expect(find.text(step), findsOneWidget);
    }
    expect(sw.helpSteps.length, greaterThanOrEqualTo(5));
    expect(sw.helpSteps.first, startsWith('1. '));
    expect(sw.helpSteps.join(' '), contains(sw.allSent));
  });
}
