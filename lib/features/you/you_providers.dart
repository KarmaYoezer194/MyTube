import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/video.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/repositories/video_lookup.dart';

/// A video in a list, with how much of it you watched (0..1), if known.
class ListedVideo {
  const ListedVideo(this.video, {this.progress, this.watchedAt});

  final Video video;

  /// Shows the red bar under the thumbnail (history only).
  final double? progress;

  /// When it was last watched (history only).
  final DateTime? watchedAt;
}

/// Turns a list of video ids (e.g. from Watch later) into videos, keeping
/// the order of the ids. Videos come from the catalog, or are looked up by
/// id if they are older (see videoLookupProvider). Deleted videos are
/// skipped. Loading / error states are passed through.
AsyncValue<List<ListedVideo>> _joinWithVideos(
  Ref ref,
  AsyncValue<List<String>> ids, {
  List<ListedVideo> Function(List<String> ids, Map<String, Video> byId)? build,
}) {
  if (ids.hasError) return AsyncError(ids.error!, ids.stackTrace!);
  final idList = ids.value;
  if (idList == null) return const AsyncLoading();

  final lookup = ref.watch(videoLookupProvider(idsKeyOf(idList)));
  if (lookup.hasError && !lookup.hasValue) {
    return AsyncError(lookup.error!, lookup.stackTrace!);
  }
  final byId = lookup.value;
  if (byId == null) return const AsyncLoading();
  return AsyncData(
    build?.call(idList, byId) ??
        [for (final video in videosInOrder(idList, byId)) ListedVideo(video)],
  );
}

/// History, newest first, with a progress bar for each video.
final historyVideosProvider = Provider<AsyncValue<List<ListedVideo>>>((ref) {
  final entries = ref.watch(historyEntriesProvider);
  final byVideo = {
    for (final e in entries.value ?? const <HistoryEntry>[]) e.videoId: e,
  };
  return _joinWithVideos(
    ref,
    entries.whenData((list) => [for (final e in list) e.videoId]),
    build: (ids, videosById) => [
      for (final video in videosInOrder(ids, videosById))
        ListedVideo(
          video,
          progress: watchedShare(
            byVideo[video.id]?.positionSeconds ?? 0,
            video.durationSeconds,
          ),
          watchedAt: byVideo[video.id]?.watchedAt,
        ),
    ],
  );
});

/// How much of a video was watched (0..1); 0 if its length is unknown.
double watchedShare(int positionSeconds, int durationSeconds) =>
    durationSeconds > 0
    ? (positionSeconds / durationSeconds).clamp(0.0, 1.0)
    : 0.0;

final likedVideosProvider = Provider<AsyncValue<List<ListedVideo>>>(
  (ref) => _joinWithVideos(ref, ref.watch(likedVideoIdsProvider)),
);

final watchLaterVideosProvider = Provider<AsyncValue<List<ListedVideo>>>(
  (ref) => _joinWithVideos(ref, ref.watch(watchLaterIdsProvider)),
);

/// Videos I uploaded, newest first, INCLUDING unlisted ones (their own
/// query, so old uploads are never missing).
final myVideosProvider = Provider<AsyncValue<List<ListedVideo>>>(
  (ref) => ref
      .watch(myUploadsProvider)
      .whenData((videos) => [for (final v in videos) ListedVideo(v)]),
);
