import 'package:intl/intl.dart';

extension DateHelpers on DateTime {
  /// ISO 8601 with the device's UTC offset, e.g. 2026-10-26T10:30:00+05:30
  String toApiString() {
    final local = toLocal();
    final offset = local.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final hours = offset.inHours.abs().toString().padLeft(2, '0');
    final minutes = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
    return '${DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(local)}$sign$hours:$minutes';
  }

  bool isSameDayAs(DateTime other) {
    final a = toLocal();
    final b = other.toLocal();
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool get isToday => isSameDayAs(DateTime.now());

  String get timeLabel => DateFormat('hh:mm a').format(toLocal());

  String get dateLabel => DateFormat('dd MMM yyyy').format(toLocal());

  String get dateTimeLabel {
    final local = toLocal();
    if (local.isToday) return 'Today, $timeLabel';
    return DateFormat('dd MMM, hh:mm a').format(local);
  }
}

DateTime? parseApiDate(dynamic value) {
  if (value == null) return null;
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value * 1000);
  return DateTime.tryParse(value.toString())?.toLocal();
}
