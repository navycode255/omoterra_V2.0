part of 'strings.dart';

/// The sign-in page of the owner-approved reference (30 October 2026). Same
/// rules as `Strings`: Swahili first, `_t(sw, en)`.
extension SignInStrings on Strings {
  String get signInWelcome => _t('Karibu Mr. Nyama', 'Welcome to Mr. Nyama');
  String get signInPhonePrompt =>
      _t('Ingiza namba yako ya simu', 'Enter your phone number');
  String get phoneNineDigits =>
      _t('Ingiza tarakimu 9 baada ya +255.', 'Enter 9 digits after +255.');
  String get rememberNumber => _t('Kumbuka namba hii', 'Remember this number');
  String get clearPhone => _t('Futa namba', 'Clear number');
  String get moreOptions => _t('Chaguo zaidi', 'More options');
  String get chooseLanguage => _t('Chagua lugha', 'Choose language');
  String get languageDone => _t('Imekamilika', 'Done');
}
