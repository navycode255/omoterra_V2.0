part of 'strings.dart';

/// Owner performance screens (Phase 9): overview, ranking, attention, people and station scorecards, ratings.
/// Same rules as `Strings`: Swahili first, both languages, `_t(sw, en)`.
extension OwnerStrings on Strings {
  String get opTitle => _t('Utendaji', 'Performance');
  String get opEntryCaption => _t('Alama, nyota na yanayohitaji umakini',
      'Scores, stars and what needs attention');
  String get opPeriodDay => _t('Siku', 'Day');
  String get opPeriodWeek => _t('Wiki', 'Week');
  String get opPeriodMonth => _t('Mwezi', 'Month');
  String get opDate => _t('Tarehe', 'Date');
  String opRange(String from, String to) => from == to ? from : '$from – $to';
  String get opProfitIncomplete => _t('Haijakamilika', 'Incomplete');
  String get opProfitIncompleteHelp => _t(
      'Haijakamilika ina maana gharama inayohitajika kuhesabu faida bado haijawekwa.',
      'Incomplete means the cost needed to calculate profit has not been entered.');
  String get opViewAll => _t('Tazama yote', 'View all');
  String get opShowLess => _t('Ficha', 'Show less');
  String get opAttentionReview =>
      _t('Inahitaji ukaguzi wa ofisi', 'Requires office review');
  String get opAttentionPendingReview =>
      _t('Inasubiri ukaguzi wa ofisi', 'Awaiting office review');
  String get opAttentionSync =>
      _t('Inasubiri kusawazishwa', 'Awaiting synchronization');
  String get opAttentionStock =>
      _t('Inasubiri uhakiki', 'Awaiting stock review');
  String get opAttentionTarget =>
      _t('Inahitaji ufuatiliaji', 'Needs follow-up');
  String opProfitMissingDays(int days) => _t(
      'Faida haijulikani kwa siku $days · gharama haijawekwa',
      'Profit missing for $days ${days == 1 ? 'day' : 'days'} · cost not entered');
  String get opOpenProblemsShort => _t('Matatizo yaliyo wazi', 'Open problems');
  String get opPendingExpensesLabel =>
      _t('Gharama zinazosubiri', 'Pending expenses');
  String opStationDaySummary(String vendors, String profit) =>
      _t('$vendors · Faida: $profit', '$vendors · Profit: $profit');
  String get opStationDayReviewHint => _t(
      'Chagua siku ili kuangalia mauzo yaliyothibitishwa, gharama na faida.',
      'Select a day to review verified sales, expenses and profit.');
  String get opStationDayScope => _t(
      'Hapa huonekana tarehe zenye rekodi za kituo hiki pekee.',
      'Only the dates shown in the current station records appear here.');
  String opVendorVerifiedChickens(String chickens) =>
      _t('Kuku $chickens waliothibitishwa', '$chickens verified chickens');
  String opVendorBonusEarned(String amount) =>
      _t('Bonasi $amount', 'Bonus $amount');
  String opVendorBonusEstimated(String amount) =>
      _t('Makadirio $amount', 'Estimated $amount');
  String get opSalesLabel => _t('Mauzo', 'Sales');
  String opStationSummary(String chickens, String profit) => _t(
      'Kuku waliothibitishwa $chickens · Faida: $profit',
      '$chickens verified chickens · Profit: $profit');
  String get opChickens =>
      _t('Kuku (mauzo yaliyothibitishwa)', 'Chickens (verified sales)');
  String get opProfit => _t('Faida', 'Profit');
  String opProfitUnknown(int days) => _t(
      'Siku $days faida haijulikani (gharama haipo)',
      'Profit unknown on $days days (no cost)');
  String get opBonusEarned => _t('Bonasi zilizopatikana', 'Bonuses earned');
  String get opBonusEstimated =>
      _t('Bonasi za makadirio (bado hazilipwi)', 'Estimated (not yet payable)');
  String get opBonusAdjustments =>
      _t('Marekebisho ya bonasi', 'Bonus adjustments');
  String get opAttention => _t('Inahitaji umakini', 'Needs attention');
  String get opAttentionNone =>
      _t('Hakuna kinachohitaji umakini.', 'Nothing needs attention.');
  String get opCashShortTitle => _t('Fedha pungufu', 'Cash short');
  String get opCashNeedsReview =>
      _t('Inahitaji ukaguzi wa ofisi', 'Requires office review');
  String get opDifferenceResolved =>
      _t('Tofauti imetatuliwa', 'Difference resolved');
  String get opCashStateUnknown =>
      _t('Hali ya fedha haijulikani', 'Cash status is not available');
  String get opCashDetails => _t('Maelezo ya fedha', 'Cash details');
  String get opExpected => _t('Ilitarajiwa', 'Expected');
  String get opHandedOver => _t('Iliyokabidhiwa', 'Handed over');
  String get opRemainingCash => _t('Iliyobaki', 'Remaining');
  String get opConfirmed => _t('Imethibitishwa', 'Confirmed');
  String get opVendor => _t('Muuzaji', 'Vendor');
  String get opReviewDifference => _t('Kagua tofauti', 'Review difference');
  String get opPhoneSyncTitle => _t('Usawazishaji wa simu', 'Phone sync');
  String get opWaitingForDevice => _t('Inasubiri simu', 'Waiting for device');
  String get opSyncNoAlertTitle =>
      _t('Hakuna tahadhari ya simu', 'No current sync alert');
  String get opSyncStatusUnknown => _t(
      'Hali ya simu haijathibitishwa', 'Phone status could not be confirmed');
  String get opAffectedPhone => _t('Simu iliyoathirika', 'Affected phone');
  String get opAssignedTo => _t('Imepangiwa', 'Assigned to');
  String get opLastSync =>
      _t('Usawazishaji wa mwisho ulioripotiwa', 'Last sync reported by server');
  String get opNotConfirmed => _t('Haijathibitishwa', 'Not confirmed');
  String get opNotProvidedByServer =>
      _t('Haijatolewa na seva', 'Not provided by the server');
  String get opSyncPendingPhone =>
      _t('Bado haijathibitishwa na ofisi', 'Not yet confirmed by the office');
  String get opViewSyncReviews =>
      _t('Angalia rekodi zinazosubiri ukaguzi', 'View records awaiting review');
  String get opNoCurrentSyncAlert => _t(
      'Ofisi haioni tahadhari ya usawazishaji kwa simu hii sasa.',
      'The office no longer reports a sync alert for this phone.');
  String get opSyncHistoryUnavailable => _t(
      'Historia kamili ya usawazishaji haipatikani hapa.',
      'Full sync history is not available here.');
  String get opPendingExpensesTitle =>
      _t('Gharama zinazosubiri', 'Pending expenses');
  String get opAwaitingApproval =>
      _t('Inasubiri idhini ya ofisi', 'Awaiting office approval');
  String get opRequestedAmount => _t('Kiasi kilichoombwa', 'Requested amount');
  String get opExpenseDetails => _t('Maelezo ya gharama', 'Expense details');
  String get opSubmittedBy => _t('Aliyeandika', 'Submitted by');
  String get opExpenseAuditHistory =>
      _t('Historia ya ukaguzi', 'Audit history');
  String get opExpenseSubmitted => _t('Gharama imetumwa', 'Expense submitted');
  String get opExpenseApproved =>
      _t('Gharama imeidhinishwa', 'Expense approved');
  String get opExpenseRejected => _t('Gharama imekataliwa', 'Expense rejected');
  String get opOffice => _t('Ofisi', 'Office');
  String attentionKindName(String kind) => switch (kind) {
        'stock_difference' => _t('Tofauti za stoo', 'Stock differences'),
        'money_short' => _t('Fedha pungufu', 'Cash short'),
        'not_synced' => _t('Simu hazijatuma leo', 'Phones not synced today'),
        'expense_pending' => _t('Gharama zinazosubiri', 'Pending expenses'),
        'target_missed_3_days' =>
          _t('Chini ya lengo siku 3 mfululizo', 'Below target 3 days running'),
        _ => kind,
      };
  String attentionHeading(String name, int count) => '$name · $count';
  String attentionMore(int n) =>
      _t('Na mengine $n hayajaonyeshwa', '$n more not shown');
  String get opRanking => _t('Mpangilio kwa alama', 'Ranking by score');
  String get opRankingNone => _t('Hakuna aliyefanya kazi katika kipindi hiki.',
      'Nobody worked in this period.');
  String get opScoresNotSet => _t(
      'Alama hazijawekwa: mmiliki aweke uzito wa alama kwenye mipangilio ya bonasi na alama.',
      'Scores are not set: the owner sets the score weights in the bonus and score settings.');
  String opScore(int score) => _t('Alama $score/100', 'Score $score/100');
  String opStars(int stars) => _t('Nyota $stars/5', '$stars/5 stars');
  String get opNoScore => _t('Hakuna alama', 'No score');
  String opCardName(String card) => switch (card) {
        'vendor' => _t('Muuzaji', 'Vendor'),
        'supervisor' => _t('Msimamizi', 'Supervisor'),
        'manager' => _t('Meneja', 'Manager'),
        _ => card,
      };
  String opScoredDays(int n) => _t('Siku $n zenye alama', '$n scored days');
  String opAreaName(String area) => switch (area) {
        'sales' => _t('Mauzo', 'Sales'),
        'money' => _t('Fedha', 'Money'),
        'stock' => _t('Stoo', 'Stock'),
        'discipline' => _t('Nidhamu', 'Discipline'),
        'conduct' => _t('Tabia', 'Conduct'),
        'stations' => _t('Vituo vyake', 'Their stations'),
        'speed' => _t('Kasi ya kuthibitisha', 'Speed of checking'),
        'problems' => _t('Matatizo', 'Problems'),
        'rating' => _t('Nyota alizopewa', 'Rating'),
        'on_time' => _t('Kwa wakati', 'On time'),
        'open_items' => _t('Yanayosubiri', 'Waiting items'),
        _ => area,
      };
  String opAreaValue(int? value) =>
      value == null ? _t('Haijapimwa', 'Not rated') : '$value/100';
  String get opWeightsNotSet =>
      _t('Uzito wa alama haujawekwa', 'Score weights not set');
  String get opSetWeights => _t('Weka uzito', 'Set weights');
  String get opNotRatedYet => _t('Bado haijapimwa', 'Not rated yet');
  String get opScorePending => _t('Alama zinasubiri', 'Score pending');
  String opMeasured(int n, int total) =>
      _t('Maeneo $n kati ya $total yamepimwa', '$n of $total areas measured');
  String get opPartial => _t('Sehemu', 'Partial');
  String get opAllMeasured => _t('Maeneo yote yamepimwa', 'All areas measured');
  String get opEqualWeights => _t('Uzito sawa', 'Equal weights');
  String get opYourWeights => _t('Uzito ulioweka', 'Your weights');
  String get opRatePerformance => _t('Pima utendaji', 'Rate performance');
  String get opUpdateRating => _t('Badilisha alama', 'Update rating');
  String get opRateChoose => _t('Chagua eneo', 'Choose an area');
  String opRateArea(String area) => _t('Pima $area', 'Rate $area');
  String get opRateAreaHelp =>
      _t('Weka alama kuanzia 0 hadi 100.', 'Enter a score from 0 to 100.');
  String opRateHelpOn(String date) => _t(
      'Weka alama kuanzia 0 hadi 100 kwa $date.',
      'Enter a score from 0 to 100 for $date.');
  String get opRateOutOfRange =>
      _t('Weka namba kuanzia 0 hadi 100.', 'Enter a number from 0 to 100.');
  String get opSaveShort => _t('Hifadhi', 'Save');
  String get opRatingUpdated => _t('Alama zimebadilishwa', 'Rating updated');
  String get opRatingRecorded => _t(
      'Mabadiliko haya yamehifadhiwa kwenye historia ya alama.',
      'This change is recorded in the rating history.');
  String get opRatingHistory => _t('Historia ya alama', 'Rating history');
  String opChanges(int n) =>
      n == 1 ? _t('Badiliko 1', '1 change') : _t('Mabadiliko $n', '$n changes');
  String get opNoRatingChanges =>
      _t('Hakuna mabadiliko ya alama siku hii.', 'No rating changes this day.');
  String get opNotAllRated => _t(
      'Alama ya jumla haionyeshwi kwa sababu si maeneo yote yamepimwa.',
      'Overall score is not shown because not all areas were rated.');
  String get opWhyScores => _t('Sababu za alama', 'Why these scores');
  String get opNoWorkDay => _t(
      'Hakuna siku ya kazi ya kupima katika kipindi hiki.',
      'There is no work.');
  String get opVerifiedChickens =>
      _t('Kuku waliothibitishwa', 'Verified chickens');
  String opPieces(String n) => _t('Vipande $n', '$n pcs');
  String get opEstimatedShort => _t('Makadirio', 'Estimated');
  String get opEstimatedHelp => _t(
      'Bonasi za siku ambazo bado hazijafungwa. Hazijalipwa hadi siku zifungwe.',
      'Bonuses for days not locked yet. Nothing is paid until those days are locked.');
  String get opAreas => _t('Maeneo', 'Areas');
  String get opDays => _t('Siku', 'Days');
  String get opNoDays =>
      _t('Hakuna siku katika kipindi hiki.', 'No days in this period.');
  String get opNoCard => _t(
      'Mtu huyu hapimwi (mmiliki au bila jukumu la kupimwa).',
      'This person is not scored (the owner, or no scored role).');
  String get opBonusTitle => _t('Bonasi za kipindi', 'Bonuses this period');
  String get opRate => _t('Toa nyota', 'Rate');
  String opRateTitle(String name) => _t('Nyota kwa $name', 'Rate $name');
  String get opRateHelp => _t(
      'Nyota za mwisho ndizo zinazohesabiwa kwenye alama.',
      'The latest rating is the one the score uses.');
  String opStarOption(int n) => _t('Nyota $n', '$n stars');
  String get opRateComment => _t('Maoni (hiari)', 'Comment (optional)');
  String get opRateSave => _t('Hifadhi nyota', 'Save rating');
  String get opRatePick => _t('Chagua nyota 1 hadi 5.', 'Choose 1 to 5 stars.');
  String get opRateSaved => _t('Nyota zimehifadhiwa.', 'Rating saved.');
  String get opPayments => _t('Malipo', 'Payments');
  String get opPaymentsCaption => _t(
      'Mshahara, bonasi na malipo yaliyorekodiwa',
      'Pay, bonuses and recorded payments');
  String get opStations => _t('Vituo', 'Stations');
  String get opSales => _t('Mauzo', 'Sales');
  String opVerified(String amount) =>
      _t('Yaliyothibitishwa $amount', 'Verified $amount');
  String get opExpenses => _t('Matumizi', 'Expenses');
  String opPendingExpenses(String amount) =>
      _t('Gharama zinazosubiri $amount', 'Pending expenses $amount');
  String opTarget(String amount) => _t('Lengo $amount', 'Target $amount');
  String get opTargetUnset => _t('Lengo halijawekwa', 'No target set');
  String get opProfitUnknownShort => _t('Haijulikani', 'Unknown');
  String opOpenProblems(int n) =>
      _t('Matatizo yaliyo wazi: $n', 'Open problems: $n');
  String opVendorsSharing(int n) => _t('Wauzaji $n', '$n vendors');
  String opChickensValue(String n) => _t('Kuku $n', '$n chickens');
  String opVendorBonus(String earned, String estimated) => _t(
      'Bonasi $earned · makadirio $estimated',
      'Bonus $earned · estimated $estimated');
  String get opVendors => _t('Wauzaji', 'Vendors');
  String get opStationPerformanceHelp => _t(
      'Chagua kipindi na tarehe kuona matokeo ya kituo. Mauzo yaliyothibitishwa, matumizi, faida na gharama zinazosubiri huonyeshwa tofauti. Chagua siku ili kukagua rekodi zake.',
      'Choose a period and date to view station results. Verified sales, expenses, profit and pending expenses stay distinct. Select a day to review its records.');
  String get opStationPerformance =>
      _t('Utendaji wa kituo', 'Station performance');
  String get opPersonPerformance =>
      _t('Alama, nyota na bonasi', 'Score, stars and bonuses');
}
