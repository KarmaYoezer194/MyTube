/// "just now", "5 minutes ago", "3 days ago", "2 weeks ago", "1 year ago".
///
/// Written by hand (instead of the timeago package) because YouTube says
/// "1 month ago" where timeago says "about a month ago".
String timeAgo(DateTime date, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(date);

  // Also covers small negative differences (clocks slightly out of sync).
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return _ago(diff.inMinutes, 'minute');
  if (diff.inHours < 24) return _ago(diff.inHours, 'hour');
  if (diff.inDays < 7) return _ago(diff.inDays, 'day');
  if (diff.inDays < 30) return _ago(diff.inDays ~/ 7, 'week');
  if (diff.inDays < 365) return _ago(diff.inDays ~/ 30, 'month');
  return _ago(diff.inDays ~/ 365, 'year');
}

String _ago(int amount, String unit) =>
    '$amount $unit${amount == 1 ? '' : 's'} ago';
