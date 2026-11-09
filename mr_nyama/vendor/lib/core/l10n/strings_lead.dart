part of 'strings.dart';

/// Outlet Lead (team roles plan, lane A): the "Kituo" section on Nyumbani.
/// Same rules as `Strings`: Swahili first, `_t(sw, en)`. REVIEW: a Swahili
/// speaker must check it.
extension LeadStrings on Strings {
  String get leadSection => _t('Kituo', 'Station');
  String get leadHandovers =>
      _t('Pokea fedha ya muuzaji', 'Receive seller cash');
  String get leadDeliveries => _t('Pokea mzigo', 'Receive goods');
  String get leadStationStock => _t('Stoo ya kituo', 'Station stock');
  String get leadExpenses => _t('Matumizi', 'Expenses');
  String get leadDamage => _t('Uharibifu wa kuhakiki', 'Damage to verify');
  String get leadClosings => _t('Hesabu za kufunga', 'Closing counts');

  // Owner makes or ends a lead (seller page, office mode).
  String get makeLead => _t('Mfanye Kiongozi wa Kituo', 'Make Outlet Lead');
  String get endLead => _t('Ondoa ukiongozi', 'End leadership');
  String get leadRole => _t('Kiongozi wa Kituo', 'Outlet Lead');
  String get makeLeadHelp => _t(
      'Atafungua ofisi ya kituo chake kwa PIN ileile ya muuzaji.',
      'They will open their station office with the same seller PIN.');
  String get endLeadHelp => _t(
      'Atabaki muuzaji; ofisi ya kituo itafungwa kwake.',
      'They stay a seller; the station office closes for them.');
  String get ownRecordRefused => _t(
      'Huwezi kuhakiki rekodi zako mwenyewe',
      'You cannot verify your own records');
  String leadRefusal(String code) => switch (code) {
        'no_station' => _t('Mpe kituo kwanza', 'Give a station first'),
        'already_lead' =>
          _t('Tayari ni Kiongozi wa Kituo', 'Already an Outlet Lead'),
        'staff_has_role' => _t(
            'Mtu huyu ana kazi nyingine ofisini',
            'This person already holds another office role'),
        'station_has_supervisor' => _t(
            'Kituo hiki tayari kina msimamizi',
            'This station already has a supervisor'),
        'vendor_not_active' => _t(
            'Akaunti ya muuzaji haifanyi kazi', 'The seller account is not active'),
        'own_account' => _t('Huwezi kujiteua mwenyewe', 'You cannot appoint yourself'),
        'staff_unavailable' => _t(
            'Akaunti ya ofisi ya mtu huyu haipatikani',
            'This person\'s office account is not available'),
        'client_id_used' => _t('Ombi hili limetumika kwa muuzaji mwingine',
            'This request was already used for another seller'),
        _ => errorBody,
      };
}
