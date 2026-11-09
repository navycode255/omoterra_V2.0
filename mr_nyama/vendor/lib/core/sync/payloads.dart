/// Builds each operation's JSON body exactly as the server contract expects
/// (backend `vendor_events.py`: SalePayload, VoidRequest, VendorReceipt,
/// DamageReport, ClosingCount). Times are sent in UTC with an offset.
library;

String _time(DateTime t) => t.toUtc().toIso8601String();

Map<String, dynamic> salePayload({
  required String clientId,
  required DateTime recordedAt,
  required String paymentMethod,
  String? customerId,
  required List<
          ({
            String productId,
            int quantity,
            int unitPrice,
            String? priceVersion,
            bool exceeds
          })>
      lines,
}) =>
    {
      'client_id': clientId,
      'recorded_at': _time(recordedAt),
      'payment_method': paymentMethod,
      if (customerId != null) 'customer_id': customerId,
      'lines': [
        for (final l in lines)
          {
            'product_key': l.productId,
            'quantity': l.quantity,
            'unit_price': l.unitPrice,
            'price_version': l.priceVersion,
            'exceeds_recorded_stock': l.exceeds,
          }
      ],
    };

Map<String, dynamic> voidPayload(
        {required String voidId,
        required String saleClientId,
        required String reason,
        String? note,
        required DateTime requestedAt}) =>
    {
      'void_id': voidId,
      'sale_client_id': saleClientId,
      'reason': reason,
      'requested_at': _time(requestedAt),
      if (note != null) 'note': note,
    };

Map<String, dynamic> receiptPayload({
  required String eventId,
  required String receiptId,
  required String consignmentId,
  required int consignmentVersion,
  required DateTime receivedAt,
  Map<String, String> notes = const {},
  required List<({String lineId, int accepted, int rejected, String? reason})>
      lines,
}) =>
    {
      'event_id': eventId,
      'receipt_id': receiptId,
      'consignment_id': consignmentId,
      'consignment_version': consignmentVersion,
      'received_at': _time(receivedAt),
      'lines': [
        for (final l in lines)
          {
            'line_id': l.lineId,
            'accepted': l.accepted,
            'rejected': l.rejected,
            'reason': l.reason,
            if (notes[l.lineId] != null) 'note': notes[l.lineId],
          }
      ],
    };

Map<String, dynamic> damagePayload(
        {required String reportId,
        required String productId,
        required int quantity,
        required String reason,
        String? note,
        required DateTime reportedAt}) =>
    {
      'report_id': reportId,
      'product_key': productId,
      'quantity': quantity,
      'reason': reason,
      'note': note,
      'reported_at': _time(reportedAt),
    };

Map<String, dynamic> closingPayload(
        {required String countId,
        required String businessDate,
        required DateTime countedAt,
        required Map<String, int> counted,
        Map<String, String> reasons = const {},
        Map<String, String> notes = const {}}) =>
    {
      'count_id': countId,
      'business_date': businessDate,
      'counted_at': _time(countedAt),
      'lines': [
        for (final e in counted.entries)
          {
            'product_key': e.key,
            'counted': e.value,
            if (reasons[e.key] != null) 'reason': reasons[e.key],
            if (notes[e.key] != null) 'note': notes[e.key]
          }
      ],
    };
