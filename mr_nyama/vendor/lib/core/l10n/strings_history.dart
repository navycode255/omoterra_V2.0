part of 'strings.dart';

/// Sales history recovered from the server on a new phone (Phase 11).
/// Same rules as `Strings`: Swahili first, both languages, `_t(sw, en)`.
extension HistoryRecoveryStrings on Strings {
  String get recoverHistory => _t('Rejesha historia', 'Recover history');
  String get recoveringHistory => _t(
      'Inarejesha historia yako kutoka ofisini. Unaweza kuendelea kuuza.',
      'Getting your history back from the office. You can keep selling.');
  String get recoveryFailed => _t(
      'Historia haikurejeshwa sasa. Mauzo yako yako salama ofisini.',
      'History could not be recovered now. Your sales are safe at the office.');
  String recoveryDone(int sales) => sales == 0
      ? _t('Historia iko kamili: hakuna kipya kutoka ofisini.',
          'History is complete: nothing new from the office.')
      : _t('Mauzo $sales yamerejeshwa kutoka ofisini.',
          '$sales sales recovered from the office.');
  String get recoveredFromOffice =>
      _t('Imerejeshwa kutoka ofisini', 'Recovered from the office');
}
