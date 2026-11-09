part of 'strings.dart';

extension FinanceWorkspaceStrings on Strings {
  String get financeTasks => _t('Kazi', 'Tasks');
  String get financePaymentsTab => _t('Malipo', 'Payments');
  String get financeBooksTab => _t('Vitabu', 'Books');
  String get financeRecordCompletedPayment => _t(
      'Rekodi malipo yaliyotekelezwa nje ya programu',
      'Record payments completed outside the app');
  String get financeOpeningDraftsCaption =>
      _t('Rasimu za stoo ya mwanzo', 'Opening-stock drafts');
  String get financeCashShortUnavailable => _t(
      'Mapitio ya tofauti za fedha hayapatikani kwa sasa.',
      'Cash-difference review is not available yet.');
  String get financeTaskCountsUnavailable => _t(
      'Baadhi ya idadi haikuweza kupakiwa. Vuta chini kujaribu tena.',
      'Some task counts could not be loaded. Pull down to retry.');
  String get financeSyncUnavailable => _t(
      'Hali ya usawazishaji wa fedha za ofisi haipatikani. Vitendo vya fedha hutumwa moja kwa moja na seva.',
      'Office finance actions do not have an offline sync queue; the server must confirm each action.');
  String get financeLoginSecurity =>
      _t('Kuingia na usalama', 'Login & security');
  String get financeAbout => _t('Kuhusu', 'About');
  String get financeAboutBody =>
      _t('MR. NYAMA\nMOTO WAKE HAUZIMI!!', 'MR. NYAMA\nMOTO WAKE HAUZIMI!!');
  String get financeBrand => 'MR. NYAMA';
}
