part of 'strings.dart';

/// Checks around office-entered sales and back-dated stock (final review of the
/// operations controls, 1 November 2026). Same rules as `Strings`: Swahili
/// first, `_t(sw, en)`.
extension EntryCheckStrings on Strings {
  String lostSaleAge(int days) => switch (days) {
        <= 0 => _t('Imeombwa leo', 'Asked today'),
        1 => _t('Imeombwa jana', 'Asked yesterday'),
        _ => _t('Imeombwa siku $days zilizopita', 'Asked $days days ago'),
      };
  String get lostSaleCancelled =>
      _t('Mauzo yamefutwa baada ya kukubaliwa', 'Sale cancelled after approval');
  String get lostSaleMissedDayWarning => _t(
      'Siku hii itaonekana kama siku bila hesabu.',
      'This day will show as a day without a count.');
  String get lostSaleAskerCannotVerify => _t(
      'Uliomba mauzo haya mwenyewe; mtu mwingine ayathibitishe.',
      'You asked for this sale yourself; someone else must verify it.');
  String get oversoldBackdatedLine => _t(
      'Mauzo haya ni ya siku ya nyuma. Stoo iliyopo sasa iliingia baadaye, kwa hiyo haihesabiwi kwa siku hiyo. Si lazima kuwa yaliuzwa zaidi ya stoo; kagua kwanza.',
      'This sale is of an earlier day. The stock there now arrived later, so it does not count for that day. It may not be selling beyond stock; check first.');
  String get duplicateEntryLine => _t(
      'Simu imetuma mauzo kwa siku ambayo ofisi tayari iliingiza mauzo ya muuzaji huyu. Linganisha yote mawili kabla ya kuthibitisha; yakiwa yale yale, moja lifutwe.',
      'A phone sent a sale for a day on which the office already entered a sale for this vendor. Compare the two before verifying; if they are the same, cancel one.');
}
