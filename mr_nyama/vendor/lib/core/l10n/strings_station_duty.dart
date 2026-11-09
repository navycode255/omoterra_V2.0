part of 'strings.dart';

/// Who answers for a station's stock difference (owner decision, 1 November 2026):
/// the supervisor reviews it and no vendor is charged automatically.
/// Same rules as `Strings`: Swahili first, `_t(sw, en)`.
extension StationDutyStrings on Strings {
  String get stationDifferenceLine => _t(
      'Tofauti ya kituo: msimamizi anakagua. Hakuna muuzaji anayedaiwa moja kwa moja.',
      'Station difference: the supervisor reviews it. No vendor is charged automatically.');
}
