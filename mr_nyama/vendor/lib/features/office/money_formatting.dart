import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/l10n/strings.dart';
import '../../core/api/office_repository.dart';
import '../../core/theme/theme.dart';

/// Returns the localized vendor-day status and its semantic status color.
(String, Color)? moneyStateWord(Strings strings, OfficeMoneyDay day) {
  final short =
      day.remaining > 0 ? day.remaining : day.cashDue - day.handedOver;
  final over =
      day.remaining < 0 ? -day.remaining : day.handedOver - day.cashDue;
  return switch (day.state) {
    MoneyDayState.nothingDue => (strings.moneyNothingDue, OwnerStyle.muted),
    MoneyDayState.notHanded => (strings.moneyNotHanded, MNColors.warning),
    MoneyDayState.short => (
        strings.moneyShort(formatTsh(math.max(0, short))),
        MNColors.error
      ),
    MoneyDayState.full => (strings.moneyFull, MNColors.success),
    MoneyDayState.over => (
        strings.moneyOver(formatTsh(math.max(0, over))),
        MNColors.warning
      ),
    null => null,
  };
}
