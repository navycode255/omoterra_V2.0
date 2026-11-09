part of 'strings.dart';

/// Unsent records (operations controls plan). Records not yet sent exist
/// only on this phone; this copy says so plainly. Same rules as `Strings`:
/// Swahili first, `_t(sw, en)`. REVIEW: a Swahili speaker must check it.
extension UnsentStrings on Strings {
  /// A wait as a short span: minutes under an hour, hours under a day, then
  /// whole days.
  String unsentSpan(Duration d) {
    if (d.inMinutes < 1) return _t('chini ya dakika 1', 'under 1 minute');
    if (d.inHours < 1) {
      return _t('dakika ${d.inMinutes}', '${d.inMinutes} min');
    }
    if (d.inDays < 1) return _t('saa ${d.inHours}', '${d.inHours} h');
    return _t('siku ${d.inDays}', '${d.inDays} days');
  }

  String unsentWaited(Duration d) => _t(
      'Kumbukumbu ya zamani zaidi imesubiri ${unsentSpan(d)}',
      'The oldest record has waited ${unsentSpan(d)}');
  String get unsentConsequence => _t(
      'Kumbukumbu hizi zipo kwenye simu hii tu. Simu ikipotea, zinapotea.',
      'These records are only on this phone. If the phone is lost, they are lost.');
  String unsentSince(String date) =>
      _t('Kumbukumbu hazijatumwa tangu $date', 'Records not sent since $date');

  /// Msaada: short numbered guidance (docs/mr_nyama/operations).
  List<String> get helpSteps => [
        _t('1. Unganisha simu kwenye intaneti angalau mara moja kila siku.',
            '1. Connect the phone to the internet at least once every day.'),
        _t('2. Angalia alama ya usawazishaji juu ya Nyumbani. Kabla ya kufunga siku, hakikisha kumbukumbu zimeondoka kwenye simu.',
            '2. Check the sync mark at the top of Nyumbani. Before closing the day, make sure the records have left the phone.'),
        _t('3. Kabla ya kubadilisha, kurudisha, kutengeneza au kufuta data za simu, au kuondoa programu: fungua Usawazishaji, unganisha intaneti, na subiri uone "$allSent". Usiondoe programu kwanza.',
            '3. Before changing, returning, repairing or resetting a phone, or removing the app: open Sync, connect to the internet, and wait for "$allSent". Never remove the app first.'),
        _t('4. Simu ikipotea, ikiibwa au ikiharibika: mwambie msimamizi wako mara moja. Zinazopotea ni kumbukumbu ambazo hazikutumwa tu; zilizotumwa ni salama.',
            '4. If the phone is lost, stolen or broken: tell your supervisor at once. Only records that were not sent are lost; sent records are safe.'),
        _t('5. Kwenye simu mpya, ingia kwa msimbo atakaokupa msimamizi. Historia ya siku 31 zilizopita itarudi yenyewe.',
            '5. On a new phone, sign in with the code your supervisor gives you. The last 31 days of history come back by themselves.'),
        _t('Kwa msaada zaidi, wasiliana na msimamizi wako wa kituo.',
            'For more help, contact your station supervisor.'),
      ];
}
