import 'package:intl/intl.dart';

import '../../data/models/video.dart';

/// The heading of one day on the History page: "Today", "Yesterday",
/// "Monday" (this week), "Oct 12" (this year) or "Oct 12, 2025".
String historyDayLabel(DateTime date, DateTime now) {
  final day = DateTime(date.year, date.month, date.day);
  final today = DateTime(now.year, now.month, now.day);
  final daysAgo = today.difference(day).inDays;
  if (daysAgo <= 0) return 'Today';
  if (daysAgo == 1) return 'Yesterday';
  if (daysAgo < 7) return DateFormat.EEEE().format(date);
  if (date.year == now.year) return DateFormat.MMMd().format(date);
  return DateFormat.yMMMd().format(date);
}

/// One day of history.
typedef HistoryDay<T> = ({String label, List<T> items});

/// Splits [items] (newest first) into days, keeping their order.
List<HistoryDay<T>> groupByDay<T>(
  List<T> items,
  DateTime Function(T item) dateOf,
  DateTime now,
) {
  final days = <HistoryDay<T>>[];
  for (final item in items) {
    final label = historyDayLabel(dateOf(item), now);
    if (days.isNotEmpty && days.last.label == label) {
      days.last.items.add(item);
    } else {
      days.add((label: label, items: [item]));
    }
  }
  return days;
}

/// "Search watch history": every word must appear in the title or the
/// channel name (upper / lower case doesn't matter).
bool matchesHistorySearch(Video video, String query) {
  final words = query.toLowerCase().split(RegExp(r'\s+'))
    ..removeWhere((word) => word.isEmpty);
  final text = '${video.title} ${video.channelName}'.toLowerCase();
  return words.every(text.contains);
}
