import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:mytube/core/theme/app_theme.dart';
import 'package:mytube/data/models/video.dart';
import 'package:mytube/features/studio/delete_video.dart';
import 'package:mytube/features/studio/studio_stats.dart';
import 'package:mytube/features/studio/widgets/stat_tile.dart';

Video _video(
  String id, {
  int views = 0,
  int likes = 0,
  int? comments,
  bool isShort = false,
  DateTime? createdAt,
  String videoUrl = '',
  String thumbnailUrl = '',
}) => Video(
  id: id,
  title: id,
  description: '',
  videoUrl: videoUrl,
  thumbnailUrl: thumbnailUrl,
  durationSeconds: 0,
  channelId: 'c',
  channelName: 'C',
  channelAvatarUrl: '',
  subscriberCount: 0,
  views: views,
  likes: likes,
  category: 'Other',
  isShort: isShort,
  uploaderUid: 'u',
  createdAt: createdAt ?? DateTime(2026, 10, 1),
  commentCount: comments,
);

void main() {
  final a = _video('a', views: 100, likes: 10, comments: 4);
  final b = _video('b', views: 300, likes: 5, isShort: true);
  final c = _video('c', views: 50, likes: 20, comments: 1);

  test('channel totals', () {
    final stats = channelStatsOf([a, b, c]);
    expect(stats.videoCount, 2);
    expect(stats.shortCount, 1);
    expect(stats.uploads, 3);
    expect(stats.views, 450);
    expect(stats.likes, 35);
    expect(stats.comments, 5); // b has no counter yet: counts as 0
    expect(stats.topVideo?.id, 'b');
  });

  test('no uploads: zeros and no top video', () {
    final stats = channelStatsOf(const []);
    expect(stats.views, 0);
    expect(stats.topVideo, isNull);
  });

  test('like rate and views per day', () {
    expect(likeRate(a), 0.1);
    expect(likeRate(_video('x')), isNull);
    final now = DateTime(2026, 10, 11);
    expect(viewsPerDay(a, now), 10); // 100 views over 10 days
    // Younger than a day counts as one day.
    expect(viewsPerDay(a, DateTime(2026, 10, 1, 6)), 100);
  });

  test('rank and share', () {
    expect(viewsRank([a, b, c], b), 1);
    expect(viewsRank([a, b, c], a), 2);
    expect(viewsRank([a, b, c], c), 3);
    expect(shareOf(50, 200), 0.25);
    expect(shareOf(5, 0), 0);
  });

  test('formatPercent', () {
    expect(formatPercent(null), '-');
    expect(formatPercent(0), '0%');
    expect(formatPercent(0.0004), '<0.1%');
    expect(formatPercent(0.05), '5%');
    expect(formatPercent(0.0525), '5.3%');
    expect(formatPercent(0.4), '40%');
    expect(formatPercent(1), '100%');
  });

  group('studioList', () {
    final old = _video('old', views: 5, createdAt: DateTime(2026, 1, 1));
    final mid = _video(
      'mid',
      views: 50,
      likes: 1,
      createdAt: DateTime(2026, 5, 1),
    );
    final short = _video(
      'short',
      views: 9,
      likes: 7,
      isShort: true,
      createdAt: DateTime(2026, 9, 1),
    );
    final all = [old, mid, short];

    test('newest first', () {
      expect(
        studioList(all, StudioFilter.all, StudioSort.newest).map((v) => v.id),
        ['short', 'mid', 'old'],
      );
    });
    test('most viewed / most liked', () {
      expect(
        studioList(all, StudioFilter.all, StudioSort.mostViewed).first.id,
        'mid',
      );
      expect(
        studioList(all, StudioFilter.all, StudioSort.mostLiked).first.id,
        'short',
      );
    });
    test('filters', () {
      expect(
        studioList(
          all,
          StudioFilter.shorts,
          StudioSort.newest,
        ).map((v) => v.id),
        ['short'],
      );
      expect(studioList(all, StudioFilter.videos, StudioSort.newest).length, 2);
    });
  });

  group('cloudinaryPublicId', () {
    test('plain upload link', () {
      expect(
        cloudinaryPublicId(
          'https://res.cloudinary.com/hcrar4ku/video/upload/v1730000000/abc123.mp4',
        ),
        'abc123',
      );
    });
    test('with size settings, folder, and the app\'s playable link', () {
      expect(
        cloudinaryPublicId(
          'https://res.cloudinary.com/hcrar4ku/video/upload/c_limit,w_1280,h_1280/mytube/abc123.mp4',
        ),
        'mytube/abc123',
      );
      expect(
        cloudinaryPublicId(
          'https://res.cloudinary.com/hcrar4ku/video/upload/so_1,w_640/abc123.jpg',
        ),
        'abc123',
      );
    });
    test('not a Cloudinary link', () {
      expect(cloudinaryPublicId('https://example.com/a.mp4'), isNull);
      expect(cloudinaryPublicId(''), isNull);
    });
  });

  test('files to delete by hand: video + its own thumbnail picture', () {
    final made = _video(
      'v',
      videoUrl: 'https://res.cloudinary.com/hcrar4ku/video/upload/v1/clip.mp4',
      thumbnailUrl:
          'https://res.cloudinary.com/hcrar4ku/video/upload/so_1,w_640/clip.jpg',
    );
    expect(cloudinaryFilesOf(made), ['clip']);

    final custom = _video(
      'v',
      videoUrl: 'https://res.cloudinary.com/hcrar4ku/video/upload/v1/clip.mp4',
      thumbnailUrl:
          'https://res.cloudinary.com/hcrar4ku/image/upload/v2/cover.png',
    );
    expect(cloudinaryFilesOf(custom), ['clip', 'cover']);
  });

  testWidgets('StatTile shows the value and label', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const Scaffold(
          body: StatTile(
            icon: Symbols.visibility,
            value: '1.2K',
            label: 'Views',
          ),
        ),
      ),
    );
    expect(find.text('1.2K'), findsOneWidget);
    expect(find.text('Views'), findsOneWidget);
  });
}
