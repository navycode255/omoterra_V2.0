import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/api/office_repository.dart';
import 'package:mr_nyama_vendor/core/auth/office_session.dart';
import 'package:mr_nyama_vendor/core/routing/routes.dart';
import 'helpers.dart';
import 'station_management_test.dart' show StationOffice, revealStation;

/// The server allows `receiving.manage` to the supervisor and the owner only,
/// for listing, adding, changing and cancelling deliveries. The screens match.
class _Office extends StationOffice {
  final bool serverAllows;
  _Office(this.serverAllows);
  @override
  Future<List<Map<String, dynamic>>> stationManifests(String id) async {
    if (!serverAllows) throw const OfficeError(OfficeErrorKind.forbidden);
    return super.stationManifests(id);
  }
}

Future<void> openStation(WidgetTester tester, String role) async {
  final repo = _Office(const {'supervisor', 'business_owner'}.contains(role));
  final app = await pumpApp(tester, startAs: StartAs.signedOut, office: repo);
  await app.container
      .read(officeSessionProvider.notifier)
      .signedIn(StaffProfile(id: 'me', name: 'Mimi', phone: '', roles: [role]));
  await tester.pumpAndSettle();
  app.router.push(MNRoutes.officeStock('s1'));
  await tester.pumpAndSettle();
}

void main() {
  for (final role in ['supervisor', 'business_owner']) {
    testWidgets('$role can add, change and cancel a delivery', (tester) async {
      await openStation(tester, role);
      await revealStation(tester, 'Badili orodha');
      expect(find.text('Badili orodha'), findsOneWidget);
      expect(find.text('Ghairi utumaji'), findsOneWidget);
      expect(find.text('Ongeza mzigo unaotarajiwa'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  for (final role in ['operations_admin', 'finance']) {
    testWidgets('$role sees no delivery controls and no refused list',
        (tester) async {
      await openStation(tester, role);
      expect(find.text('Mizigo inayotarajiwa'), findsNothing);
      expect(find.text('Zinazosubiri kupokelewa'), findsNothing);
      expect(find.text('Badili orodha'), findsNothing);
      expect(find.text('Ghairi utumaji'), findsNothing);
      expect(find.text('Wateja wa mkopo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
