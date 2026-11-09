part of 'strings.dart';

/// Missed-closing cases (MN031): the office explains a day nobody counted.
/// Same rules as `Strings`: Swahili first, `_t(sw, en)`. A case is
/// information; it never says a day was counted.
extension ClosingCaseStrings on Strings {
  String get closingCasesTitle => _t('Siku zisizofungwa', 'Days not closed');
  String get closingCasesEmpty =>
      _t('Hakuna siku isiyofungwa.', 'No days left unclosed.');
  String closingCasesRowCount(int n) =>
      _t('Siku $n bila hesabu', '$n days without a count');
  String closingCaseVendors(String names) =>
      _t('Wauzaji: $names', 'Vendors: $names');

  String closingCaseOutcome(String outcome) => switch (outcome) {
        'estimate' => _t('Makadirio', 'Estimate'),
        'not_counted' => _t('Haikuhesabiwa', 'Not counted'),
        _ => outcome,
      };
  String get closingCaseEstimateLabel =>
      _t('Makadirio, si hesabu halisi', 'An estimate, not a real count');
  String closingCaseState(String status) => switch (status) {
        'open' => _t('Inasubiri uamuzi', 'Waiting for a decision'),
        'approved' => _t('Imekubaliwa', 'Approved'),
        'rejected' => _t('Imekataliwa', 'Refused'),
        'withdrawn' => _t('Imeondolewa', 'Withdrawn'),
        _ => status,
      };
  String get closingCaseNone => _t('Hakuna kesi bado', 'No case yet');

  String get closingCaseOpen => _t('Fungua kesi', 'Open a case');
  String get closingCaseKind => _t('Aina ya kesi', 'Kind of case');
  String get closingCaseBasis => _t('Umekagua nini?', 'What did you check?');
  String get closingCaseEstimates =>
      _t('Makadirio ya bidhaa', 'Estimated products');
  String get closingCaseAddProduct => _t('Ongeza bidhaa', 'Add a product');
  String get closingCaseConfirmTitle =>
      _t('Thibitisha kesi', 'Confirm the case');
  String get closingCaseConfirmEstimate => _t(
      'Makadirio haya hayabadilishi stoo wala hesabu ya siku. Ni maelezo tu.',
      "This estimate does not change stock or the day's count. It is information only.");
  String get closingCaseConfirmNotCounted => _t(
      'Siku hii itaandikwa kuwa haikuhesabiwa. Haibadilishi stoo.',
      'This day will be recorded as not counted. It does not change stock.');
  String get closingCaseSend => _t('Tuma kesi', 'Send the case');
  String get closingCaseSent => _t('Kesi imetumwa.', 'Case sent.');
  String get closingCaseFormInvalid => _t(
      'Andika ulichokagua (angalau herufi 10), na makadirio ya angalau bidhaa moja.',
      'Write what you checked (at least 10 characters) and at least one estimated product.');

  String closingCaseOpenedBy(String name) =>
      _t('Imefunguliwa na $name', 'Opened by $name');
  String closingCaseDecidedBy(String name) =>
      _t('Imeamuliwa na $name', 'Decided by $name');
  String get closingCaseOwnWaiting => _t(
      'Kesi hii inasubiri uamuzi wa fedha au mmiliki. Huwezi kuiamua mwenyewe.',
      'This case waits for finance or the owner. You cannot decide it yourself.');
  String get closingCaseHistory => _t('Historia', 'History');
  String closingCaseBlockedTitle(String sales, String damage) {
    final parts = [
      if (sales.isNotEmpty) sales,
      if (damage.isNotEmpty) damage,
    ];
    return _t('Haiwezi kukubaliwa bado: ${parts.join(', ')}.',
        'Cannot be approved yet: ${parts.join(', ')}.');
  }

  String closingCaseBlockedSales(int n) =>
      _t('mauzo $n hayajathibitishwa', '$n sales not verified');
  String closingCaseBlockedDamage(int n) =>
      _t('uharibifu $n haujaamuliwa', '$n damage reports not decided');
}
