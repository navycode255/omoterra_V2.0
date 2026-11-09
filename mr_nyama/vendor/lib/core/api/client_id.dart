import 'dart:math';

/// A random version-4 id, so a retried request is stored once.
String newClientId() {
  final r = Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
      '${h.substring(16, 20)}-${h.substring(20)}';
}

/// The id of one office money request: kept while the same details are sent
/// again after a lost answer, new once any detail changes.
class RetryId {
  String? _details, _id;
  String forDetails(String details) {
    if (details != _details || _id == null) {
      _details = details;
      _id = newClientId();
    }
    return _id!;
  }
}
