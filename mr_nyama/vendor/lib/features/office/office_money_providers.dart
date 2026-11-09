import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/office_repository.dart';
import '../../core/auth/office_session.dart';

typedef MoneyDayKey = ({String station, String date});
typedef VendorDayKey = ({String station, String date, String vendor});

final moneyDaysProvider = FutureProvider.autoDispose
    .family<List<OfficeMoneyDay>, MoneyDayKey>((ref, key) => ref
        .read(officeSessionProvider.notifier)
        .guard((repository) => repository.moneyDays(
            stationId: key.station, businessDate: key.date)));

/// Every expense at a station on one business day, any status.
final moneyExpensesProvider = FutureProvider.autoDispose
    .family<List<OfficeExpense>, MoneyDayKey>((ref, key) => ref
        .read(officeSessionProvider.notifier)
        .guard((repository) => repository.expenses(
            stationId: key.station, from: key.date, to: key.date)));

final vendorHandoversProvider = FutureProvider.autoDispose
    .family<List<OfficeHandover>, VendorDayKey>((ref, key) => ref
        .read(officeSessionProvider.notifier)
        .guard((repository) => repository.handovers(
            stationId: key.station,
            vendorId: key.vendor,
            from: key.date,
            to: key.date)));

final moneySettingsProvider = FutureProvider.autoDispose<OfficeMoneySettings>(
    (ref) => ref
        .read(officeSessionProvider.notifier)
        .guard((repository) => repository.moneySettings()));
