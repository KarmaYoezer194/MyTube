import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/video.dart';
import '../../data/repositories/video_repository.dart';

/// "Up next" list for a video: same category first, then everything else
/// (both newest first). Shorts and unlisted videos are left out.
final upNextProvider = Provider.family<List<Video>, String>((ref, videoId) {
  final videos = ref.watch(allVideosProvider).value ?? const <Video>[];
  final current = videos.where((v) => v.id == videoId).firstOrNull;

  final candidates = videos
      .where((v) => v.id != videoId && !v.isShort && !v.isUnlisted)
      .toList();
  if (current == null) return candidates;

  final sameCategory =
      candidates.where((v) => v.category == current.category);
  final others = candidates.where((v) => v.category != current.category);
  return [...sameCategory, ...others];
});
