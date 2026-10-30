import 'package:flutter_test/flutter_test.dart';
import 'package:mytube/data/models/video.dart';
import 'package:mytube/features/you/history_groups.dart';

Video _video(String title, String channel) => Video(
  id: title,
  title: title,
  description: '',
  videoUrl: '',
  thumbnailUrl: '',
  durationSeconds: 0,
  channelId: 'c',
  channelName: channel,
  channelAvatarUrl: '',
  subscriberCount: 0,
  views: 0,
  likes: 0,
  category: 'Other',
  isShort: false,
  uploaderUid: 'u',
  createdAt: DateTime(2026),
);

void main() {
  // Thursday 29 October 2026, 10:00.
  final now = DateTime(2026, 10, 29, 10);

  group('historyDayLabel', () {
    test('today and yesterday', () {
      expect(historyDayLabel(DateTime(2026, 10, 29, 0, 5), now), 'Today');
      expect(historyDayLabel(DateTime(2026, 10, 28, 23, 59), now), 'Yesterday');
    });

    test('this week: the day name', () {
      expect(historyDayLabel(DateTime(2026, 10, 26), now), 'Monday');
      expect(historyDayLabel(DateTime(2026, 10, 23), now), 'Friday');
    });

    test('older: the date', () {
      expect(historyDayLabel(DateTime(2026, 10, 12), now), 'Oct 12');
      expect(historyDayLabel(DateTime(2025, 3, 4), now), 'Mar 4, 2025');
    });

    test('a slightly future time (clock skew) counts as today', () {
      expect(historyDayLabel(DateTime(2026, 10, 29, 11), now), 'Today');
    });
  });

  test('groupByDay keeps the order and joins the same day', () {
    final items = [
      DateTime(2026, 10, 29, 9),
      DateTime(2026, 10, 29, 8),
      DateTime(2026, 10, 28, 20),
      DateTime(2026, 10, 12),
    ];
    final days = groupByDay(items, (d) => d, now);
    expect(days.map((d) => d.label), ['Today', 'Yesterday', 'Oct 12']);
    expect(days.first.items.length, 2);
  });

  group('matchesHistorySearch', () {
    final video = _video('Big Buck Bunny', 'Blender Foundation');

    test('matches title and channel, any case', () {
      expect(matchesHistorySearch(video, 'bunny'), isTrue);
      expect(matchesHistorySearch(video, 'BLENDER'), isTrue);
    });

    test('every word must match', () {
      expect(matchesHistorySearch(video, 'buck blender'), isTrue);
      expect(matchesHistorySearch(video, 'buck sintel'), isFalse);
    });

    test('empty search matches everything', () {
      expect(matchesHistorySearch(video, '   '), isTrue);
    });
  });
}
