import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/video.dart';
import 'user_repository.dart';
import 'video_repository.dart';

/// Videos for a list of ids ([idsKey] = the ids joined with commas, so the
/// same list always gives the same provider): taken from the catalog
/// (already loaded, no reads) and, for older videos, fetched once by id.
///
/// Used by History, Liked videos, Watch later, playlists and the play
/// queue, which can hold videos of any age.
final videoLookupProvider = FutureProvider.autoDispose
    .family<Map<String, Video>, String>((ref, idsKey) async {
      final ids = idsFromKey(idsKey);
      if (ids.isEmpty) return const {};
      final catalog = await ref.watch(allVideosProvider.future);
      final found = {for (final video in catalog) video.id: video};
      final missing = [
        for (final id in ids)
          if (!found.containsKey(id)) id,
      ];
      if (missing.isNotEmpty) {
        found.addAll(
          await ref.read(videoRepositoryProvider).getVideosByIds(missing),
        );
      }
      return {for (final id in ids) id: ?found[id]};
    });

/// "a,b,c" for a list of ids (the key of [videoLookupProvider]).
String idsKeyOf(Iterable<String> ids) => ids.join(',');

List<String> idsFromKey(String key) => key.isEmpty ? const [] : key.split(',');

/// [ids] turned into videos, in the same order; missing ones are skipped.
List<Video> videosInOrder(Iterable<String> ids, Map<String, Video> byId) => [
  for (final id in ids) ?byId[id],
];

/// My uploads (unlisted too), live. Empty for guests.
final myUploadsProvider = StreamProvider<List<Video>>((ref) {
  if (!ref.watch(isSignedInProvider)) return Stream.value(const []);
  return ref
      .watch(videoRepositoryProvider)
      .watchUploadsBy(ref.watch(currentUidProvider));
});
