import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/video.dart';
import '../../data/repositories/video_repository.dart';
import '../discovery/discovery_providers.dart';
import '../discovery/hidden_content.dart';

export '../discovery/discovery_providers.dart'
    show
        allCategory,
        recentlyUploadedCategory,
        homeFeedProvider,
        recommendedProvider;
export '../discovery/hidden_content.dart'
    show notInterestedProvider, hiddenChannelsProvider, tasteProfileProvider;

/// The chips under the top bar (the Explore chip is added separately).
const List<String> homeCategories = [
  allCategory,
  'Animation',
  'Cars',
  'Entertainment',
  'Sci-Fi',
  recentlyUploadedCategory,
];

/// Which chip is selected.
class SelectedCategoryController extends Notifier<String> {
  @override
  String build() => allCategory;

  void select(String category) => state = category;
}

final selectedCategoryProvider =
    NotifierProvider<SelectedCategoryController, String>(
      SelectedCategoryController.new,
    );

/// The Shorts for the shelf on Home (not hidden ones).
final homeShortsProvider = Provider<List<Video>>((ref) {
  final taste = ref.watch(tasteProfileProvider);
  final videos = ref.watch(allVideosProvider).value ?? const [];
  return videos
      .where((v) => v.isShort && !v.isUnlisted && !taste.hides(v))
      .toList();
});
