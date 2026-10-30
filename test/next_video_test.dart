import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytube/data/models/video.dart';
import 'package:mytube/data/repositories/video_repository.dart';
import 'package:mytube/features/discovery/hidden_content.dart';
import 'package:mytube/features/discovery/recommendations.dart';
import 'package:mytube/features/mini_player/player_panel_provider.dart';
import 'package:mytube/features/playlists/play_queue.dart';

Video _video(String id, {String channelId = 'c1', String category = 'Cars'}) =>
    Video(
      id: id,
      title: id,
      description: '',
      videoUrl: '',
      thumbnailUrl: '',
      durationSeconds: 60,
      channelId: channelId,
      channelName: channelId,
      channelAvatarUrl: '',
      subscriberCount: 0,
      views: 100,
      likes: 0,
      category: category,
      isShort: false,
      uploaderUid: 'u',
      createdAt: DateTime(2026),
    );

void main() {
  test('pressing ⏭ again and again plays every video once, then '
      'starts over (no A-B-A loop)', () async {
    // Like the sample videos: a and b are each other's best match (same
    // channel + category), so the old code bounced between them.
    final videos = [
      _video('a', channelId: 'blender', category: 'Animation'),
      _video('b', channelId: 'blender', category: 'Animation'),
      _video('c', channelId: 'cars'),
      _video('d', channelId: 'cars'),
      _video('e', channelId: 'trips', category: 'Entertainment'),
    ];
    final container = ProviderContainer(
      overrides: [
        allVideosProvider.overrideWith((ref) => Stream.value(videos)),
        tasteProfileProvider.overrideWithValue(const TasteProfile()),
      ],
    );
    addTearDown(container.dispose);
    container.listen(allVideosProvider, (_, _) {});
    await container.read(allVideosProvider.future);

    final panel = container.read(playerPanelProvider.notifier);
    panel.open('a');
    final played = ['a'];
    for (var i = 0; i < 4; i++) {
      final current = container.read(playerPanelProvider).videoId!;
      final next = container.read(nextVideoProvider(current));
      expect(next, isNotNull);
      panel.switchTo(next!.id);
      played.add(next.id);
    }
    // All 5 videos, each exactly once.
    expect(played.toSet(), {'a', 'b', 'c', 'd', 'e'});
    expect(played.length, 5);

    // Everything played: ⏭ still works (starts over).
    final current = container.read(playerPanelProvider).videoId!;
    expect(container.read(nextVideoProvider(current)), isNotNull);
  });

  test('closing the player starts a fresh round', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final panel = container.read(playerPanelProvider.notifier);
    panel.open('a');
    panel.switchTo('b');
    expect(container.read(playerPanelProvider).previousIds, ['a']);
    panel.close();
    panel.open('c');
    expect(container.read(playerPanelProvider).previousIds, isEmpty);
  });
}
