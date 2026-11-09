import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../dev/preview_repository.dart';
import '../auth/secure_store.dart';
import 'http_vendor_repository.dart';
import 'office_repository.dart';
import 'vendor_repository.dart';

/// The Mr. Nyama API, chosen at build time:
/// `--dart-define=MN_API_URL=https://mrnyama.jopex.co.tz`. There is no
/// default and no fallback to any other server.
const apiUrl = String.fromEnvironment('MN_API_URL');

/// Release builds talk to the API only over HTTPS. Debug and profile builds
/// may use plain HTTP for a development server on the local network.
bool apiUrlAllowed(String url, {bool release = kReleaseMode}) {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.host.isEmpty) return false;
  return uri.scheme == 'https' || (!release && uri.scheme == 'http');
}

/// The vendor API. Without an allowed [apiUrl], every call fails closed
/// ([UnavailableVendorRepository]). The development preview
/// (`--dart-define=MN_PREVIEW=true`, never in release builds) swaps in
/// sample data from `lib/dev/`.
final vendorRepositoryProvider = Provider<VendorRepository>((ref) {
  if (devPreviewEnabled) return PreviewVendorRepository();
  if (apiUrlAllowed(apiUrl)) {
    return HttpVendorRepository(
        baseUrl: apiUrl, store: ref.read(keyValueStoreProvider));
  }
  return const UnavailableVendorRepository();
});

/// The office (staff) API, on the same server and build-time URL. The
/// development preview has no office: it fails closed there.
final officeRepositoryProvider = Provider<OfficeRepository>((ref) {
  if (!devPreviewEnabled && apiUrlAllowed(apiUrl)) {
    return HttpOfficeRepository(
        baseUrl: apiUrl, store: ref.read(keyValueStoreProvider));
  }
  return const UnavailableOfficeRepository();
});

final keyValueStoreProvider =
    Provider<KeyValueStore>((ref) => const SecureKeyValueStore());
