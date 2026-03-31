import 'package:intl/intl.dart';

class EasternTimeUtils {
  EasternTimeUtils._();

  static DateTime toEastern(DateTime value) {
    final utc = value.toUtc();
    final offset = _isDaylightSavingTime(utc) ? -4 : -5;
    return utc.add(Duration(hours: offset));
  }

  static String format(DateTime? value, {String pattern = 'yyyy-MM-dd HH:mm'}) {
    if (value == null) {
      return '--';
    }
    return DateFormat(pattern).format(toEastern(value));
  }

  static bool _isDaylightSavingTime(DateTime utc) {
    final year = utc.year;
    final dstStartDay = _nthWeekdayOfMonth(year, 3, DateTime.sunday, 2);
    final dstEndDay = _nthWeekdayOfMonth(year, 11, DateTime.sunday, 1);
    final dstStartUtc = DateTime.utc(year, 3, dstStartDay, 7);
    final dstEndUtc = DateTime.utc(year, 11, dstEndDay, 6);
    return !utc.isBefore(dstStartUtc) && utc.isBefore(dstEndUtc);
  }

  static int _nthWeekdayOfMonth(
    int year,
    int month,
    int weekday,
    int occurrence,
  ) {
    final firstDay = DateTime.utc(year, month, 1);
    final delta = (weekday - firstDay.weekday + 7) % 7;
    return 1 + delta + (occurrence - 1) * 7;
  }
}
