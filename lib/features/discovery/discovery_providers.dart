import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/search_keywords.dart';
import '../../data/models/channel.dart';
import '../../data/models/video.dart';
import '../../data/repositories/channel_repository.dart';
import '../../data/repositories/paged_videos.dart';
import '../../data/repositories/video_repository.dart';
import 'hidden_content.dart';
import 'recommendations.dart';

// ---------------- Home ----------------

/// The Home chips that aren't a category.
const String allCategory = 'All';
const String recentlyUploadedCategory = 'Recently uploaded';

/// Home's feed for one chip, page by page (newest first).
class HomeFeedController extends PagedVideosController {
  HomeFeedController(this.chip);

  final String chip;

  @override
  Query<Map<String, dynamic>>? buildQuery() {
    final repository = ref.read(videoRepositoryProvider);
    return switch (chip) {
      allCategory => repository.homeQuery(),
      recentlyUploadedCategory => repository.homeQuery(
        since: DateTime.now().subtract(const Duration(days: 30)),
      ),
      _ => repository.homeQuery(category: chip),
    };
  }
}

final homeFeedProvider = NotifierProvider.autoDispose
    .family<HomeFeedController, PagedVideos, String>(HomeFeedController.new);

/// "Recommended for you" on Home: my best unwatched matches (up to 10).
final recommendedProvider = Provider<List<Video>>((ref) {
  final videos = ref.watch(allVideosProvider).value ?? const <Video>[];
  return recommend(
    videos,
    ref.watch(tasteProfileProvider),
    unwatchedOnly: true,
  ).take(10).toList();
});

// ---------------- Explore ----------------

/// Explore chips: Trending (all categories) or one category.
const String trendingChip = 'Trending';

/// Most viewed public videos, page by page.
class TrendingController extends PagedVideosController {
  TrendingController(this.chip);

  final String chip;

  @override
  Query<Map<String, dynamic>>? buildQuery() => ref
      .read(videoRepositoryProvider)
      .trendingQuery(category: chip == trendingChip ? null : chip);
}

final trendingProvider = NotifierProvider.autoDispose
    .family<TrendingController, PagedVideos, String>(TrendingController.new);

// ---------------- Search ----------------

enum SearchFilter { all, videos, shorts, channels }

enum SearchSort { relevance, date, views }

typedef SearchArg = ({String query, SearchFilter filter, SearchSort sort});

/// Videos for a search, page by page. Firestore finds ONE word (the
/// longest); [visibleSearchResults] checks the others.
class SearchVideosController extends PagedVideosController {
  SearchVideosController(this.arg);

  final SearchArg arg;

  @override
  Query<Map<String, dynamic>>? buildQuery() {
    final term = searchTerm(arg.query);
    if (term == null || arg.filter == SearchFilter.channels) return null;
    return ref
        .read(videoRepositoryProvider)
        .searchQuery(
          term,
          shorts: switch (arg.filter) {
            SearchFilter.videos => false,
            SearchFilter.shorts => true,
            _ => null,
          },
          byViews: arg.sort != SearchSort.date,
        );
  }
}

final searchVideosProvider = NotifierProvider.autoDispose
    .family<SearchVideosController, PagedVideos, SearchArg>(
      SearchVideosController.new,
    );

/// The loaded search results to show: every word must match, hidden ones
/// are left out, and "Relevance" puts the best title matches first (among
/// what is loaded so far).
List<Video> visibleSearchResults(
  List<Video> loaded,
  String query,
  SearchSort sort,
  TasteProfile taste,
) {
  final results = [
    for (final video in loaded)
      if (!taste.hides(video) &&
          matchesQuery([video.title, video.channelName, video.category], query))
        video,
  ];
  if (sort == SearchSort.relevance) {
    // A stable sort: equal scores keep Firestore's order (most viewed).
    final scored = [
      for (var i = 0; i < results.length; i++)
        (results[i], relevanceScore(results[i].title, query), i),
    ]..sort((a, b) => a.$2 != b.$2 ? b.$2 - a.$2 : a.$3 - b.$3);
    return [for (final (video, _, _) in scored) video];
  }
  return results;
}

/// Channels for a search (up to 20, most subscribers first).
final searchChannelsProvider = FutureProvider.autoDispose
    .family<List<Channel>, String>((ref, query) async {
      final term = searchTerm(query);
      if (term == null) return const [];
      final hidden = ref.watch(hiddenChannelsProvider);
      try {
        final snapshot = await ref
            .read(channelRepositoryProvider)
            .searchQuery(term)
            .limit(20)
            .get();
        return [
          for (final doc in snapshot.docs)
            if (Channel.fromFirestore(doc) case final channel
                when !hidden.contains(channel.id) &&
                    matchesQuery([channel.name, channel.handle], query))
              channel,
        ];
      } catch (error) {
        debugPrint('SEARCH channels failed: $error');
        rethrow;
      }
    });
