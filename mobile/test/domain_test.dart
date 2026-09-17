import 'package:flutter_test/flutter_test.dart';
import 'package:omoterra/core/routing/router.dart';
import 'package:omoterra/core/api/repository.dart';
import 'package:omoterra/shared/models/domain.dart';

void main() {
  test('role routing denies supplier-only buyers and buyer-only suppliers', () {
    expect(
        routeGuard('/stock/new', signedIn: true, setup: true, roles: ['buyer']),
        '/buyer');
    expect(
        routeGuard('/checkout/id',
            signedIn: true, setup: true, roles: ['supplier']),
        '/supplier');
    expect(
        routeGuard('/stock/new',
            signedIn: true, setup: true, roles: ['buyer', 'supplier']),
        isNull);
    expect(routeGuard('/orders', signedIn: false, setup: false, roles: []),
        '/welcome');
    expect(routeGuard('/orders', signedIn: true, setup: false, roles: []),
        '/setup');
  });
  test('decimal API contracts retain exact money strings', () {
    final listing = SupplyListing.fromJson({
      'id': '1',
      'category': 'beef',
      'unit_type': 'kg',
      'region': 'Dar',
      'buyer_price_per_unit': '12000.50',
      'quantity_available': '3.125'
    });
    expect(listing.price, '12000.50');
    expect(listing.available, '3.125');
  });
  test('local repository never fakes a successful transaction', () async {
    await expectLater(
        LocalRepository().write('/orders', {}), throwsA(isA<ApiFailure>()));
    await expectLater(LocalRepository().write('/reservations', {}),
        throwsA(isA<ApiFailure>()));
  });
}
