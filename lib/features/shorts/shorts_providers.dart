import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/video.dart';
import '../../data/repositories/video_repository.dart';

/// All Shorts for the Shorts tab, newest first (unlisted ones left out).
final shortsFeedProvider = Provider<AsyncValue<List<Video>>>((ref) {
  return ref
      .watch(allVideosProvider)
      .whenData(
        (videos) => videos.where((v) => v.isShort && !v.isUnlisted).toList(),
      );
});
