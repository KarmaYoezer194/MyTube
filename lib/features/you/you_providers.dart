import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/video.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/repositories/video_repository.dart';

/// A video in a list, with how much of it you watched (0..1), if known.
class ListedVideo {
  const ListedVideo(this.video, {this.progress});

  final Video video;

  /// Shows the red bar under the thumbnail (history only).
  final double? progress;
}

/// Combines a list of video ids (e.g. from Watch later) with the live list
/// of all videos, keeping the order of the ids. Videos that were deleted
/// are skipped. Loading / error states are passed through.
AsyncValue<List<ListedVideo>> _joinWithVideos(
  Ref ref,
  AsyncValue<List<String>> ids, {
  Map<String, double>? progressById,
}) {
  final videos = ref.watch(allVideosProvider);
  if (ids.hasError) return AsyncError(ids.error!, ids.stackTrace!);
  if (videos.hasError) return AsyncError(videos.error!, videos.stackTrace!);

  final idList = ids.value;
  final all = videos.value;
  if (idList == null || all == null) return const AsyncLoading();

  final byId = {for (final v in all) v.id: v};
  return AsyncData([
    for (final id in idList)
      if (byId[id] case final video?)
        ListedVideo(video, progress: progressById?[id]),
  ]);
}

/// History, newest first, with a progress bar for each video.
final historyVideosProvider = Provider<AsyncValue<List<ListedVideo>>>((ref) {
  final entries = ref.watch(historyEntriesProvider);
  final videos = ref.watch(allVideosProvider).value ?? const <Video>[];
  final lengths = {for (final v in videos) v.id: v.durationSeconds};

  final progress = <String, double>{
    for (final e in entries.value ?? const <HistoryEntry>[])
      e.videoId: (lengths[e.videoId] ?? 0) > 0
          ? (e.positionSeconds / lengths[e.videoId]!).clamp(0.0, 1.0)
          : 0.0,
  };
  return _joinWithVideos(
    ref,
    entries.whenData((list) => [for (final e in list) e.videoId]),
    progressById: progress,
  );
});

final likedVideosProvider = Provider<AsyncValue<List<ListedVideo>>>(
  (ref) => _joinWithVideos(ref, ref.watch(likedVideoIdsProvider)),
);

final watchLaterVideosProvider = Provider<AsyncValue<List<ListedVideo>>>(
  (ref) => _joinWithVideos(ref, ref.watch(watchLaterIdsProvider)),
);

/// Videos I uploaded, newest first, INCLUDING unlisted ones.
final myVideosProvider = Provider<AsyncValue<List<ListedVideo>>>((ref) {
  final uid = ref.watch(currentUidProvider);
  return ref
      .watch(allVideosProvider)
      .whenData(
        (videos) => [
          for (final v in videos)
            if (v.uploaderUid == uid) ListedVideo(v),
        ],
      );
});
