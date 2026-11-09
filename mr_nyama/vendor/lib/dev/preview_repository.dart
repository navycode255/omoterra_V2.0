// Development tool: sample data only. Never reachable in release builds.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/api/vendor_repository.dart';
import '../core/theme/tokens.dart';

/// The sign-in and dashboard preview exists only in debug/profile builds
/// started with `--dart-define=MN_PREVIEW=true`. It is a compile-time false
/// in release, so [PreviewVendorRepository] is never used there.
const devPreviewEnabled = !kReleaseMode && bool.fromEnvironment('MN_PREVIEW');

/// Phones the preview knows (enter the 9 digits after +255):
/// - 712 345 678: Maternus (sample), PIN 2580
/// - 700 000 001: first activation, code 123456
/// - 700 000 002: suspended account
/// Any other valid number is "not registered". Activation and reset code:
/// 123456. Nothing here is real or reaches a server.
class PreviewVendorRepository implements VendorRepository {
  static const _delay = Duration(milliseconds: 700);
  static const _code = '123456';
  static const _profile = VendorProfile(
      id: 'sample-vendor',
      name: 'Maternus (sampuli)',
      phone: '+255712345678',
      station: 'Kituo cha sampuli',
      stationKey: 'sample-station');

  String _pin = '2580';
  int _attempts = 3;

  Future<void> _wait() => Future.delayed(_delay);

  @override
  Future<SignInStep> startSignIn(String phone) async {
    await _wait();
    return switch (phone) {
      '+255712345678' => SignInStep.pin,
      '+255700000001' => SignInStep.activation,
      '+255700000002' => throw const AuthFailure(AuthFailureKind.suspended),
      _ => throw const AuthFailure(AuthFailureKind.unknownPhone),
    };
  }

  @override
  Future<VendorSession> signIn(
      {required String phone, required String pin}) async {
    await _wait();
    if (pin != _pin) {
      _attempts--;
      if (_attempts <= 0) {
        _attempts = 3;
        throw AuthFailure(AuthFailureKind.locked,
            retryAfter: DateTime.now().add(const Duration(minutes: 15)));
      }
      throw AuthFailure(AuthFailureKind.wrongPin, attemptsLeft: _attempts);
    }
    _attempts = 3;
    return const VendorSession('sample-token', _profile);
  }

  @override
  Future<String> verifyCode(
      {required String phone, required String code, bool reset = false}) async {
    await _wait();
    if (code != _code) throw const AuthFailure(AuthFailureKind.invalidCode);
    return 'sample-setup-token';
  }

  @override
  Future<VendorSession> setPin(
      {required String setupToken, required String pin}) async {
    await _wait();
    _pin = pin;
    return const VendorSession('sample-token', _profile);
  }

  @override
  Future<void> changePin(
      {required String token,
      required String currentPin,
      required String newPin}) async {
    await _wait();
    if (currentPin != _pin) {
      throw const AuthFailure(AuthFailureKind.wrongPin);
    }
    _pin = newPin;
  }

  @override
  Future<DashboardSummary> dashboard(String token) async {
    await _wait();
    final now = DateTime.now();
    DateTime at(int h, int m) => DateTime(now.year, now.month, now.day, h, m);
    return DashboardSummary(
      date: now,
      todayTotal: 245000,
      saleCount: 24,
      recent: [
        SaleSummary(
            id: 's1',
            recordedAt: at(11, 25),
            product: 'Paja (Robo)',
            quantity: 2,
            payment: PaymentMethod.cash,
            amount: 4000),
        SaleSummary(
            id: 's2',
            recordedAt: at(10, 42),
            product: 'Nusu kuku',
            quantity: 1,
            payment: PaymentMethod.mpesa,
            amount: 4500),
        SaleSummary(
            id: 's3',
            recordedAt: at(9, 58),
            product: 'Kuku mzima',
            quantity: 1,
            payment: PaymentMethod.cash,
            amount: 9000),
      ],
    );
  }

  /// Sample server configuration. The seven priced products use the owner's
  /// confirmed reference prices; the others have no price yet, so they show
  /// as not for sale. Photos only where an approved asset exists.
  @override
  Future<CatalogSnapshot> catalog(String token) async {
    await _wait();
    return const CatalogSnapshot(
      // Clearly not a real number: the real one comes from the server.
      mpesaRecipient: '000 000 (sampuli)',
      products: [
        CatalogItem(
            id: 'kuku-mzima',
            name: 'Kuku mzima',
            price: 9000,
            priceVersion: 'sample-1',
            category: 'kuku',
            available: 8),
        CatalogItem(
            id: 'nusu-kuku',
            name: 'Nusu kuku',
            price: 4500,
            priceVersion: 'sample-1',
            category: 'kuku',
            available: 15),
        CatalogItem(
            id: 'paja-robo',
            name: 'Paja (Robo)',
            price: 2000,
            priceVersion: 'sample-1',
            category: 'kuku',
            available: 30),
        CatalogItem(
            id: 'kidali-robo',
            name: 'Kidali (Robo)',
            price: 2500,
            priceVersion: 'sample-1',
            category: 'kuku',
            imageKey: 'kidali',
            available: 28),
        CatalogItem(
            id: 'firigisi-2',
            name: 'Firigisi (2)',
            price: 1000,
            priceVersion: 'sample-1',
            category: 'kuku',
            available: 50),
        CatalogItem(
            id: 'shingo-1',
            name: 'Shingo (1)',
            price: 500,
            priceVersion: 'sample-1',
            category: 'kuku',
            imageKey: 'shingo',
            available: 2),
        CatalogItem(
            id: 'vichwa-miguu',
            name: 'Vichwa na miguu',
            price: 500,
            priceVersion: 'sample-1',
            category: 'kuku',
            available: 35),
        CatalogItem(
            id: 'mishkaki',
            name: 'Kuku Mishkaki',
            price: null,
            category: 'vyakula'),
        CatalogItem(
            id: 'viazi', name: 'Viazi', price: null, category: 'vyakula'),
        CatalogItem(
            id: 'maini', name: 'Maini', price: null, category: 'vyakula'),
        CatalogItem(
            id: 'ndizi-kaanga',
            name: 'Ndizi Kaanga',
            price: null,
            category: 'vyakula'),
      ],
    );
  }

  /// Two sample deliveries: one for this station, one addressed to another
  /// station (which the phone must refuse to receive).
  @override
  Future<List<DeliveryManifest>> deliveries(String token) async {
    await _wait();
    final today = DateTime.now();
    return [
      DeliveryManifest(
        consignmentId: 'sample-consignment-1',
        version: 1,
        reference: 'OMT-2041',
        sender: 'Omoterra (sampuli)',
        stationKey: 'sample-station',
        stationName: 'Kituo cha sampuli',
        dispatchedAt: DateTime(today.year, today.month, today.day, 7, 30),
        lines: const [
          ManifestLine(
              lineId: 'L1',
              productId: 'kuku-mzima',
              productName: 'Kuku mzima',
              quantity: 20),
          ManifestLine(
              lineId: 'L2',
              productId: 'kidali-robo',
              productName: 'Kidali (Robo)',
              quantity: 30,
              imageKey: 'kidali'),
          ManifestLine(
              lineId: 'L3',
              productId: 'shingo-1',
              productName: 'Shingo (1)',
              quantity: 40,
              imageKey: 'shingo'),
        ],
      ),
      DeliveryManifest(
        consignmentId: 'sample-consignment-2',
        version: 1,
        reference: 'OMT-2042',
        sender: 'Omoterra (sampuli)',
        stationKey: 'other-station',
        stationName: 'Kituo kingine (sampuli)',
        dispatchedAt: DateTime(today.year, today.month, today.day, 8),
        lines: const [
          ManifestLine(
              lineId: 'L1',
              productId: 'paja-robo',
              productName: 'Paja (Robo)',
              quantity: 25),
        ],
      ),
    ];
  }

  /// The preview never pretends the office accepted anything: queued
  /// operations stay "waiting", exactly as they would without a server.
  @override
  Future<SyncReply> sync(String token,
          {required DateTime phoneTime,
          required List<SyncOperation> operations}) async =>
      throw const AuthFailure(AuthFailureKind.notConfigured);

  @override
  Future<void> signOut(String token) async {}
}

/// Marks every preview screen so sample data is never mistaken for real.
class PreviewBanner extends StatelessWidget {
  final Widget child;
  const PreviewBanner({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Banner(
        message: 'SAMPULI',
        location: BannerLocation.topEnd,
        color: MNColors.warning,
        child: child,
      );
}
