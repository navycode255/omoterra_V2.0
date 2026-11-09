/// Registers this phone's push token for the person signed in (MN026, step
/// 13B). The server ends it when the phone's session ends.
abstract interface class VendorPushRepository {
  Future<void> registerPushToken(String token, {required String lang});
}

abstract interface class OfficePushRepository {
  Future<void> registerPushToken(String token, {required String lang});
}
