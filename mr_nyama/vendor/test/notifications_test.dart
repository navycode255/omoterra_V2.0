import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/api/notifications.dart';
import 'package:mr_nyama_vendor/core/api/office_repository.dart';
import 'package:mr_nyama_vendor/core/auth/office_session.dart';
import 'package:mr_nyama_vendor/core/l10n/strings.dart';
import 'package:mr_nyama_vendor/core/routing/routes.dart';
import 'package:mr_nyama_vendor/features/notifications/notification_bell.dart';
import 'package:mr_nyama_vendor/features/notifications/notifications_screen.dart';
import 'package:mr_nyama_vendor/features/notifications/notifications_state.dart';
import 'package:mr_nyama_vendor/shared/widgets/app_header.dart';
import 'package:mr_nyama_vendor/shared/widgets/buttons.dart';

import 'helpers.dart';
import 'office_test.dart' show FakeOfficeRepository;

const sw = Strings('sw');

AppNotification note(String id,
        {String kind = 'delivery_waiting',
        String target = 'receive',
        bool read = false,
        String title = 'Mzigo unakuja',
        String body = 'Mzigo M-1 umetumwa kituo Kariakoo. Pokea ukifika.'}) =>
    AppNotification(
        id: id,
        kind: kind,
        title: title,
        body: body,
        target: target,
        createdAt: DateTime.now(),
        read: read);

/// The office fake with notifications and office messages (MN025).
class NotifyingOffice extends FakeOfficeRepository
    implements OfficeNotificationsRepository {
  final list = <AppNotification>[];
  final sent =
      <({String clientId, String body, String? station, String? vendor})>[];
  @override
  Future<NotificationPage> notifications(
          {required String lang, String? before}) async =>
      NotificationPage(
          items: List.of(list), unread: list.where((n) => !n.read).length);
  @override
  Future<int> markNotificationsRead(List<String>? ids) async {
    for (var i = 0; i < list.length; i++) {
      if (ids == null || ids.contains(list[i].id)) {
        list[i] = list[i].markedRead();
      }
    }
    return 1;
  }

  @override
  Future<OfficeMessage> sendMessage(
      {required String clientId,
      required String body,
      String? stationId,
      String? vendorId}) async {
    sent.add(
        (clientId: clientId, body: body, station: stationId, vendor: vendorId));
    return OfficeMessage(
        id: clientId,
        body: body,
        station: 'Kariakoo',
        vendor: '',
        sentBy: owner.name,
        recipients: 2,
        createdAt: DateTime.now());
  }

  @override
  Future<List<OfficeMessage>> sentMessages() async => const [];
}

Future<void> tapLabel(WidgetTester tester, String label) async {
  final target = find.bySemanticsLabel(label);
  await tester.ensureVisible(target.first);
  await tester.tap(target.first);
  await tester.pumpAndSettle();
}

void main() {
  group('vendor', () {
    testWidgets('the bell shows a dot for unread and opens the list',
        (tester) async {
      final app = await pumpApp(tester);
      expect(find.bySemanticsLabel(sw.notificationsTitle), findsOneWidget);
      app.api.notificationList.add(note('n1'));
      app.container.invalidate(notificationsProvider);
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel(sw.notificationsNew), findsOneWidget);
      await tapLabel(tester, sw.notificationsNew);
      expect(app.router.state.uri.path, MNRoutes.notifications);
      expect(find.text('Mzigo unakuja'), findsOneWidget);
      expect(app.api.notificationLangs.last, 'sw');
    });

    testWidgets('opening one marks it read and goes to its screen',
        (tester) async {
      final app = await pumpApp(tester, initial: MNRoutes.notifications);
      app.api.notificationList.add(note('n1'));
      app.container.invalidate(notificationsProvider);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mzigo unakuja'));
      await tester.pumpAndSettle();
      expect(app.router.state.uri.path, MNRoutes.receive);
      expect(app.api.notificationList.single.read, isTrue);
    });

    testWidgets('Soma zote marks everything read', (tester) async {
      final app = await pumpApp(tester, initial: MNRoutes.notifications);
      app.api.notificationList
        ..add(note('n1'))
        ..add(note('n2',
            kind: 'office_message',
            target: 'messages',
            title: 'Ujumbe wa ofisi',
            body: 'Mkutano saa nne.'));
      app.container.invalidate(notificationsProvider);
      await tester.pumpAndSettle();
      await tester.tap(find.text(sw.notificationsMarkAll));
      await tester.pumpAndSettle();
      expect(app.api.notificationList.every((n) => n.read), isTrue);
      expect(find.text(sw.notificationsMarkAll), findsNothing);
      // A message has no other screen: tapping it stays on the list.
      await tester.tap(find.text('Mkutano saa nne.'));
      await tester.pumpAndSettle();
      expect(app.router.state.uri.path, MNRoutes.notifications);
    });

    testWidgets('nothing yet says so', (tester) async {
      await pumpApp(tester, initial: MNRoutes.notifications);
      expect(find.text(sw.notificationsEmpty), findsOneWidget);
    });

    testWidgets('the vendor list uses the office title and back-row layout',
        (tester) async {
      await pumpApp(tester, initial: MNRoutes.notifications);
      expect(find.text(sw.notificationsTitle), findsOneWidget);
      expect(find.byType(MNIconButton), findsOneWidget);
      expect(find.byType(MNAppHeader), findsNothing);
      expect(find.text(sw.notificationsEmpty), findsOneWidget);
    });
  });

  group('office', () {
    Future<(TestApp, NotifyingOffice)> owner(WidgetTester tester) async {
      final office = NotifyingOffice()..signedIn = true;
      final app =
          await pumpApp(tester, startAs: StartAs.signedOut, office: office);
      await app.container
          .read(officeSessionProvider.notifier)
          .signedIn(office.owner);
      await tester.pumpAndSettle();
      return (app, office);
    }

    testWidgets('the owner bell opens the office list', (tester) async {
      final (app, office) = await owner(tester);
      office.list.add(note('o1',
          kind: 'problem',
          target: 'office_problems',
          title: 'Tofauti ya stoo',
          body: 'Kariakoo · Asha'));
      app.container.invalidate(notificationsProvider);
      await tester.pumpAndSettle();
      expect(app.container.read(notificationsUnreadProvider), isTrue);
      await tester.tap(find.byType(NotificationBell));
      await tester.pumpAndSettle();
      expect(app.router.state.uri.path, MNRoutes.officeNotifications);
      expect(find.text('Tofauti ya stoo'), findsOneWidget);
    });

    for (final role in ['supervisor', 'finance']) {
      testWidgets('a $role reaches the list and can send a message',
          (tester) async {
        final office = NotifyingOffice()..signedIn = true;
        final staff = StaffProfile(
            id: 's1',
            name: 'Neema Said',
            phone: '+255746484666',
            roles: [role]);
        office.owner = staff;
        final app =
            await pumpApp(tester, startAs: StartAs.signedOut, office: office);
        await app.container
            .read(officeSessionProvider.notifier)
            .signedIn(staff);
        await tester.pumpAndSettle();
        await tester.tap(find.byType(NotificationBell));
        await tester.pumpAndSettle();
        expect(app.router.state.uri.path, MNRoutes.officeNotifications);
        expect(find.text(sw.notificationsEmpty), findsOneWidget);
        expect(canSendMessages(staff.roles), isTrue);
      });
    }

    testWidgets('Tuma ujumbe to a whole kituo', (tester) async {
      final (app, office) = await owner(tester);
      app.router.push(MNRoutes.officeNewMessage);
      await tester.pumpAndSettle();
      expect(find.text(sw.messageSend), findsOneWidget);
      await tester.tap(find.text(sw.selectPlaceholder));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kariakoo').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Mkutano kesho saa tatu.');
      await tester.pump();
      await tester.tap(find.text(sw.messageSend));
      await tester.pumpAndSettle();
      expect(office.sent.single.body, 'Mkutano kesho saa tatu.');
      expect(office.sent.single.station, 's1');
      expect(find.text(sw.messageSent(2)), findsOneWidget);
    });
  });
}
