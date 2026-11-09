part of 'strings.dart';

/// Owner bonus screens, performance settings and sale corrections (Phase 9).
/// Same rules as `Strings`: Swahili first, both languages, `_t(sw, en)`.
extension BonusStrings on Strings {
  // Bonuses ------------------------------------------------------------------
  String get bonusTitle => _t('Bonasi', 'Bonuses');
  String get bonusEarnings => _t('Mapato', 'Earnings');
  String get bonusEarnedStatus => _t('Imepatikana', 'Earned');
  String get bonusEstimatedStatus => _t('Makadirio', 'Estimated');
  String get bonusVerifiedChickens =>
      _t('Kuku waliothibitishwa', 'Verified chickens');
  String bonusChickenCount(String count) => _t('$count kuku', '$count pcs');
  String get bonusDailyEarnings => _t('Mapato ya siku', 'Daily earnings');
  String get bonusProfitCannotConfirm => _t(
      'Faida haiwezi kuthibitishwa hadi gharama ya kawaida ya bidhaa iingizwe.',
      'Profit cannot be confirmed until the product\'s standard cost is entered.');
  String get bonusPayableEarned => _t(
      'Mapato yanayolipika pekee · makadirio hayajajumuishwa',
      'Payable earnings only · estimates excluded');
  String get bonusChickenPartShort => _t('Bonasi ya kuku', 'Chicken bonus');
  String get bonusProfitPartShort => _t('Bonasi ya faida', 'Profit bonus');
  String get bonusOverallStatus => _t('Hali ya jumla', 'Overall status');
  String get bonusRecords => _t('Rekodi', 'Records');
  String get bonusEstimatedNotPayable =>
      _t('Bado hailipiki', 'Not yet payable');
  String get bonusDayReviewOnly => _t(
      'Siku hii inaonyeshwa kwa ajili ya ukaguzi. Makadirio hayahesabiwi kama mapato yaliyopatikana au yanayolipika hadi siku ithibitishwe.',
      'This day is shown for review. Estimates do not count as earned or payable until the day is verified.');
  String bonusProfitMissingDays(int days) => _t(
      'Faida haipatikani kwa siku $days · weka gharama ya kawaida',
      'Profit unavailable for $days ${days == 1 ? 'day' : 'days'} · set standard cost');
  String get bonusCaption => _t(
      'Bonasi za wauzaji: zilizopatikana na makadirio',
      'Vendor bonuses: earned and estimated');
  String get bonusPeriodDay => _t('Siku', 'Day');
  String get bonusPeriodWeek => _t('Wiki', 'Week');
  String get bonusPeriodMonth => _t('Mwezi', 'Month');
  String get bonusDate => _t('Tarehe', 'Date');
  String bonusRange(String from, String to) =>
      from == to ? from : '$from – $to';
  String bonusEarned(String amount) =>
      _t('Imepatikana $amount', 'Earned $amount');
  String bonusEstimated(String amount) =>
      _t('Makadirio $amount', 'Estimated $amount');
  String bonusAdjustments(String amount) =>
      _t('Marekebisho $amount', 'Adjustments $amount');
  String get bonusEstimatedNote => _t(
      'Makadirio hayalipwi mpaka hesabu ya Funga Siku ya kituo ithibitishwe.',
      'Estimates are not paid until the station\'s Funga Siku count is confirmed.');
  String get bonusNone =>
      _t('Hakuna bonasi katika kipindi hiki.', 'No bonuses in this period.');
  String bonusChickens(String n) => _t('Kuku $n', '$n chickens');
  String get bonusLocked => _t('Imefungwa', 'Locked');
  String get bonusOpen => _t('Makadirio', 'Estimated');
  String bonusChickenPart(String amount) =>
      _t('Bonasi ya kuku: $amount', 'Chicken bonus: $amount');
  String bonusProfitPart(String amount) =>
      _t('Bonasi ya faida: $amount', 'Profit bonus: $amount');
  String bonusShared(int n) => _t(
      'Kituo kilikuwa na wauzaji $n: bonasi ya faida imegawanywa kwa mauzo.',
      '$n vendors at the station: the profit bonus is split by sales.');
  String get bonusStandardCost =>
      _t('Gharama ya kawaida imetumika', 'Standard cost used');
  String get bonusProfitUnknown => _t(
      'Faida haijulikani: weka gharama ya kawaida ya bidhaa',
      'Profit unknown: set the product\'s standard cost');
  String bonusDayAdjusted(String amount) => _t(
      'Marekebisho ya siku hii: $amount', 'This day\'s adjustments: $amount');
  String get bonusPay => _t('Lipa', 'Pay');
  String get bonusPayCaption =>
      _t('Malipo yaliyorekodiwa', 'Recorded payments');
  String get bonusDays => _t('Siku', 'Days');
  String get bonusVerifiedSales =>
      _t('Mauzo yaliyothibitishwa', 'Verified sales');

  // Sale corrections ----------------------------------------------------------
  String get correctSale => _t('Sahihisha mauzo', 'Correct the sale');
  String get correctSalesCaption => _t(
      'Mmiliki anasahihisha mauzo yaliyothibitishwa',
      'The owner corrects verified sales');
  String get correctSaleWarning => _t(
      'Mauzo haya yatafutwa. Bidhaa zinarudi stoo ya kituo, na kama siku imefungwa bonasi yake inabadilika kwa marekebisho ya leo. Hayawezi kurudishwa.',
      'This sale will be voided. Its stock returns to the station, and if the day is locked its bonus changes by an adjustment dated today. This cannot be undone.');
  String get correctSaleDone => _t('Mauzo yamesahihishwa.', 'Sale corrected.');
  String get correctedSale => _t('Imesahihishwa', 'Corrected');
  String get noVerifiedSales => _t('Hakuna mauzo yaliyothibitishwa siku hii.',
      'No verified sales this day.');

  // Performance settings ------------------------------------------------------
  String get perfSettings => _t('Bonasi na alama', 'Bonuses and scores');
  String get perfSettingsCaption => _t(
      'Malengo, bonasi, gharama na uzito wa alama',
      'Targets, bonuses, costs and score weights');
  String get perfNotSet => _t('Haijawekwa', 'Not set');
  String get perfSaved => _t('Imehifadhiwa.', 'Saved.');
  String get perfSectionBonus => _t('Bonasi', 'Bonuses');
  String get perfSectionCost => _t('Gharama', 'Costs');
  String get perfSectionScores => _t('Alama', 'Scores');
  String get perfChicken => _t('Bonasi ya kuku', 'Chicken bonus');
  String perfChickenSummary(int target, int steps) =>
      _t('Lengo $target · hatua $steps', 'Target $target · $steps steps');
  String get perfTarget => _t('Lengo la kuku kwa siku', 'Daily chicken target');
  String get perfSteps => _t('Hatua', 'Steps');
  String get perfStepAt => _t('Kuku', 'Chickens');
  String get perfStepAmount => _t('Kiasi (TSh)', 'Amount (TSh)');
  String get perfAddStep => _t('Ongeza hatua', 'Add a step');
  String get perfRemoveStep => _t('Ondoa hatua', 'Remove step');
  String get perfPerExtra => _t('Kwa kila kuku juu ya hatua ya mwisho (TSh)',
      'Per chicken above the last step (TSh)');
  String get perfChickenHelp => _t(
      'Hatua zinajumlishwa: kila hatua inayofikiwa inaongeza kiasi chake. Kila hatua iwe juu ya lengo na juu ya ile iliyotangulia.',
      'Steps add up: each step reached adds its amount. Each step is above the target and above the one before.');
  String get perfEquivalents => _t('Kuku sawa na', 'Chicken equivalents');
  String get perfEquivalentsCaption => _t(
      'Kila bidhaa inahesabika kama kuku wangapi (mf. nusu 0.5)',
      'How many chickens each product counts as (e.g. half 0.5)');
  String perfEquivalentCount(int n) =>
      _t('Bidhaa $n zimewekwa', '$n products set');
  String get perfEquivalentLabel =>
      _t('Inahesabika kama kuku', 'Counts as chickens');
  String get perfEquivalentInvalid => _t(
      'Andika namba kati ya 0 na 10, desimali 2 zaidi.',
      'Write a number from 0 to 10, at most 2 decimals.');
  String get perfProfit => _t('Bonasi ya faida', 'Profit bonus');
  String perfProfitSummary(String target, String share) =>
      _t('Lengo $target · $share%', 'Target $target · $share%');
  String get perfDefaultTarget =>
      _t('Lengo la faida kwa siku (TSh)', 'Daily profit target (TSh)');
  String get perfShare => _t('Sehemu kwa muuzaji (%)', 'Vendor\'s share (%)');
  String get perfStationTargets =>
      _t('Lengo la kituo (hiari)', 'Station target (optional)');
  String get perfProfitHelp => _t(
      'Bonasi = sehemu % ya faida iliyozidi lengo. Kituo kisicho na lengo lake kinatumia lengo la kawaida.',
      'Bonus = share % of the profit above the target. A station without its own target uses the default.');
  String get perfShareInvalid =>
      _t('Sehemu ni kati ya 0 na 100.', 'The share is from 0 to 100.');
  String get perfPayPeriod => _t('Kipindi cha malipo', 'Pay period');
  String get perfWeekly => _t('Kila wiki', 'Weekly');
  String get perfMonthly => _t('Kila mwezi', 'Monthly');
  String get perfStandardCost => _t('Gharama ya kawaida', 'Standard cost');
  String get perfStandardCostCaption => _t(
      'Inatumika pale mzigo hauna bei ya makubaliano',
      'Used when a delivery has no agreed price');
  String perfCostCount(int n) => _t('Bidhaa $n zimewekwa', '$n products set');
  String get perfCostLabel =>
      _t('Gharama kwa kipimo (TSh)', 'Cost per unit (TSh)');
  String get perfWeights => _t('Uzito wa alama', 'Score weights');
  String perfWeightsFor(String key) => switch (key) {
        'score.weights.vendor' => _t('Muuzaji', 'Vendor'),
        'score.weights.supervisor' => _t('Msimamizi', 'Supervisor'),
        _ => _t('Mhasibu na uendeshaji', 'Finance and operations'),
      };
  String perfArea(String area) => switch (area) {
        'sales' => _t('Mauzo', 'Sales'),
        'money' => _t('Fedha', 'Money'),
        'stock' => _t('Stoo', 'Stock'),
        'discipline' => _t('Nidhamu', 'Discipline'),
        'conduct' => _t('Tabia', 'Conduct'),
        'stations' => _t('Vituo vyake', 'Their stations'),
        'speed' => _t('Kasi ya kuthibitisha', 'Speed of checking'),
        'problems' => _t('Matatizo', 'Problems'),
        'rating' => _t('Nyota za mmiliki', 'Owner rating'),
        'on_time' => _t('Kwa wakati', 'On time'),
        'open_items' => _t('Yanayosubiri', 'Waiting items'),
        _ => area,
      };
  String perfWeightsTotal(int total) =>
      _t('Jumla $total / 100', 'Total $total / 100');
  String get perfWeightsInvalid =>
      _t('Jumla iwe 100 kabisa.', 'The total must be exactly 100.');
  String get perfNumberInvalid =>
      _t('Andika namba nzima.', 'Write a whole number.');
  String get perfStepsInvalid => _t(
      'Kila hatua iwe juu ya lengo na juu ya ile iliyotangulia.',
      'Each step must be above the target and the step before.');
  String perfReason(String what) =>
      _t('Mmiliki amebadilisha: $what', 'Owner changed: $what');
  String get perfRemove => _t('Ondoa', 'Remove');
}
