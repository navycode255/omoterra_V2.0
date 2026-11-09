part of 'strings.dart';

/// The vendor's progress card on Nyumbani (Phase 10).
/// Same rules as `Strings`: Swahili first, both languages, `_t(sw, en)`.
extension ProgressStrings on Strings {
  String get progressTitle => _t('Lengo la leo', "Today's target");
  String progressChickens(String sold, int? target) => target == null
      ? _t('Kuku $sold', 'Chickens $sold')
      : _t('Kuku $sold / $target', 'Chickens $sold / $target');
  String progressNextStep(int chickens, String amount) => chickens == 1
      ? _t('Kuku 1 zaidi kupata bonasi ya $amount',
          '1 more chicken for a bonus of $amount')
      : _t('Kuku $chickens zaidi kupata bonasi ya $amount',
          '$chickens more chickens for a bonus of $amount');
  String get progressBonusToday => _t('Bonasi ya leo', "Today's bonus");
  String get progressEstimated => _t('makadirio', 'estimated');
  String get progressEarned => _t('umepata', 'earned');
  String progressStars(int stars) => _t('Nyota $stars/5', 'Stars $stars/5');
  String progressPeriod(String period) => period == 'monthly'
      ? _t('Bonasi ya mwezi huu', "This month's bonus")
      : _t('Bonasi ya wiki hii', "This week's bonus");
  String progressPeriodAmount(String earned, String? estimated) => estimated ==
          null
      ? earned
      : _t('$earned + $estimated makadirio', '$earned + $estimated estimated');
  String get progressEstimatedNote => _t(
      'Makadirio hadi mauzo yathibitishwe na siku ifungwe.',
      'Estimated until sales are verified and the day is closed.');
}
