// End-to-end check of the app's HTTP client against a running Mr. Nyama API.
// Opt-in: skipped unless started with the server and a fresh vendor code:
//
//   flutter test test/live_api_test.dart \
//     --dart-define=MN_LIVE_API=http://127.0.0.1:8765 \
//     --dart-define=MN_LIVE_PHONE=+2557XXXXXXXX --dart-define=MN_LIVE_CODE=123456
//
// The vendor must be assigned to a station with one open delivery whose first
// line is a priced product. Uses the app's own payload builders, so what is
// sent is exactly what the outbox sends. Never point this at production.
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/api/http_vendor_repository.dart';
import 'package:mr_nyama_vendor/core/api/vendor_repository.dart';
import 'package:mr_nyama_vendor/core/business_day.dart';
import 'package:mr_nyama_vendor/core/sync/payloads.dart';
import 'package:uuid/uuid.dart';

import 'fakes.dart';

const api = String.fromEnvironment('MN_LIVE_API');
const phone = String.fromEnvironment('MN_LIVE_PHONE');
const code = String.fromEnvironment('MN_LIVE_CODE');

void main() {
  test('activate, receive, sell and sync against the live API', () async {
    final repo = HttpVendorRepository(baseUrl: api, store: InMemoryStore());
    const uuid = Uuid();

    expect(await repo.startSignIn(phone), SignInStep.pin);
    final setup = await repo.verifyCode(phone: phone, code: code);
    final session = await repo.setPin(setupToken: setup, pin: '2580');
    final profile = session.profile;
    expect(profile.stationKey, isNotEmpty);

    final [delivery, ...] = await repo.deliveries('t');
    final line = delivery.lines.first;
    SyncOperation op(String type, String id, Map<String, dynamic> payload) {
      final now = DateTime.now();
      return SyncOperation(
          opId: id,
          opType: type,
          vendorId: profile.id,
          stationKey: profile.stationKey,
          businessDate: businessDateKey(now),
          createdAt: now,
          payload: payload);
    }

    final receipt = op(
        'receipt',
        uuid.v4(),
        receiptPayload(
            eventId: uuid.v4(),
            receiptId: uuid.v4(),
            consignmentId: delivery.consignmentId,
            consignmentVersion: delivery.version,
            receivedAt: DateTime.now(),
            lines: [
              for (final l in delivery.lines)
                (
                  lineId: l.lineId,
                  accepted: l.quantity,
                  rejected: 0,
                  reason: null
                )
            ]));
    var reply =
        await repo.sync('t', phoneTime: DateTime.now(), operations: [receipt]);
    expect(reply.results.single.outcome, OperationOutcome.accepted,
        reason: reply.results.single.reason);

    var catalogue = await repo.catalog('t');
    final product =
        catalogue.products.firstWhere((p) => p.id == line.productId);
    expect(product.available, line.quantity);
    expect(product.price, isNotNull);

    final saleId = uuid.v4();
    final sale = op(
        'sale',
        saleId,
        salePayload(
            clientId: saleId,
            recordedAt: DateTime.now(),
            paymentMethod: 'cash',
            lines: [
              (
                productId: product.id,
                quantity: 2,
                unitPrice: product.price!,
                priceVersion: product.priceVersion,
                exceeds: false
              )
            ]));
    reply = await repo.sync('t', phoneTime: DateTime.now(), operations: [sale]);
    expect(reply.results.single.outcome, OperationOutcome.accepted,
        reason: reply.results.single.reason);
    reply = await repo.sync('t', phoneTime: DateTime.now(), operations: [sale]);
    expect(reply.results.single.outcome, OperationOutcome.duplicate);
    expect(reply.serverTime, isNotNull);

    catalogue = await repo.catalog('t');
    expect(catalogue.products.firstWhere((p) => p.id == product.id).available,
        line.quantity - 2);
    final dashboard = await repo.dashboard('t');
    expect(dashboard.saleCount, 1);
    expect(dashboard.todayTotal, 2 * product.price!);

    await repo.signOut('t');
    final again = await repo.signIn(phone: phone, pin: '2580');
    expect(again.profile.id, profile.id);
  }, skip: api.isEmpty ? 'set --dart-define=MN_LIVE_API to run' : false);
}
