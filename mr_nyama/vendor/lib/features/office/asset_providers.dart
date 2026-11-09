import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/office_assets.dart';
import '../../core/api/office_repository.dart';
import '../../core/api/providers.dart';
import '../../core/auth/office_session.dart';

/// Runs an asset call with the office (or lead office) session. A repository
/// without assets refuses instead of pretending.
Future<T> officeAssetCall<T>(OfficeSessionController session,
        Future<T> Function(OfficeAssetsRepository repository) call) =>
    session.guard((repository) {
      if (repository is! OfficeAssetsRepository) {
        return Future.error(const OfficeError(OfficeErrorKind.invalid));
      }
      return call(repository as OfficeAssetsRepository);
    });

/// Reads show nothing when the repository has no asset support.
Future<List<T>> _list<T>(
    Ref ref, Future<List<T>> Function(OfficeAssetsRepository repository) call) {
  if (ref.read(officeRepositoryProvider) is! OfficeAssetsRepository) {
    return Future.value(<T>[]);
  }
  return officeAssetCall(ref.read(officeSessionProvider.notifier), call);
}

final officeAssetLocationsProvider =
    FutureProvider.autoDispose<List<AssetLocation>>(
        (ref) => _list(ref, (r) => r.assetLocations()));

final officeAssetCategoriesProvider =
    FutureProvider.autoDispose<List<AssetCategory>>(
        (ref) => _list(ref, (r) => r.assetCategories()));

final officeAssetsProvider = FutureProvider.autoDispose
    .family<List<Asset>, AssetFilter>((ref, filter) => _list(
        ref,
        (r) => r.assets(
            locationId: filter.locationId,
            categoryId: filter.categoryId,
            query: filter.query)));

final officeAssetProvider =
    FutureProvider.autoDispose.family<Asset, String>((ref, id) {
  if (ref.read(officeRepositoryProvider) is! OfficeAssetsRepository) {
    return Future.error(const OfficeError(OfficeErrorKind.invalid));
  }
  return officeAssetCall(
      ref.read(officeSessionProvider.notifier), (r) => r.assetById(id));
});
