import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/api/office_repository.dart';
import 'package:mr_nyama_vendor/core/l10n/strings.dart';
import 'package:mr_nyama_vendor/core/routing/routes.dart';
import 'package:mr_nyama_vendor/features/office/owner_reference.dart'
    show OwnerMenuRow;
import 'package:mr_nyama_vendor/shared/widgets/buttons.dart';

import 'office_people_test.dart'
    show RecordingOffice, inSheet, openOffice, peopleOffice, tapVisible;

const sw = Strings('sw');

/// The people fake that can also delete products, categories, stations and
/// credit customers; `refuse` makes the next delete fail as the server would.
class RemovalOffice extends RecordingOffice implements OfficeRemovalRepository {
  final removed = <String>[];
  OfficeError? refuse;

  Future<void> _record(String what) async {
    if (refuse case final e?) {
      refuse = null;
      throw e;
    }
    removed.add(what);
  }

  @override
  Future<void> deleteProduct(String code, {required String reason}) =>
      _record('product $code reason=$reason');
  @override
  Future<void> deleteCategory(String code, {required String reason}) =>
      _record('category $code reason=$reason');
  @override
  Future<void> deleteStation(String stationId, {required String reason}) =>
      _record('station $stationId reason=$reason');
  @override
  Future<void> deleteCreditCustomer(String customerId,
          {required String reason}) =>
      _record('customer $customerId reason=$reason');
}

RemovalOffice removalOffice() {
  final o = RemovalOffice()..signedIn = true;
  final base = peopleOffice();
  o.vendorsList.addAll(base.vendorsList);
  o.staffList.addAll(base.staffList);
  o.productsList.add(const OfficeProduct(
      code: 'KOSA-1', name: 'Bidhaa ya kosa', category: 'kuku', unit: 'piece'));
  return o;
}

Future<void> confirmDelete(
    WidgetTester tester, String action, String reason) async {
  await tester.enterText(inSheet(find.byType(TextField)), reason);
  await tester.tap(inSheet(find.widgetWithText(MNButton, action)).last);
  await tester.pumpAndSettle();
  await tester.tap(find.text(sw.deleteYes));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'a staff member added by mistake is deleted after a reason and a confirmation',
      (tester) async {
    final office = removalOffice();
    final app = await openOffice(tester, office);
    app.router.push(MNRoutes.officeStaffMember('st1'));
    await tester.pumpAndSettle();
    await tapVisible(
        tester, find.widgetWithText(OwnerMenuRow, sw.deleteAccount));
    expect(find.textContaining('aliyeongezwa kwa makosa'), findsOneWidget);
    await confirmDelete(tester, sw.deleteAccount, 'Niliongeza kwa makosa');
    expect(office.log, ['staff delete st1 reason=Niliongeza kwa makosa']);
    expect(office.staffList.any((s) => s.id == 'st1'), isFalse);
    expect(find.text(sw.deletedToast), findsOneWidget);
  });

  testWidgets('someone with records is refused in the server\'s words',
      (tester) async {
    final office = removalOffice()
      ..refuseStatus = const OfficeError(OfficeErrorKind.refused,
          'This vendor has records (sales), so it cannot be deleted. Mark them as left instead.');
    final app = await openOffice(tester, office);
    app.router.push(MNRoutes.officeVendor('v1'));
    await tester.pumpAndSettle();
    await tapVisible(
        tester, find.widgetWithText(OwnerMenuRow, sw.deleteAccount));
    await confirmDelete(tester, sw.deleteAccount, 'Jaribio');
    expect(find.textContaining('Mark them as left instead'), findsOneWidget);
    expect(office.vendorsList.any((v) => v.id == 'v1'), isTrue);
  });

  testWidgets('a product added by mistake is deleted from its page',
      (tester) async {
    final office = removalOffice();
    final app = await openOffice(tester, office);
    app.router.push(MNRoutes.officeProduct('KOSA-1'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.bySemanticsLabel(sw.productActions));
    await tapVisible(
        tester, find.widgetWithText(MNTextButton, sw.deleteProduct));
    await confirmDelete(tester, sw.deleteProduct, 'Jina lilikosewa');
    expect(office.removed, ['product KOSA-1 reason=Jina lilikosewa']);
  });
}
