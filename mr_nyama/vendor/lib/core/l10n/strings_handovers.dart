part of 'strings.dart';

/// Handover time and note, the vendor's read-only handover list, the cash
/// limit and the estimate (operations controls, Milestone D). Same rules as
/// `Strings`: Swahili first, `_t(sw, en)`.
extension HandoverStrings on Strings {
  // Office form.
  String get handoverReceivedAt => _t('Ilipokelewa saa', 'Received at');
  String get handoverReceivedNow => _t('Sasa', 'Now');
  String get handoverNoteLabel => _t('Maelezo (si lazima)', 'Note (optional)');
  String get handoverTimeFuture => _t(
      'Saa hii bado haijafika. Chagua saa iliyopita.',
      'That time has not come yet. Choose a time that has passed.');
  String get handoverAmountNotFromSales => _t(
      'Andika kiasi ulichopokea kwa mkono. Hakijajazwa kutoka mauzo.',
      'Type the amount you received. It is not filled in from sales.');

  // The vendor's own handovers (read-only).
  String get handoversTitle => _t('Makabidhiano', 'Handovers');
  String get handoversReadOnly => _t(
      'Haya yamerekodiwa na ofisi kwa jina lako. Huwezi kuyabadilisha.',
      'The office recorded these in your name. You cannot change them.');
  String get handoversEmpty => _t(
      'Hakuna makabidhiano katika siku 31 zilizopita.',
      'No handovers in the last 31 days.');
  String get vendorMoneySummaryTitle => _t('Hali ya fedha', 'Cash summary');
  String get vendorMoneyOwed =>
      _t('Kiasi kilichothibitishwa kinachodaiwa', 'Confirmed amount due');
  String get vendorMoneyCredit => _t('Salio la ziada', 'Credit balance');
  String get vendorMoneyUnverifiedSales => _t(
      'Mauzo taslimu yanayosubiri uthibitisho',
      'Cash sales awaiting verification');
  String get vendorMoneyUnconfirmedHandovers => _t(
      'Makabidhiano yanayosubiri uthibitisho',
      'Handovers awaiting confirmation');
  String get vendorMoneyPendingExpenses =>
      _t('Gharama zinazosubiri idhini', 'Expenses awaiting approval');
  String get vendorMoneyNote => _t(
      'Mauzo ya fedha taslimu ambayo hayajathibitishwa, makabidhiano ambayo hayajathibitishwa na gharama zinazosubiri idhini yanaonyeshwa kando; havibadilishi kiasi kilichothibitishwa kinachodaiwa.',
      'Unverified cash sales, handovers awaiting confirmation and expenses awaiting approval are shown separately; they do not change the confirmed amount due.');
  String handoverReceiver(String name) =>
      _t('Alipokea: $name', 'Received by: $name');
  String handoverAt(String time, String date) =>
      _t('Saa $time · $date', '$time · $date');
  String handoverStatus(String code) => switch (code) {
        'confirmed' => _t('Imethibitishwa', 'Confirmed'),
        'reversed' => _t('Imebatilishwa', 'Cancelled'),
        _ => _t('Imerekodiwa', 'Recorded'),
      };

  // Owner overview and money day.
  String get supervisorFundsCaption =>
      _t('Bado haijathibitishwa', 'Not yet confirmed');
  String get cashOnHandEstimate =>
      _t('Makadirio ya fedha mkononi sasa', 'Estimated cash on hand now');
  String get cashOnHandEstimateHelp => _t(
      'Ni makadirio kutoka mauzo, gharama na makabidhiano. Hayathibitishi kuwa fedha ipo.',
      'An estimate from sales, expenses and handovers. It does not prove the cash is there.');

  // Cash limit setting (owner).
  String get cashLimitTitle =>
      _t('Kikomo cha fedha mkononi', 'Cash on hand limit');
  String get cashLimitNotSet => _t('Haijawekwa', 'Not set');
  String get cashLimitHelp => _t(
      'Makadirio ya mmoja wa wauzaji yakizidi kiasi hiki, msimamizi anaarifiwa mara moja kwa siku. Isipowekwa, tahadhari hii imezimwa.',
      'When a vendor\'s estimate goes above this amount, the supervisor is told once a day. While it is not set, this alert is off.');
  String get cashLimitAmount => _t('Kikomo (TSh)', 'Limit (TSh)');
  String get cashLimitSave => _t('Weka kikomo', 'Set limit');
  String get cashLimitClear => _t('Zima tahadhari', 'Turn the alert off');
  String get cashLimitInvalid => _t(
      'Andika kiasi kamili cha shilingi kuanzia 1.',
      'Enter a whole number of shillings from 1.');
  String cashLimitReason(String amount) => _t(
      'Kikomo cha fedha mkononi kimewekwa kuwa TSh $amount.',
      'Cash on hand limit set to TSh $amount.');
  String get cashLimitClearedReason => _t(
      'Tahadhari ya kikomo cha fedha mkononi imezimwa.',
      'The cash on hand limit alert was turned off.');
}
