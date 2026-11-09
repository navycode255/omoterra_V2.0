part of 'strings.dart';

/// Automatic verification (operations controls, Milestone E). Same rules as
/// `Strings`: Swahili first, `_t(sw, en)`. Anything automatic says so.
extension AutoVerifyStrings on Strings {
  // Station Mauzo.
  String get autoHeldLabel =>
      _t('Imezuiwa, inasubiri ukaguzi', 'Held for a person to check');
  String get autoVerifiedLabel =>
      _t('Imethibitishwa moja kwa moja', 'Verified automatically');
  String get autoVerifiedFilter =>
      _t('Yaliyothibitishwa moja kwa moja', 'Verified automatically');
  String get autoVerifiedNone => _t(
      'Hakuna mauzo yaliyothibitishwa moja kwa moja.',
      'No sales were verified automatically.');
  String autoQueueLine(int passed, int held) => _t(
      'Leo: moja kwa moja $passed · yamezuiwa $held',
      'Today: automatic $passed · held $held');

  /// Why a sale waits for a person. A code this app does not know yet still
  /// reads as a hold, so a newer server never shows a blank.
  String autoHoldReason(String code) => switch (code) {
        'mpesa' => _t('Malipo ya M-Pesa hukaguliwa na mtu',
            'M-Pesa payments are checked by a person'),
        'credit_not_allowed' => _t('Mteja haruhusiwi mkopo',
            'Credit is not allowed for this customer'),
        'credit_over_limit' => _t('Mauzo yamepita kikomo cha mkopo cha mteja',
            'The sale takes the customer over their limit'),
        'oversold' =>
          _t('Stoo haitoshi kwa mauzo haya', 'Stock does not cover this sale'),
        'stale_price' => _t('Bei si ile iliyokuwepo wakati wa mauzo',
            'The price was not the one in force at the time'),
        'late' => _t('Mauzo yamefika kwa kuchelewa', 'The sale arrived late'),
        'possible_duplicate' =>
          _t('Huenda mauzo haya yamerudiwa', 'This sale may be a duplicate'),
        'over_amount' => _t('Kiasi kimepita kikomo cha mmiliki',
            "The amount is above the owner's limit"),
        'clock_skew' => _t('Saa ya simu ilikosea siku hiyo',
            "The phone's clock was wrong that day"),
        'needs_approval' => _t(
            'Kurekodi stoo ya siku iliyopita kunahitaji idhini ya fedha au mmiliki',
            'Recording stock on an earlier day needs approval from finance or the owner'),
        'day_locked' => _t(
            'Bonasi ya siku hii ilishafungwa; mtu athibitishe mauzo haya',
            "This day's bonus was already locked; a person must verify this sale"),
        'cancel_requested' => _t(
            'Kuna ombi la kubatilisha mauzo haya linalosubiri uamuzi',
            'A request to cancel this sale is waiting for a decision'),
        'office_entered' => _t(
            'Mauzo haya yameingizwa na ofisi baada ya simu kupotea; mtu athibitishe',
            'The office entered this sale after a phone was lost; a person must verify it'),
        'possible_duplicate_entry' => _t(
            'Simu imetuma mauzo kwa siku ambayo ofisi iliingiza mauzo; huenda yamerudiwa',
            'A phone sent a sale for a day the office entered one; it may be the same sale'),
        'sampled' => _t('Yamechaguliwa kwa ukaguzi wa kushtukiza',
            'Picked for a spot check'),
        _ => _t('Yanahitaji ukaguzi wa mtu', 'Needs a person to check'),
      };

  // Settings.
  String get autoVerifySection => _t('Mauzo', 'Sales');
  String get autoVerifyTitle =>
      _t('Uthibitisho wa moja kwa moja', 'Automatic verification');
  String get autoVerifyHelp => _t(
      'Mauzo ya kawaida ya taslimu na mkopo ndani ya kikomo yanathibitishwa yenyewe. Mauzo ya leo hukaguliwa tu baada ya muuzaji kufunga siku, ili aweze kubatilisha makosa yake. Saa uliyoweka ni kwa siku zilizopita zisizo na hesabu. M-Pesa haipiti. Hesabu ya kufunga siku bado inathibitishwa na mtu.',
      'Normal cash sales and credit within the limit verify themselves. Today\'s sales are checked only after the vendor closes the day, so they can still void their mistakes. The time you set is for past days with no count. M-Pesa never passes. The closing count is still confirmed by a person.');
  String get autoVerifyHelpOnce => _t(
      'Mauzo hukaguliwa mara moja tu. Yaliyokaguliwa kwenye jaribio hayathibitishwi yenyewe baadaye; yanabaki kwa mtu.',
      'A sale is checked once. Sales checked in a trial do not verify themselves later; they stay with a person.');
  String get autoVerifyMode => _t('Hali', 'Mode');
  String autoVerifyModeName(String mode) => switch (mode) {
        'shadow' => _t('Jaribio (haithibitishi)', 'Trial (verifies nothing)'),
        'live' => _t('Inafanya kazi', 'Live'),
        _ => _t('Imezimwa', 'Off'),
      };
  String get autoVerifyStations => _t('Vituo', 'Stations');
  String get autoVerifyRunTime => _t('Saa ya siku zilizopita zisizo na hesabu',
      'Time for past days with no count');
  String get autoVerifyLateHours =>
      _t('Imechelewa baada ya saa ngapi', 'Late after how many hours');
  String get autoVerifyDuplicateMinutes =>
      _t('Dakika za kushuku kurudiwa', 'Minutes to suspect a duplicate');
  String get autoVerifyMaxAmount =>
      _t('Kiasi cha juu cha mauzo (TSh)', 'Highest sale amount (TSh)');
  String get autoVerifySamplePercent =>
      _t('Asilimia ya ukaguzi wa kushtukiza', 'Percent for spot checks');
  String get autoVerifyStalePrice => _t('Bei ya zamani', 'Older price');
  String get autoVerifyStaleHold => _t('Zuia yakaguliwe', 'Hold for a person');
  String get autoVerifyStaleAccept => _t('Ruhusu ipite', 'Let it pass');
  String get autoVerifyNotSet => _t('Haijawekwa', 'Not set');
  String get autoVerifySave => _t('Hifadhi', 'Save');
  String get autoVerifySaved => _t('Imehifadhiwa.', 'Saved.');
  String get autoVerifyIncomplete => _t(
      'Chagua hali na ujaze kila kitu. Hakuna thamani inayowekwa kwa niaba yako.',
      'Choose a mode and fill in everything. No value is set for you.');
  String get autoVerifyLiveConfirmTitle => _t(
      'Washa uthibitisho wa moja kwa moja?', 'Turn on automatic verification?');
  String get autoVerifyLiveConfirmBody => _t(
      'Mauzo yanayopita yatatoa stoo na kuhesabiwa kwenye malipo bila mtu kuyakagua. Mauzo ya kabla ya siku ulipowasha kwa mara ya kwanza kituo hayaguswi; yanabaki kwa watu.',
      'Sales that pass will move stock and count towards pay without a person checking them. Sales from before the day you first switched a station on are left alone; they stay with people.');
  String autoVerifyReason(String mode) => _t(
      'Uthibitisho wa moja kwa moja: ${autoVerifyModeName(mode)}',
      'Automatic verification: ${autoVerifyModeName(mode)}');

  // Trial summary, the owner's evidence for going live.
  String get autoSummaryTitle => _t('Matokeo ya jaribio', 'Trial results');
  String autoSummaryWeek(String from, String to) =>
      _t('$from – $to', '$from – $to');
  String get autoSummaryEarlierWeek => _t('Wiki iliyotangulia', 'Earlier week');
  String get autoSummaryLaterWeek => _t('Wiki iliyofuata', 'Later week');
  String get autoSummaryEmpty => _t('Hakuna mauzo yaliyokaguliwa wiki hii.',
      'No sales were checked this week.');
  String autoSummaryWouldPass(int n) =>
      _t('Yangepita: $n', 'Would have passed: $n');
  String autoSummaryWouldHold(int n) =>
      _t('Yangezuiwa: $n', 'Would have been held: $n');
  String autoSummaryReason(String reason, int n) => '$reason: $n';
  String autoSummaryUnchecked(int n) => _t(
      'Mauzo $n hayakukaguliwa ingawa muda wake umefika',
      '$n sales were due for a check and have none');
  String autoSummaryStaffWouldHold(int n) => _t(
      'Yaliyothibitishwa na watu ambayo sheria zingezuia: $n',
      'Verified by staff, but the rules would have held: $n');
}
