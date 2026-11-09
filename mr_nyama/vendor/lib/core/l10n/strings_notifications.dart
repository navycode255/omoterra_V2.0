part of 'strings.dart';

/// Notifications and "Ujumbe wa ofisi", step 13A (owner decisions
/// 30 October 2026). The notifications' own titles and lines come from the
/// server in the reader's language. Same rules as `Strings`: `_t(sw, en)`.
extension NotificationStrings on Strings {
  String get notificationsTitle => ownerNotifications;
  String get notificationsNew => _t('Arifa mpya', 'New notifications');
  String get notificationsEmpty =>
      _t('Hakuna arifa bado.', 'No notifications yet.');
  String get notificationsEmptyHelp => _t(
      'Mzigo, maamuzi ya ofisi na ujumbe vitaonekana hapa.',
      'Deliveries, office decisions and messages appear here.');
  String get notificationsMarkAll => _t('Soma zote', 'Mark all read');
  String get notificationsMore => _t('Onyesha zaidi', 'Show more');
  String get notificationsUnreadMark => _t('Mpya', 'New');
  String notificationTime(DateTime at, DateTime now) {
    final hm =
        '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
    final today =
        at.year == now.year && at.month == now.month && at.day == now.day;
    return today ? hm : '${dayMonth(at)} · $hm';
  }

  String get messageNew => _t('Tuma ujumbe', 'Send a message');
  String get messageTo => _t('Kwa', 'To');
  String get messageToStation => _t('Kituo kizima', 'A whole station');
  String get messageToVendor => _t('Muuzaji mmoja', 'One vendor');
  String get messageStation => _t('Kituo', 'Station');
  String get messageVendor => _t('Muuzaji', 'Vendor');
  String get messageBody => _t('Ujumbe', 'Message');
  String get messageHint => _t('Andika ujumbe mfupi (hadi herufi 500).',
      'Write a short message (up to 500 characters).');
  String get messageSend => _t('Tuma', 'Send');
  String messageSent(int n) => n == 1
      ? _t('Ujumbe umemfikia muuzaji 1.', 'Message sent to 1 vendor.')
      : _t('Ujumbe umewafikia wauzaji $n.', 'Message sent to $n vendors.');
  String get messageNobody => _t(
      'Ujumbe umehifadhiwa, lakini hakuna muuzaji kwenye kituo hiki sasa.',
      'Message saved, but no vendor works at this station now.');
  String get messageNotYourStation => _t(
      'Unaweza kutuma ujumbe kwa wauzaji wa vituo vyako tu.',
      'You can only message vendors of your own stations.');
  String get messagesSent => _t('Ujumbe uliotumwa', 'Sent messages');
  String messageRecipients(int n) => _t(
      n == 1 ? 'Muuzaji 1' : 'Wauzaji $n', n == 1 ? '1 vendor' : '$n vendors');
}
