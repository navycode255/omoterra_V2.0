// Outlet Lead: the owner makes a seller the lead of his own station, or ends
// it. The server checks `staff.manage` and `roles.grant`.

/// 409 codes the lead routes answer with.
const leadRefusals = {
  'no_station',
  'already_lead',
  'staff_has_role',
  'station_has_supervisor',
  'vendor_not_active',
  'own_account',
  'staff_unavailable',
  'client_id_used',
};

abstract interface class OfficeOutletLeadRepository {
  /// A retry with the same [clientId] repeats the first answer.
  Future<void> makeOutletLead(String vendorId,
      {required String clientId, required String reason});

  Future<void> endOutletLead(String vendorId,
      {required String clientId, required String reason});
}
