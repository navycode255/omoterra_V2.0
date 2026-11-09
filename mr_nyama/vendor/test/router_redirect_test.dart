import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/core/api/office_repository.dart';
import 'package:mr_nyama_vendor/core/api/vendor_repository.dart';
import 'package:mr_nyama_vendor/core/auth/office_session.dart';
import 'package:mr_nyama_vendor/core/auth/session.dart';
import 'package:mr_nyama_vendor/core/routing/router.dart';
import 'package:mr_nyama_vendor/core/routing/routes.dart';

import 'fakes.dart';

const _staff = StaffProfile(id: 's1', name: 'Neema', phone: '', roles: []);
const _lead = OfficeSignedIn(_staff, viaLead: true);
const _plain = OfficeSignedIn(_staff);
final _in =
    AsyncData<AuthState>(SignedIn(VendorSession('t', testProfile)));
const _locked = AsyncData<AuthState>(Locked(testProfile));
const _out = AsyncData<AuthState>(SignedOut());

void main() {
  group('lead office session', () {
    test('a signed-in seller with a lead session opens the lead pages', () {
      for (final path in [
        MNRoutes.officeMoneyStation('st1'),
        MNRoutes.officeStock('st1'),
        MNRoutes.officeVerificationProblems('st1'),
        MNRoutes.officeClosingCases('st1'),
        MNRoutes.officeClosingCase('c1', stationId: 'st1'),
      ]) {
        expect(sessionRedirect(_in, path, office: _lead), isNull, reason: path);
      }
    });

    test('lead may open /ofisi/mali but not /ofisi/mali/mpya', () {
      for (final path in [MNRoutes.officeAssets, MNRoutes.officeAsset('a1')]) {
        expect(sessionRedirect(_in, path, office: _lead), isNull, reason: path);
      }
      expect(sessionRedirect(_in, MNRoutes.officeAssetNew, office: _lead),
          MNRoutes.home);
    });

    test('a non-owner office session cannot open the register form', () {
      const ops = OfficeSignedIn(StaffProfile(
          id: 'o', name: 'Z', phone: '', roles: ['operations_admin']));
      const owner = OfficeSignedIn(StaffProfile(
          id: 'w', name: 'W', phone: '', roles: ['business_owner']));
      expect(sessionRedirect(_out, MNRoutes.officeAssetNew, office: ops),
          MNRoutes.officeAssets);
      expect(sessionRedirect(_out, MNRoutes.officeAssetNew, office: owner),
          isNull);
    });

    test('the lead pages stay a fixed list', () {
      expect(sessionRedirect(_in, MNRoutes.officeVendors, office: _lead),
          MNRoutes.home);
      expect(sessionRedirect(_in, MNRoutes.officeMoneySettings, office: _lead),
          MNRoutes.home);
      expect(sessionRedirect(_in, MNRoutes.office, office: _lead),
          MNRoutes.home);
      expect(sessionRedirect(_in, MNRoutes.officeSignIn, office: _lead),
          MNRoutes.home);
      expect(sessionRedirect(_in, MNRoutes.officePin, office: _lead),
          MNRoutes.home);
    });

    test('seller pages stay open with a lead session', () {
      expect(sessionRedirect(_in, MNRoutes.home, office: _lead), isNull);
      expect(sessionRedirect(_in, MNRoutes.expenses, office: _lead), isNull);
    });

    test('a locked phone asks for the PIN before any lead page', () {
      expect(
          sessionRedirect(_locked, MNRoutes.officeStock('st1'), office: _lead),
          MNRoutes.pin);
      expect(sessionRedirect(_locked, MNRoutes.home, office: _lead),
          MNRoutes.pin);
    });

    test('signed out goes to the seller login, never the office sign-in', () {
      expect(
          sessionRedirect(_out, MNRoutes.officeStock('st1'), office: _lead),
          MNRoutes.login);
      expect(sessionRedirect(_out, MNRoutes.officeSignIn, office: _lead),
          MNRoutes.login);
    });

    test('a plain office session still sees only the office', () {
      expect(sessionRedirect(_out, MNRoutes.home, office: _plain),
          MNRoutes.office);
      expect(sessionRedirect(_out, MNRoutes.officeVendors, office: _plain),
          isNull);
    });

    test('a plain seller cannot open office pages', () {
      expect(
          sessionRedirect(_in, MNRoutes.officeMoneyStation('st1'),
              office: const OfficeSignedOut()),
          MNRoutes.home);
      expect(
          sessionRedirect(_in, MNRoutes.officeStock('st1'),
              office: const OfficeSignedOut()),
          MNRoutes.home);
    });
  });
}
