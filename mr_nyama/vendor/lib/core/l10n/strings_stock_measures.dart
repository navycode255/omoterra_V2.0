part of 'strings.dart';

/// One meaning for every stock figure (operations-controls plan, Task 5). The
/// office Stoo page and the manual use these words; the vendor keeps a single
/// figure, "Imesalia". Same rules as `Strings`: Swahili first, `_t(sw, en)`.
extension StockMeasureStrings on Strings {
  String get measuresHeading => _t('Kwenye stoo sasa', 'In stock now');
  String get measureBook => _t('Stoo ya vitabuni', 'Stock in the books');
  String get measurePendingSales =>
      _t('Mauzo yanayosubiri', 'Sales waiting for verification');
  String get measurePendingDamage =>
      _t('Uharibifu unaosubiri', 'Damage waiting for a decision');
  String get measureHeldSales =>
      _t('Mauzo yaliyoshikiliwa', 'Sales held for review');
  String get measureEstimate => _t('Makadirio ya stoo', 'Stock estimate');
  String get measureCounted => _t('Hesabu halisi', 'Counted');
  String get measureVariance => _t('Tofauti', 'Difference');
  String get measureGap => _t('Tofauti isiyoingizwa', 'Difference not posted');
  String get measuresHelpTitle =>
      _t('Maana ya takwimu za stoo', 'What the stock figures mean');
  String get measuresHelp => _t(
      '$measureEstimate: kinachobaki kwenye stoo baada ya kukata vipande '
          'vinavyohitajika (sawa na "Imesalia" ya muuzaji), si chini ya sifuri. '
          'Ni hesabu ya mwisho pamoja na mienendo iliyofuata, ukitoa mauzo na '
          'uharibifu vinavyosubiri vilivyofanyika baada ya hesabu hiyo.\n\n'
          '$measureBook: stoo iliyorekodiwa kwenye vitabu rasmi.\n\n'
          '$measurePendingSales: yameuzwa na kutumwa, bado hayajathibitishwa.\n\n'
          '$measurePendingDamage: yameripotiwa, bado hayajaamuliwa.\n\n'
          '$measureHeldSales: yameuzwa, lakini seva imeshikilia rekodi ili '
          'ikaguliwe. Hayatolewi kwenye makadirio.\n\n'
          '$measureCounted: kilichohesabiwa kwa macho mara ya mwisho.\n\n'
          '$measureVariance: hesabu halisi ukitoa kilichotarajiwa, wakati wa '
          'uthibitisho wa mwisho.\n\n'
          '$measureGap: makadirio na yanayosubiri ukitoa vitabuni. Si sifuri '
          'ikiwa hesabu inatofautiana na vitabu na hakuna aliyeiingiza.',
      '$measureEstimate: what lies at the station once the needed cuts are '
          'made (the vendor\'s "Imesalia"), never below zero. It is the last '
          'count plus the movements since, less sales and damage waiting that '
          'came after that count.\n\n'
          '$measureBook: stock recorded in the official books.\n\n'
          '$measurePendingSales: sold and sent, not yet verified.\n\n'
          '$measurePendingDamage: reported, not yet decided.\n\n'
          '$measureHeldSales: sold, but the server holds the record for '
          'review. They are not taken off the estimate.\n\n'
          '$measureCounted: what was physically counted last.\n\n'
          '$measureVariance: counted minus expected, at the last '
          'confirmation.\n\n'
          '$measureGap: the estimate plus what is waiting, minus the books. '
          'Not zero when a count differs from the books and nothing has '
          'posted it.');
}
