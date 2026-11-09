part of 'strings.dart';

/// Blind Funga Siku count: the vendor counts without seeing the expected
/// figure, then freezes the count before the differences are shown.
/// Same rules as `Strings`: Swahili first, `_t(sw, en)`.
extension BlindCountStrings on Strings {
  String get freezeTitle => _t('Hakiki hesabu?', 'Check the count?');
  String get freezeBody => _t('Ukiendelea huwezi kubadilisha hesabu.',
      'If you continue you cannot change the count.');
  String get freezeContinue => _t('Endelea', 'Continue');
  String get freezeBack => _t('Rudi kuhesabu', 'Back to counting');
  String get frozenNote => _t(
      'Namba hizi zimefungwa na hazibadiliki, hata ukitoka na kurudi. Kosa la kuandika linasahihishwa na ofisi. Bado hazijahifadhiwa: gusa "Hifadhi na funga siku".',
      'These figures are locked and do not change, even if you leave and come back. A typing mistake is corrected by the office. They are not saved yet: tap "Hifadhi na funga siku".');
  String get countedFigure => _t('Umehesabu', 'Counted');
}
