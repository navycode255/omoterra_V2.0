part of 'strings.dart';

/// Picking a phone number from the phone's contacts (owner request,
/// 7 November 2026). Same rules as `Strings`: Swahili first, `_t(sw, en)`.
/// REVIEW: a Swahili speaker must check it.
extension ContactStrings on Strings {
  String get contactsPick => _t('Chagua kwenye anwani', 'Pick from contacts');
  String get contactsTitle => _t('Anwani za simu', 'Phone contacts');
  String get contactsSearch => _t('Tafuta jina au namba', 'Search name or number');
  String get contactsEmpty => _t(
      'Hakuna namba ya simu ya Tanzania kwenye anwani zako.',
      'No Tanzanian mobile number in your contacts.');
  String get contactsNoMatch =>
      _t('Hakuna anwani inayolingana.', 'No contact matches.');
  String get contactsDenied => _t(
      'Simu haikuruhusu kusoma anwani. Andika namba mwenyewe.',
      'The phone did not allow reading contacts. Type the number instead.');
  String get contactsFailed => _t(
      'Anwani hazikusomeka. Andika namba mwenyewe.',
      'Contacts could not be read. Type the number instead.');
  String contactsMore(int n) => _t(
      'Anwani $n zaidi. Andika jina kupunguza.',
      '$n more contacts. Type a name to narrow the list.');
}
