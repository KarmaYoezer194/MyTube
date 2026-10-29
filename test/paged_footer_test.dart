import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytube/core/theme/app_theme.dart';
import 'package:mytube/core/widgets/paged_footer.dart';
import 'package:mytube/data/models/video.dart';
import 'package:mytube/data/repositories/paged_videos.dart';

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
  testWidgets('shows Retry after an error', (tester) async {
    var retried = 0;
    await tester.pumpWidget(
      _wrap(
        PagedFooter(
          page: PagedVideos(items: [_video('a')], error: Exception('x')),
          onRetry: () => retried++,
        ),
      ),
    );
    expect(find.text("Couldn't load more videos."), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(retried, 1);
  });

  testWidgets('shows a spinner while the next page loads', (tester) async {
    await tester.pumpWidget(
      _wrap(
        PagedFooter(
          page: PagedVideos(items: [_video('a')], isLoading: true),
          onRetry: () {},
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows nothing when idle', (tester) async {
    await tester.pumpWidget(
      _wrap(
        PagedFooter(
          page: PagedVideos(items: [_video('a')], hasMore: false),
          onRetry: () {},
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Retry'), findsNothing);
  });

  test('PagedVideos flags', () {
    expect(const PagedVideos(isLoading: true).isFirstLoad, isTrue);
    expect(const PagedVideos(hasMore: false).isEmpty, isTrue);
    expect(PagedVideos(items: [_video('a')], hasMore: false).isEmpty, isFalse);
  });
}
