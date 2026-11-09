// Deleting a product, category, station or credit customer added by mistake
// (owner decision 28 October 2026). The server refuses anything with records
// and says what to do instead; staff and vendors go through
// `changeVendorStatus` / `changeStaffStatus` with StatusChange.delete.

abstract interface class OfficeRemovalRepository {
  Future<void> deleteProduct(String code, {required String reason});
  Future<void> deleteCategory(String code, {required String reason});
  Future<void> deleteStation(String stationId, {required String reason});
  Future<void> deleteCreditCustomer(String customerId,
      {required String reason});
}
