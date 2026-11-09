/// Mr. Nyama's business day is the calendar day in Africa/Dar_es_Salaam
/// (UTC+3 all year, no daylight saving), whatever the phone's own time zone.
const _eat = Duration(hours: 3);

/// The business date of [moment], as a UTC midnight value (date only).
DateTime businessDate(DateTime moment) {
  final local = moment.toUtc().add(_eat);
  return DateTime.utc(local.year, local.month, local.day);
}

/// The instants where business date [day] starts and ends (end exclusive).
(DateTime, DateTime) businessDayRange(DateTime day) {
  final start = DateTime.utc(day.year, day.month, day.day).subtract(_eat);
  return (start, start.add(const Duration(days: 1)));
}

/// [moment] as East Africa Time wall-clock values, for display.
DateTime eatClock(DateTime moment) {
  final t = moment.toUtc().add(_eat);
  return DateTime(t.year, t.month, t.day, t.hour, t.minute, t.second);
}

/// Business date of [moment] as `yyyy-mm-dd`.
String businessDateKey(DateTime moment) {
  final d = businessDate(moment);
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
