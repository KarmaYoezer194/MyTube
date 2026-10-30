import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:mytube/core/theme/app_theme.dart';
import 'package:mytube/core/utils/cloudinary_urls.dart';
import 'package:mytube/core/utils/durations.dart';
import 'package:mytube/core/utils/format_views.dart';
import 'package:mytube/core/utils/time_ago.dart';
import 'package:mytube/core/widgets/category_chip.dart';
import 'package:mytube/core/widgets/empty_state.dart';
import 'package:mytube/core/widgets/network_thumbnail.dart';
import 'package:mytube/data/models/video.dart';
import 'package:mytube/data/repositories/user_repository.dart';
import 'package:mytube/data/repositories/video_lookup.dart';
import 'package:mytube/features/discovery/hidden_content.dart';
import 'package:mytube/features/home/widgets/recommended_shelf.dart';
import 'package:mytube/features/you/you_providers.dart';

const _cdn = 'https://res.cloudinary.com/hcrar4ku';

Video _video(String id) => Video(
  id: id,
  title: id,
  description: '',
  videoUrl: '',
  thumbnailUrl: '',
  durationSeconds: 0,
  channelId: 'c',
  channelName: 'C',
  channelAvatarUrl: '',
  subscriberCount: 0,
  views: 0,
  likes: 0,
  category: 'Other',
  isShort: false,
  uploaderUid: 'u',
  createdAt: DateTime(2026),
);

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.dark(),
  home: Scaffold(body: child),
);

void main() {
  group('smaller Cloudinary thumbnails', () {
    test('a video frame is shrunk AFTER the frame is picked', () {
      expect(
        sizedThumbnailUrl(
          '$_cdn/video/upload/so_60,w_640/mytube/seed/a.jpg',
          320,
        ),
        '$_cdn/video/upload/so_60,w_640/c_limit,w_320,q_auto/mytube/seed/a.jpg',
      );
    });

    test('pictures also get f_auto, before the version', () {
      expect(
        sizedThumbnailUrl('$_cdn/image/upload/v17/cover.png', 480),
        '$_cdn/image/upload/c_limit,w_480,q_auto,f_auto/v17/cover.png',
      );
    });

    test('other links and already sized links stay the same', () {
      const other = 'https://example.com/a.jpg';
      expect(sizedThumbnailUrl(other, 320), other);
      final once = sizedThumbnailUrl('$_cdn/image/upload/a.png', 160);
      expect(sizedThumbnailUrl(once, 160), once);
    });

    test('sizes are rounded up to a few fixed widths', () {
      expect(thumbnailBucket(100), 160);
      expect(thumbnailBucket(161), 320);
      expect(thumbnailBucket(720), 720);
      expect(thumbnailBucket(5000), 1080);
    });

    test('uploaded videos play as a phone-sized MP4', () {
      expect(
        playableVideoUrl('$_cdn/video/upload/v1/clip.mov'),
        '$_cdn/video/upload/c_limit,w_1280,h_1280/v1/clip.mp4',
      );
      expect(
        playableVideoUrl('https://example.com/a.mp4'),
        'https://example.com/a.mp4',
      );
    });
  });

  group('looking videos up by id', () {
    test('keys', () {
      expect(idsKeyOf(['a', 'b']), 'a,b');
      expect(idsFromKey('a,b'), ['a', 'b']);
      expect(idsFromKey(''), isEmpty);
    });

    test('keeps the order of the ids and skips missing ones', () {
      final byId = {'a': _video('a'), 'c': _video('c')};
      expect(videosInOrder(['c', 'b', 'a'], byId).map((v) => v.id), ['c', 'a']);
    });

    test('watched share', () {
      expect(watchedShare(30, 120), 0.25);
      expect(watchedShare(500, 120), 1.0);
      expect(watchedShare(30, 0), 0.0);
    });
  });

  test(
    'history saving a new position does not rebuild recommendations',
    () async {
      final history = StreamController<List<HistoryEntry>>();
      addTearDown(history.close);
      final container = ProviderContainer(
        overrides: [
          historyEntriesProvider.overrideWith((ref) => history.stream),
        ],
      );
      addTearDown(container.dispose);

      final keys = <String>[];
      container.listen(
        watchedIdsKeyProvider,
        (_, key) => keys.add(key),
        fireImmediately: true,
      );
      HistoryEntry entry(String id, int position) => HistoryEntry(
        videoId: id,
        positionSeconds: position,
        watchedAt: DateTime(2026),
      );

      history.add([entry('a', 10)]);
      await pumpEventQueue();
      history.add([entry('a', 20)]); // same video, new position
      await pumpEventQueue();
      history.add([entry('b', 0), entry('a', 20)]); // a new video
      await pumpEventQueue();

      expect(keys, ['', 'a', 'a,b']);
    },
  );

  group('formatting', () {
    test('compact numbers cut off like YouTube', () {
      expect(formatCompactCount(950), '950');
      expect(formatCompactCount(1000), '1K');
      expect(formatCompactCount(1290000), '1.2M');
      expect(formatCompactCount(12500), '12K');
      expect(formatCompactCount(3000000000), '3B');
    });

    test('views and subscribers', () {
      expect(formatViews(1), '1 view');
      expect(formatViews(1500), '1.5K views');
      expect(formatSubscribers(1), '1 subscriber');
    });

    test('time ago', () {
      final now = DateTime(2026, 10, 30, 12);
      expect(
        timeAgo(now.subtract(const Duration(seconds: 5)), now: now),
        'just now',
      );
      expect(
        timeAgo(now.subtract(const Duration(minutes: 1)), now: now),
        '1 minute ago',
      );
      expect(
        timeAgo(now.subtract(const Duration(days: 3)), now: now),
        '3 days ago',
      );
      expect(
        timeAgo(now.subtract(const Duration(days: 400)), now: now),
        '1 year ago',
      );
    });

    test('durations', () {
      expect(formatDuration(const Duration(seconds: 75)), '1:15');
      expect(formatDuration(const Duration(hours: 1, seconds: 5)), '1:00:05');
    });
  });

  group('shared widgets', () {
    testWidgets('EmptyState shows its text and action', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(
          EmptyState(
            icon: Symbols.search_off,
            title: 'No results',
            message: 'Try again',
            actionLabel: 'Retry',
            onAction: () => taps++,
          ),
        ),
      );
      expect(find.text('No results'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      expect(taps, 1);
    });

    testWidgets('CategoryChip calls back when tapped', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(
          CategoryChip(label: 'Cars', selected: false, onTap: () => taps++),
        ),
      );
      await tester.tap(find.text('Cars'));
      expect(taps, 1);
    });

    testWidgets('Recommended cards never overflow, even with long titles', (
      tester,
    ) async {
      final long = Video(
        id: 'x',
        title:
            'A very long title that needs two lines and then some more '
            'words so it would wrap even further',
        description: '',
        videoUrl: '',
        thumbnailUrl: '',
        durationSeconds: 888,
        channelId: 'c',
        channelName: 'A channel with a long name as well',
        channelAvatarUrl: '',
        subscriberCount: 0,
        views: 0,
        likes: 0,
        category: 'Other',
        isShort: false,
        uploaderUid: 'u',
        createdAt: DateTime(2026),
      );
      await tester.pumpWidget(
        ProviderScope(
          child: _wrap(
            SingleChildScrollView(
              child: RecommendedShelf(videos: [long, long]),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Recommended for you'), findsOneWidget);
    });

    testWidgets('a thumbnail without a link shows the play icon', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const SizedBox(
            width: 160,
            height: 90,
            child: NetworkThumbnail(url: ''),
          ),
        ),
      );
      expect(find.byIcon(Symbols.play_circle), findsOneWidget);
    });
  });
}
