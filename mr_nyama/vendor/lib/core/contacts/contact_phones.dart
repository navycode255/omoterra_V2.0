import 'package:flutter_contacts/flutter_contacts.dart' as device;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_flow.dart' show normaliseTanzanianPhone;

/// One phone number from the phone's contacts, already in `+255…` form.
class ContactPhone {
  final String name;
  final String phone;
  const ContactPhone({required this.name, required this.phone});
}

/// Whether the phone let the app read its contacts.
enum ContactAccess { granted, denied }

/// Reads the phone's contacts. Read only: the app never writes contacts.
abstract class ContactPhoneSource {
  Future<ContactAccess> requestAccess();

  /// Every Tanzanian mobile number in the contacts, one entry per number,
  /// sorted by name. Numbers that are not Tanzanian mobiles are left out.
  Future<List<ContactPhone>> phones();
}

class DeviceContactPhoneSource implements ContactPhoneSource {
  const DeviceContactPhoneSource();

  @override
  Future<ContactAccess> requestAccess() async {
    final status =
        await device.FlutterContacts.permissions.request(device.PermissionType.read);
    return status == device.PermissionStatus.granted ||
            status == device.PermissionStatus.limited
        ? ContactAccess.granted
        : ContactAccess.denied;
  }

  @override
  Future<List<ContactPhone>> phones() async {
    final contacts = await device.FlutterContacts.getAll(
        properties: {device.ContactProperty.name, device.ContactProperty.phone});
    return contactPhonesFrom([
      for (final c in contacts)
        (name: c.displayName ?? '', numbers: [for (final p in c.phones) p.number]),
    ]);
  }
}

/// Turns raw contacts into Tanzanian mobile numbers: one entry per number,
/// duplicates within a contact dropped, sorted by name.
List<ContactPhone> contactPhonesFrom(
    Iterable<({String name, List<String> numbers})> contacts) {
  final out = <ContactPhone>[];
  for (final c in contacts) {
    final seen = <String>{};
    for (final raw in c.numbers) {
      final phone = normaliseTanzanianPhone(raw);
      if (phone == null || !seen.add(phone)) continue;
      final name = c.name.trim();
      out.add(ContactPhone(name: name.isEmpty ? phone : name, phone: phone));
    }
  }
  out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return out;
}

final contactPhoneSourceProvider =
    Provider<ContactPhoneSource>((ref) => const DeviceContactPhoneSource());
