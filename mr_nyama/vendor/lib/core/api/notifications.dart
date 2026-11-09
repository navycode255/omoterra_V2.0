/// Notifications, step 13A (MN025, owner decisions 30 October 2026,
/// docs/mr_nyama/implementation/notifications-plan.md). The server writes
/// each notification's title and line in the reader's language; the app
/// lists them, marks them read and opens the screen they are about.
class AppNotification {
  final String id, kind, title, body, target;
  final String? sourceId;
  final DateTime createdAt;
  final bool read;
  const AppNotification(
      {required this.id,
      required this.kind,
      required this.title,
      required this.body,
      required this.target,
      required this.createdAt,
      required this.read,
      this.sourceId});

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
      id: j['id'] as String,
      kind: j['kind'] as String,
      title: j['title'] as String? ?? '',
      body: j['body'] as String? ?? '',
      target: j['target'] as String? ?? 'home',
      sourceId: j['source_id'] as String?,
      createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
      read: j['read'] as bool? ?? false);

  AppNotification markedRead() => AppNotification(
      id: id,
      kind: kind,
      title: title,
      body: body,
      target: target,
      sourceId: sourceId,
      createdAt: createdAt,
      read: true);
}

class NotificationPage {
  final List<AppNotification> items;
  final int unread;
  final bool more;
  const NotificationPage(
      {required this.items, required this.unread, this.more = false});
  static const empty = NotificationPage(items: [], unread: 0);

  factory NotificationPage.fromJson(Map<String, dynamic> j) => NotificationPage(
          items: [
            for (final item in j['items'] as List? ?? const [])
              AppNotification.fromJson(Map<String, dynamic>.from(item as Map))
          ],
          unread: (j['unread'] as num?)?.toInt() ?? 0,
          more: j['more'] as bool? ?? false);
}

/// "Ujumbe wa ofisi" as sent.
class OfficeMessage {
  final String id, body, station, vendor, sentBy;
  final int recipients;
  final DateTime createdAt;
  const OfficeMessage(
      {required this.id,
      required this.body,
      required this.station,
      required this.vendor,
      required this.sentBy,
      required this.recipients,
      required this.createdAt});

  factory OfficeMessage.fromJson(Map<String, dynamic> j) => OfficeMessage(
      id: j['id'] as String,
      body: j['body'] as String? ?? '',
      station: j['station'] as String? ?? '',
      vendor: j['vendor'] as String? ?? '',
      sentBy: j['sent_by'] as String? ?? '',
      recipients: (j['recipients'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(j['created_at'] as String).toLocal());
}

abstract interface class VendorNotificationsRepository {
  Future<NotificationPage> notifications(String token,
      {required String lang, String? before});

  /// Marks [ids] read, or every notification when null.
  Future<int> markNotificationsRead(String token, List<String>? ids);
}

abstract interface class OfficeNotificationsRepository {
  Future<NotificationPage> notifications(
      {required String lang, String? before});
  Future<int> markNotificationsRead(List<String>? ids);

  /// One message to a vendor or a whole station; [clientId] makes a retry
  /// send it once.
  Future<OfficeMessage> sendMessage(
      {required String clientId,
      required String body,
      String? stationId,
      String? vendorId});
  Future<List<OfficeMessage>> sentMessages();
}
