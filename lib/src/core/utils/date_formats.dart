import 'package:intl/intl.dart';

/// Formats a UTC [dateTime] in the user's locale (e.g. "Oct 9, 2026, 5:30 PM").
String formatDateTime(DateTime dateTime, String locale) {
  final DateFormat format = DateFormat.yMMMd(locale).add_jm();
  return format.format(dateTime.toLocal());
}
