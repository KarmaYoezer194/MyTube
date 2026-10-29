/// Short numbers like YouTube: 950, 1.2K, 12K, 1.2M, 3B.
///
/// YouTube cuts off extra digits instead of rounding up
/// (1,290,000 -> "1.2M", not "1.3M"), so we do the same.
String formatCompactCount(int n) {
  if (n < 1000) return '$n';
  if (n < 1000000) return _compact(n / 1000, 'K');
  if (n < 1000000000) return _compact(n / 1000000, 'M');
  return _compact(n / 1000000000, 'B');
}

String _compact(double value, String suffix) {
  // 10 and above: no decimals ("12K"). Below 10: one decimal ("1.2K").
  if (value >= 10) return '${value.floor()}$suffix';
  final oneDecimal = (value * 10).floor() / 10;
  final text = oneDecimal == oneDecimal.roundToDouble()
      ? oneDecimal.toInt().toString() // "1K" instead of "1.0K"
      : oneDecimal.toStringAsFixed(1);
  return '$text$suffix';
}

/// "1 view", "1.2M views"
String formatViews(int n) =>
    n == 1 ? '1 view' : '${formatCompactCount(n)} views';

/// "1 subscriber", "286K subscribers"
String formatSubscribers(int n) =>
    n == 1 ? '1 subscriber' : '${formatCompactCount(n)} subscribers';
