import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/office_repository.dart';
import '../../core/auth/office_session.dart';
import '../../core/auth/session.dart' show clockProvider;
import '../../core/business_day.dart';

/// Nullable until the matching financial/operational API is implemented
/// (null shows a dash).
/// Reference figures are supplied by test overrides only.
class OwnerOverview {
  final int? sales, supervisorFunds, openStations;
  final int? totalStations;
  final double? changePercent, supervisorFundsChangePercent;
  const OwnerOverview(
      {this.sales,
      this.supervisorFunds,
      this.openStations,
      this.totalStations,
      this.changePercent,
      this.supervisorFundsChangePercent});
}

/// The business date Muhtasari and the money report show; null is today.
/// Kept while the owner moves between tabs.
final ownerDayProvider = StateProvider<DateTime?>((ref) => null);

/// `yyyy-mm-dd` of a date-only value.
String ownerDayKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// `ownerDayKey` of the chosen day, or null for today.
String? _chosenKey(Ref ref) {
  final day = ref.watch(ownerDayProvider);
  return day == null ? null : ownerDayKey(day);
}

/// Ties a kept answer to the signed-in account: signing out, or in as
/// someone else, drops everything kept for the previous account.
void watchOfficeAccount(Ref ref) =>
    ref.watch(officeSessionProvider.select((auth) => switch (auth.valueOrNull) {
          OfficeSignedIn(:final profile) => profile.id,
          _ => null,
        }));

/// One business day's Muhtasari figures (null: today), fetched once and
/// kept: choosing a day already seen shows it at once, without asking the
/// server again. Pull-to-refresh refreshes that day. A failed fetch is not
/// kept, so the next visit tries again.
final ownerDayFiguresProvider =
    FutureProvider.autoDispose.family<OwnerOverview, String?>((ref, day) async {
  watchOfficeAccount(ref);
  final session = ref.read(officeSessionProvider.notifier);
  final stations = await session.guard((r) => r.stations());
  // The day's recorded sales (voided ones left out) and the day before's,
  // for the change; a server without that report leaves dashes.
  Future<OwnerMoneyOverview?> sales(String? date) async {
    try {
      return await session.guard((r) async => r is OwnerReportsRepository
          ? await (r as OwnerReportsRepository)
              .moneyOverview(OwnerPeriod.day, date: date)
          : null);
    } on OfficeError {
      return null;
    }
  }

  final money = await sales(day);
  final isToday = day == null ||
      day == ownerDayKey(businessDate(ref.read(clockProvider)()));
  final shown = money?.from ?? (day == null ? null : DateTime.parse(day));
  final before = shown == null
      ? null
      : await sales(ownerDayKey(shown.subtract(const Duration(days: 1))));
  final now = money?.totals.sales, then = before?.totals.sales;
  ref.keepAlive();
  // Station registration is not proof a station has opened for the day, so
  // the open count comes from the server's day records.
  return OwnerOverview(
      sales: now,
      changePercent: now == null || then == null || then == 0
          ? null
          : (now - then) * 100 / then,
      openStations: money?.openStations,
      // The server's figure; never counted on the phone.
      // It is the cash with supervisors now, so a past day shows a dash.
      supervisorFunds: isToday ? money?.withSupervisor : null,
      totalStations: stations.length);
});

/// The chosen day's figures as Muhtasari shows them. Synchronous over the
/// kept answers, so a day already seen is data at once (no loading frame).
final ownerOverviewProvider = Provider.autoDispose<AsyncValue<OwnerOverview>>(
    (ref) => ref.watch(ownerDayFiguresProvider(_chosenKey(ref))));

/// Refreshes the chosen day's figures from the server (pull-to-refresh).
Future<void> refreshOwnerDay(WidgetRef ref) {
  final day = ref.read(ownerDayProvider);
  return ref.refresh(
      ownerDayFiguresProvider(day == null ? null : ownerDayKey(day)).future);
}

typedef OwnerMoneyKey = ({OwnerPeriod period, String? day});

/// The owner's money report for one period around a day (null: today),
/// kept per period and day like [ownerDayFiguresProvider].
final ownerMoneyOverviewProvider = FutureProvider.autoDispose
    .family<OwnerMoneyOverview, OwnerMoneyKey>((ref, key) async {
  watchOfficeAccount(ref);
  final report = await ref.read(officeSessionProvider.notifier).guard((r) =>
      (r as OwnerReportsRepository).moneyOverview(key.period, date: key.day));
  ref.keepAlive();
  return report;
});

/// The report's key for [period] around the day chosen on Muhtasari.
OwnerMoneyKey ownerMoneyKey(WidgetRef ref, OwnerPeriod period) {
  final day = ref.watch(ownerDayProvider);
  return (period: period, day: day == null ? null : ownerDayKey(day));
}
