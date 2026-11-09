part of 'strings.dart';

/// Offline unlock (Phase 11): offline PIN, grant validity, re-lock, attempts.
/// Same rules as `Strings`: Swahili first, both languages, `_t(sw, en)`.
extension OfflineStrings on Strings {
  String offlineWrongPin(int left) => _t(
      'PIN si sahihi. Majaribio $left yamebaki bila intaneti.',
      'Wrong PIN. $left attempts left offline.');
  String get offlineErased => _t(
      'Majaribio yamekwisha. Unganisha intaneti uingie tena.',
      'Too many attempts. Connect to the internet to sign in again.');
  String get offlineExpired => _t(
      'Muda wa kufungua bila intaneti umekwisha. Unganisha intaneti uingie.',
      'Offline access has ended. Connect to the internet to sign in.');
  String get offlineRecordingStopped => _t(
      'Muda wa kufanya kazi bila intaneti umekwisha. Unganisha intaneti ili kuendelea kurekodi.',
      'Offline time is over. Connect to the internet to keep recording.');
  String get offlineSettingsTitle =>
      _t('Kufungua bila intaneti', 'Unlocking offline');
  String get offlineSettingsHelp => _t(
      'Muuzaji aliyeingia mtandaoni anaweza kufungua kwa PIN bila intaneti kwa muda huu. Usipoweka yote matatu, kufungua bila intaneti kumezimwa.',
      'A vendor who signed in online may unlock with their PIN offline for this long. Until all three are set, offline unlock is off.');
  String offlineLimitName(String key) => switch (key) {
        'offline.validity_hours' =>
          _t('Saa bila intaneti (1–720)', 'Hours offline (1–720)'),
        'offline.relock_minutes' => _t('Funga tena baada ya dakika (1–1440)',
            'Lock again after minutes (1–1440)'),
        'offline.pin_attempts' =>
          _t('Majaribio ya PIN (1–20)', 'PIN attempts (1–20)'),
        _ => key,
      };
  String get offlineNotSet => _t('Haijawekwa', 'Not set');
  String get offlineOn => _t('Imewashwa', 'On');
  String get offlineOff => _t('Imezimwa', 'Off');
  String offlineLimitInvalid(String name) => _t(
      '$name: weka namba ndani ya kipimo.', '$name: enter a number in range.');
  String offlineSaveReason(String values) =>
      _t('Viwango vya bila intaneti: $values', 'Offline limits: $values');
  String get lockPinOrFingerprint => _t(
      'Ingiza PIN yako au tumia alama ya kidole kufungua.',
      'Enter your PIN or use your fingerprint to unlock.');
  String get offlineUnlockedNote => _t(
      'Umefungua bila intaneti. Rekodi zitatumwa ukipata intaneti.',
      'Unlocked offline. Records are sent once you are online.');
}
