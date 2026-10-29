import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/video.dart';
import '../../data/repositories/video_repository.dart';

const String allCategory = 'All';
const String recentlyUploadedCategory = 'Recently uploaded';

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

/// Videos hidden with "Not interested" (only until the page is reloaded).
class NotInterestedController extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void hide(String videoId) => state = {...state, videoId};

  void undo(String videoId) => state = {...state}..remove(videoId);
}

final notInterestedProvider =
    NotifierProvider<NotInterestedController, Set<String>>(
  NotInterestedController.new,
);

/// The long videos shown on Home, filtered by the selected chip.
final homeFeedProvider = Provider<AsyncValue<List<Video>>>((ref) {
  final category = ref.watch(selectedCategoryProvider);
  final hidden = ref.watch(notInterestedProvider);
  final recentCutoff = DateTime.now().subtract(const Duration(days: 30));

  return ref.watch(allVideosProvider).whenData(
        (videos) => videos
            .where((v) => !v.isShort && !v.isUnlisted && !hidden.contains(v.id))
            .where((v) => switch (category) {
                  allCategory => true,
                  recentlyUploadedCategory => v.createdAt.isAfter(recentCutoff),
                  _ => v.category == category,
                })
            .toList(),
      );
});

/// The Shorts for the shelf on Home.
final homeShortsProvider = Provider<List<Video>>((ref) {
  final hidden = ref.watch(notInterestedProvider);
  final videos = ref.watch(allVideosProvider).value ?? const [];
  return videos
      .where((v) => v.isShort && !v.isUnlisted && !hidden.contains(v.id))
      .toList();
});
