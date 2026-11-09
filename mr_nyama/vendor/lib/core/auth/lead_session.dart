import '../api/office_repository.dart' show StaffProfile;

/// The office session an Outlet Lead gets from the seller session
/// (`POST /vendor/auth/lead-session`): staff-audience tokens and the staff
/// profile. It never has a fingerprint key.
class LeadSession {
  /// The token answer (`access_token`, `refresh_token`, ...). Kept only by
  /// the office client's secure store.
  final Map<String, dynamic> tokens;
  final StaffProfile profile;
  const LeadSession({required this.tokens, required this.profile});
}

/// Asks the server for the lead session, with the seller session.
abstract interface class VendorLeadRepository {
  Future<LeadSession> leadSession(String token);
}

/// Keeps the tokens of a lead session in the office client.
abstract interface class OfficeLeadRepository {
  Future<void> keepLeadTokens(Map<String, dynamic> tokens);
}
