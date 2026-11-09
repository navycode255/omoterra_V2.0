part of 'strings.dart';

/// Fingerprint sign-in after sign-out (MN024, owner decisions 29 and 30
/// October 2026). Same rules as `Strings`: Swahili first, `_t(sw, en)`.
extension FingerprintStrings on Strings {
  String get fingerprintSignIn =>
      _t('Ingia kwa alama ya kidole', 'Sign in with fingerprint');
  String welcomeBack(String name) =>
      _t('Karibu tena, $name', 'Welcome back, $name');
  String get notYou => _t('Si wewe?', 'Not you?');
  String get fingerprintTapHint =>
      _t('Gusa kuingia kwa alama ya kidole', 'Tap to use fingerprint');
  String get fingerprintSignInPending => _t(
      'Alama ya kidole inafungua programu. Kuingia kwa alama ya kidole baada ya kutoka bado hakupatikani kwenye seva; kutajaribiwa tena ukiingia kwa PIN.',
      'Your fingerprint unlocks the app. Signing in with it after signing out is not available from the server yet; the app tries again at your next PIN sign-in.');
  String get fingerprintKeyEnded => _t(
      'Kuingia kwa alama ya kidole kumesimamishwa (PIN imebadilishwa, akaunti imebadilika au ofisi imezima vipindi). Ingia kwa PIN na uchague "Kumbuka namba hii" ili kuiwasha tena.',
      'Fingerprint sign-in has ended (the PIN or the account changed, or the office ended sessions). Sign in with your PIN and choose "Remember this number" to turn it on again.');
}
