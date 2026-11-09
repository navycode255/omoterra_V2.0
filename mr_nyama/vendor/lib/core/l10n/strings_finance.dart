part of 'strings.dart';

/// Finance books in the office (Phase 12): accounts, posting map, periods, journal, reports.
/// Same rules as `Strings`: Swahili first, both languages, `_t(sw, en)`.
extension FinanceStrings on Strings {
  String get financeBooks => _t('Vitabu vya fedha', 'Finance books');
  String get financeBooksCaption => _t('Akaunti, uingizaji, vipindi na ripoti',
      'Accounts, posting, periods and reports');
  String get financeConfirmNote => _t(
      'Majina ya akaunti na jinsi kila tukio linavyoingizwa yathibitishwe na mhasibu kabla ya kutegemewa.',
      'Confirm account names and how each event posts with the accountant before relying on them.');

  // Status and posting.
  String financeWaitingSummary(int n) => _t('$n kuingizwa', '$n to post');
  String financeSetupSummary(int n) => n == 1
      ? _t('Mpangilio 1 unahitajika', '1 rule missing')
      : _t('Mipangilio $n inahitajika', '$n rules missing');
  String get financeStatusTitle => _t('Hali ya vitabu', 'Books status');
  String financeUnposted(int n) => n == 1
      ? _t('Tukio 1 bado halijaingizwa', '1 event not yet posted')
      : _t('Matukio $n bado hayajaingizwa', '$n events not yet posted');
  String get financeAllPosted =>
      _t('Matukio yote yameingizwa.', 'Every event is posted.');
  String financeUnconfigured(int n) => _t(
      'Matukio $n hayana mpangilio, kwa hiyo hayataingizwa.',
      '$n events have no posting rule, so they will not post.');
  String financeLastPosted(String when) =>
      _t('Mara ya mwisho: $when', 'Last posted: $when');
  String get financeNeverPosted =>
      _t('Bado hakuna kilichoingizwa.', 'Nothing has been posted yet.');
  String financeEventCount(String event, int n) => '$event: $n';
  String get financePost => _t('Tuma kwenye vitabu', 'Post to the books');
  String get financePostUntil => _t('Hadi tarehe', 'Up to');
  String financePostConfirmTitle(String date) =>
      _t('Tuma matukio hadi $date?', 'Post events up to $date?');
  String get financePostConfirmBody => _t(
      'Kila tukio lililothibitishwa na lenye mpangilio linaingizwa mara moja tu. Hakuna kinachofutwa.',
      'Each verified event with a posting rule posts once. Nothing is deleted.');
  String financePosted(int n) => n == 1
      ? _t('Ingizo 1 limeandikwa.', '1 entry written.')
      : _t('Maingizo $n yameandikwa.', '$n entries written.');
  String get financePostedNothing =>
      _t('Hakuna jipya la kuingiza.', 'Nothing new to post.');

  // Sections.
  String get financeAccounts => _t('Akaunti', 'Accounts');
  String get financeMap => _t('Mpangilio wa kuingiza', 'Posting rules');
  String get financeMapCaption => _t('Kila tukio linaingia akaunti zipi',
      'Which accounts each event posts to');
  String get financePeriods => _t('Vipindi', 'Periods');
  String get financePeriodsCaption =>
      _t('Miezi iliyo wazi na iliyofungwa', 'Open and locked months');
  String get financeJournal => _t('Daftari', 'Journal');
  String get financeJournalCaption =>
      _t('Maingizo yote, kwa tarehe', 'Every entry, by date');
  String get financeReports => _t('Ripoti', 'Reports');
  String get financeReportsCaption => _t(
      'Mizania, matokeo ya biashara, fedha zilizopo',
      'Trial balance, operating result, cash position');

  // Events.
  String financeEventName(String event) => switch (event) {
        'sale_cash' => _t('Mauzo ya fedha taslimu', 'Cash sales'),
        'sale_credit' => _t('Mauzo ya mkopo', 'Credit sales'),
        'sale_mpesa' => _t('Mauzo ya M-Pesa', 'M-Pesa sales'),
        'cost_of_sales' =>
          _t('Gharama ya bidhaa zilizouzwa', 'Cost of goods sold'),
        'sale_correction' => _t('Masahihisho ya mauzo', 'Sale corrections'),
        'handover_confirmed' =>
          _t('Makabidhiano yaliyothibitishwa', 'Confirmed handovers'),
        'expense_office' => _t('Gharama za ofisi', 'Office expenses'),
        'expense_vendor' => _t('Gharama za muuzaji', 'Vendor-paid expenses'),
        'stock_loss' => _t('Hasara ya stoo', 'Stock losses'),
        'credit_repayment' =>
          _t('Malipo ya madeni ya wateja', 'Customer credit repayments'),
        'credit_write_off' =>
          _t('Madeni ya wateja yaliyosamehewa', 'Customer debts written off'),
        'vendor_debit' => _t('Deni la ziada la muuzaji', 'Vendor debits'),
        'vendor_credit' => _t('Punguzo la deni la muuzaji', 'Vendor credits'),
        'bonus_earned' => _t('Bonasi zilizopatikana', 'Bonuses earned'),
        'vendor_payment' => _t('Malipo kwa wauzaji', 'Vendor payments'),
        _ => event,
      };
  String financeEventCaption(String event) => switch (event) {
        'sale_cash' => _t('Mauzo yaliyothibitishwa; muuzaji ameshika fedha',
            'Verified sales; the vendor holds the cash'),
        'sale_credit' => _t('Mauzo yaliyothibitishwa; mteja anadaiwa',
            'Verified sales; the customer owes'),
        'sale_mpesa' => _t('Mauzo yaliyothibitishwa; yanasubiri kulinganishwa',
            'Verified sales; awaiting matching'),
        'cost_of_sales' => _t('Gharama ya bidhaa zilizotoka stoo kwa mauzo',
            'Cost of the stock the sales took'),
        'sale_correction' => _t(
            'Mmiliki akisahihisha mauzo, maingizo yake yanarudishwa',
            'When the owner corrects a sale, its entries are reversed'),
        'handover_confirmed' => _t(
            'Fedha alizokabidhi muuzaji, mhasibu amethibitisha',
            'Cash a vendor handed over, confirmed by finance'),
        'expense_office' =>
          _t('Gharama zilizolipwa na ofisi', 'Expenses the office paid'),
        'expense_vendor' => _t('Gharama za dharura alizolipa muuzaji',
            'Emergency expenses a vendor paid'),
        'stock_loss' => _t('Bidhaa zilizoharibika au kupotea, zimethibitishwa',
            'Verified damaged or lost stock'),
        'credit_repayment' =>
          _t('Wateja wa mkopo wakilipa deni', 'Credit customers paying back'),
        'credit_write_off' => _t('Deni la mteja ambalo biashara imeacha',
            'Customer debt the business gives up'),
        'vendor_debit' => _t('Marekebisho yanayoongeza deni la muuzaji',
            'Adjustments that add to what a vendor owes'),
        'vendor_credit' => _t('Marekebisho yanayopunguza deni la muuzaji',
            'Adjustments that reduce what a vendor owes'),
        'bonus_earned' =>
          _t('Bonasi za siku zilizofungwa', 'Bonuses of closed days'),
        'vendor_payment' => _t('Malipo yaliyorekodiwa kwa wauzaji',
            'Payments recorded to vendors'),
        _ => '',
      };

  // Posting rules.
  String get financeDebit => _t('Debiti', 'Debit');
  String get financeCredit => _t('Krediti', 'Credit');
  String get financeNotSet => _t('Haijawekwa', 'Not set');
  String financeRuleBy(String name, String when) =>
      _t('Imewekwa na $name · $when', 'Set by $name · $when');
  String get financeSaveRule => _t('Hifadhi mpangilio', 'Save rule');
  String get financeRuleSameAccount =>
      _t('Chagua akaunti mbili tofauti.', 'Choose two different accounts.');
  String get financeRuleChooseBoth =>
      _t('Chagua debiti na krediti.', 'Choose the debit and the credit.');
  String get financeRuleSaved =>
      _t('Mpangilio umehifadhiwa.', 'Posting rule saved.');
  String get financeRuleNote => _t(
      'Mabadiliko yanahusu maingizo yajayo tu; yaliyokwisha andikwa yanabaki.',
      'A change applies to later postings only; entries already written stay.');
  String get financeOwnerOnly =>
      _t('Mmiliki ndiye anayebadilisha.', 'Only the owner changes this.');
  String get financeNeedAccounts => _t(
      'Ongeza akaunti kwanza, kisha weka mpangilio.',
      'Add accounts first, then set the rules.');

  // Accounts.
  String get financeAddAccount => _t('Ongeza akaunti', 'Add an account');
  String get financeAccountCode => _t('Namba ya akaunti', 'Account code');
  String get financeAccountName => _t('Jina la akaunti', 'Account name');
  String get financeAccountKind => _t('Aina', 'Kind');
  String financeKindName(String kind) => switch (kind) {
        'asset' => _t('Mali', 'Asset'),
        'liability' => _t('Dhima', 'Liability'),
        'equity' => _t('Mtaji', 'Equity'),
        'income' => _t('Mapato', 'Income'),
        'expense' => _t('Matumizi', 'Expense'),
        _ => kind,
      };
  String get financeAccountCodeInvalid => _t(
      'Namba: herufi 1 hadi 20 (A–Z, 0–9, nukta au kistari).',
      'Code: 1 to 20 characters (A–Z, 0–9, dot or dash).');
  String get financeAccountNameInvalid =>
      _t('Jina: herufi 2 hadi 80.', 'Name: 2 to 80 characters.');
  String get financeAccountKindMissing =>
      _t('Chagua aina ya akaunti.', 'Choose the kind of account.');
  String get financeAccountSaved =>
      _t('Akaunti imehifadhiwa.', 'Account saved.');
  String financeReasonNewAccount(String code) =>
      _t('Akaunti mpya $code', 'New account $code');
  String financeReasonRename(String code) =>
      _t('Jina la akaunti $code limebadilishwa', 'Account $code renamed');
  String get financeRename => _t('Badilisha jina', 'Rename');
  String get financeDeactivate => _t('Sitisha akaunti', 'Deactivate');
  String get financeActivate => _t('Rudisha akaunti', 'Reactivate');
  String get financeInactive => _t('Imesitishwa', 'Inactive');
  String get financeDeactivateNote => _t(
      'Akaunti iliyositishwa haipokei maingizo mapya. Iliyo kwenye mpangilio haisitishwi.',
      'An inactive account takes no new entries. One used in a posting rule cannot be deactivated.');
  String get financeNoAccounts => _t(
      'Hakuna akaunti bado. Ongeza za kwanza pamoja na mhasibu.',
      'No accounts yet. Add the first ones with the accountant.');
  String financeBalance(String amount) =>
      _t('Salio $amount', 'Balance $amount');

  // Periods.
  String get financeMonthOpen => _t('Wazi', 'Open');
  String get financeMonthLocked => _t('Imefungwa', 'Locked');
  String get financeLockMonth => _t('Funga mwezi', 'Lock the month');
  String get financeLockRule => _t(
      'Miezi hufungwa kwa mpangilio; mwezi wa sasa haufungwi na uliofungwa haufunguliwi. Tukio la mwezi uliofungwa huingia mwezi wa kwanza ulio wazi.',
      'Months lock in order; the current month never locks and a locked one never reopens. An event of a locked month posts in the first open month.');
  String financeLockTitle(String month) => _t('Funga $month?', 'Lock $month?');
  String get financeLocked => _t('Mwezi umefungwa.', 'Month locked.');
  String financeLockedBy(String name, String when) =>
      _t('Imefungwa na $name · $when', 'Locked by $name · $when');
  String get financeNoPeriods => _t('Hakuna vipindi bado.', 'No periods yet.');

  // Journal.
  String get financeJournalEmpty =>
      _t('Hakuna maingizo katika kipindi hiki.', 'No entries in this period.');
  String get financeAllAccounts => _t('Akaunti zote', 'All accounts');
  String get financeRange => _t('Kipindi', 'Period');
  String financeOriginalDate(String date) =>
      _t('Tarehe ya tukio: $date', 'Event date: $date');
  String get financeReversal => _t('Ingizo la kurudisha', 'Reversing entry');
  String financeEntryBy(String name, String when) =>
      _t('Imeingizwa na $name · $when', 'Posted by $name · $when');
  String financeLineAmounts(String debit, String credit) =>
      _t('D $debit · K $credit', 'D $debit · C $credit');

  // Reports.
  String get financeTrialBalance => _t('Mizania ya majaribio', 'Trial balance');
  String get financeOperatingResult =>
      _t('Matokeo ya biashara', 'Operating result');
  String get financeCashPosition => _t('Fedha zilizopo', 'Cash position');
  String get financeIncome => _t('Mapato', 'Income');
  String get financeExpenses => _t('Matumizi', 'Expenses');
  String get financeTotalIncome => _t('Jumla ya mapato', 'Total income');
  String get financeTotalExpenses => _t('Jumla ya matumizi', 'Total expenses');
  String get financeResult => _t('Matokeo', 'Result');
  String get financeProvisional => _t('Ya muda', 'Provisional');
  String financeProvisionalNote(int n) => _t(
      'Ya muda: matukio $n bado hayajaingizwa, au gharama ya baadhi ya mauzo haijulikani.',
      'Provisional: $n events are not yet posted, or some sales have no known cost.');
  String financeTotals(String debit, String credit) => _t(
      'Jumla: debiti $debit · krediti $credit',
      'Totals: debit $debit · credit $credit');
  String financeAsOf(String date) => _t('Hadi $date', 'As of $date');
  String get financeNoRows =>
      _t('Hakuna cha kuonyesha bado.', 'Nothing to show yet.');
}
