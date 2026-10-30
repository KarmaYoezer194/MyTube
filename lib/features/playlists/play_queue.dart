import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/video.dart';
import '../../data/repositories/video_lookup.dart';
import '../mini_player/player_panel_provider.dart';
import '../watch/watch_providers.dart';

/// The playlist being played with "Play all" or "Shuffle".
///
/// While the video on screen is part of it, ⏭ and autoplay go to the next
/// video of the playlist (instead of "Up next"), and the watch page shows
/// the playlist panel.
@immutable
class PlayQueue {
  const PlayQueue({
    required this.playlistId,
    required this.title,
    required this.videoIds,
    this.shuffled = false,
  });

  final String playlistId;
  final String title;

  /// In playing order (already shuffled for Shuffle).
  final List<String> videoIds;
  final bool shuffled;

  bool contains(String videoId) => videoIds.contains(videoId);
  int indexOf(String videoId) => videoIds.indexOf(videoId);
}

/// The id after [current] in [ids], or null at the end (or if [current]
/// isn't in the list).
String? nextInQueue(List<String> ids, String current) {
  final index = ids.indexOf(current);
  if (index < 0 || index + 1 >= ids.length) return null;
  return ids[index + 1];
}

/// [ids] in a random order, with [first] (if given) moved to the front.
List<String> shuffledIds(List<String> ids, {String? first, Random? random}) {
  final result = [...ids]..shuffle(random ?? Random());
  if (first != null && result.remove(first)) result.insert(0, first);
  return result;
}

class PlayQueueController extends Notifier<PlayQueue?> {
  @override
  PlayQueue? build() {
    // Closing the player ends the playlist.
    ref.listen(playerPanelProvider, (previous, next) {
      if (!next.isOpen) state = null;
    });
    return null;
  }

  void start(PlayQueue queue) => state = queue;

  void clear() => state = null;
}

final playQueueProvider = NotifierProvider<PlayQueueController, PlayQueue?>(
  PlayQueueController.new,
);

/// Plays a playlist: [videos] in order (or shuffled), starting at
/// [startId] or the first video. Shorts are skipped (they play in the
/// Shorts tab). Returns false if there is nothing to play.
bool playPlaylist(
  WidgetRef ref, {
  required String playlistId,
  required String title,
  required List<Video> videos,
  String? startId,
  bool shuffle = false,
}) {
  final playable = [
    for (final video in videos)
      if (!video.isShort) video.id,
  ];
  if (playable.isEmpty) return false;
  final ids = shuffle ? shuffledIds(playable, first: startId) : playable;
  final first = startId != null && ids.contains(startId) ? startId : ids.first;
  ref
      .read(playQueueProvider.notifier)
      .start(
        PlayQueue(
          playlistId: playlistId,
          title: title,
          videoIds: ids,
          shuffled: shuffle,
        ),
      );
  ref.read(playerPanelProvider.notifier).open(first);
  return true;
}

/// What ⏭ and autoplay play after [videoId]: the next video of the
/// playlist being played (null at its end), otherwise the first "Up next".
final nextVideoProvider = Provider.family<Video?, String>((ref, videoId) {
  final queue = ref.watch(playQueueProvider);
  if (queue != null && queue.contains(videoId)) {
    final byId =
        ref.watch(videoLookupProvider(idsKeyOf(queue.videoIds))).value ??
        const <String, Video>{};
    // Skip videos that were deleted since the playlist started.
    var nextId = nextInQueue(queue.videoIds, videoId);
    while (nextId != null) {
      if (byId[nextId] case final video?) return video;
      nextId = nextInQueue(queue.videoIds, nextId);
    }
    return null;
  }
  return ref.watch(upNextProvider(videoId)).firstOrNull;
});
