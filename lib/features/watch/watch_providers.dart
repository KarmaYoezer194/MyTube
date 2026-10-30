import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/video.dart';
import '../../data/repositories/video_repository.dart';
import '../discovery/hidden_content.dart';
import '../discovery/recommendations.dart';

/// "Up next" for a video: the best matches for it and for my taste (same
/// channel / category, channels I subscribe to, categories I watch a lot,
/// not watched yet, popular). Shorts, unlisted and hidden videos are left
/// out. See discovery/recommendations.dart for the score.
final upNextProvider = Provider.family<List<Video>, String>((ref, videoId) {
  final videos = ref.watch(allVideosProvider).value ?? const <Video>[];
  final current = videos.where((v) => v.id == videoId).firstOrNull;
  return recommend(
    videos,
    ref.watch(tasteProfileProvider),
    current: current,
  ).where((v) => v.id != videoId).toList();
});
