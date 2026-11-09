part of 'strings.dart';

/// The lock and PIN pad of the owner-approved reference (30 October 2026).
/// Same rules as `Strings`: Swahili first, `_t(sw, en)`.
extension PinStrings on Strings {
  String get pinTitle => _t('Weka PIN', 'Enter PIN');
  String get pinSubtitle =>
      _t('Ingiza PIN ya akaunti.', 'Enter your account PIN.');
  String get pinWrong => _t('PIN si sahihi.', 'Wrong PIN.');
  String pinTriesLeft(int left) => left == 1
      ? _t('Jaribio 1 limebaki.', '1 try left.')
      : _t('Majaribio $left yamebaki.', '$left tries left.');
  String get pinWait => _t('Subiri kidogo', 'Please wait');
  String get pinRetryAfter => _t('Jaribu tena baada ya', 'Try again in');
  String get biometricPaused =>
      _t('Biometrics zimezimwa kwa muda.', 'Biometrics are off for now.');
  String get lockTryAgain => _t('Jaribu tena', 'Try again');

  /// Badilisha PIN, three steps.
  String get changePinCurrent => _t('PIN ya sasa', 'Current PIN');
  String get changePinNew => _t('PIN mpya', 'New PIN');
  String get changePinConfirm => _t('Thibitisha PIN mpya', 'Confirm new PIN');
  String changePinStep(int n) => _t('Hatua ya $n kati ya 3', 'Step $n of 3');
  String get changePinWrong =>
      _t('PIN si sahihi. Jaribu tena.', 'Wrong PIN. Try again.');
  String get changePinMismatch =>
      _t('PIN hazifanani. Jaribu tena.', "PINs don't match. Try again.");
  String get changePinLocked =>
      _t('Jaribio limezuiwa kwa muda', 'Attempts are paused for now');
  String get changePinPaused => _t('PIN na biometrics vimesitishwa kwa muda.',
      'PIN and biometrics are paused for now.');

  /// The phone's own fingerprint dialog.
  String get biometricPromptTitle =>
      _t('Tumia alama ya kidole', 'Use your fingerprint');
  String get biometricPromptCancel => _t('Ghairi', 'Cancel');
}
