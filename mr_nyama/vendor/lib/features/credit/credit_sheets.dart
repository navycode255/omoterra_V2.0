import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/l10n/strings.dart';
import '../../shared/widgets/select_field.dart';
import 'credit_store.dart';

/// One line about a customer's credit: what they owe and their limit, or
/// why they cannot take credit.
String creditCaption(Strings s, CreditCustomer c) {
  if (c.suspended) return s.creditSuspended;
  if (c.creditLimit == null) return s.creditNoLimit;
  final owes = c.owed > 0 ? s.creditOwes(formatTsh(c.owed)) : s.creditNoneOwed;
  return '$owes · ${s.creditLimitOf(formatTsh(c.creditLimit!))}';
}

/// The station's credit customers to choose from (the app's own sheet).
/// Customers credit is not allowed for are shown, greyed, with the reason.
Future<CreditCustomer?> showCreditCustomerSheet(
    BuildContext context, WidgetRef ref, List<CreditCustomer> customers,
    {String? selectedId}) async {
  final s = ref.read(stringsProvider);
  final picked = await showMNSelectSheet<String>(context,
      title: s.creditChooseCustomer,
      selected: selectedId,
      emptyText: s.creditNoCustomers,
      options: [
        for (final c in customers)
          MNSelectOption(
              value: c.id,
              label: c.name,
              caption: creditCaption(s, c),
              enabled: c.creditAllowed),
      ]);
  if (picked == null) return null;
  return customers.where((c) => c.id == picked.value).firstOrNull;
}
