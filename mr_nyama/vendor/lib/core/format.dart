import 'package:intl/intl.dart';

final _grouped = NumberFormat('#,##0', 'en');

/// Whole shillings with thousands separators: `245000` → `245,000`.
/// Formatting only; amounts always come from authoritative product
/// configuration and server totals, never from constants in the app.
String groupDigits(int value) => _grouped.format(value);

/// `TSh 245,000`, as in the approved designs.
String formatTsh(int shillings) => 'TSh ${groupDigits(shillings)}';

/// `TZS 245,000`, as in the approved Kikapu reference (22 October 2026).
String formatTzs(int shillings) => 'TZS ${groupDigits(shillings)}';
