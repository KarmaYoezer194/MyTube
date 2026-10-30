import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../data/models/video.dart';

/// What the app knows about my taste, from data it already has (no extra
/// Firestore reads): my history, my subscriptions and what I hid.
@immutable
class TasteProfile {
  const TasteProfile({
    this.watchedIds = const {},
    this.categoryCounts = const {},
    this.subscribedChannelIds = const {},
    this.hiddenVideoIds = const {},
    this.hiddenChannelIds = const {},
  });

  final Set<String> watchedIds;

  /// How many videos of each category I watched.
  final Map<String, int> categoryCounts;
  final Set<String> subscribedChannelIds;
  final Set<String> hiddenVideoIds;
  final Set<String> hiddenChannelIds;

  /// "Not interested" or "Don't recommend channel".
  bool hides(Video video) =>
      hiddenVideoIds.contains(video.id) ||
      hiddenChannelIds.contains(video.channelId);
}

/// Counts the categories of the videos I watched.
Map<String, int> countCategories(Iterable<Video> watched) {
  final counts = <String, int>{};
  for (final video in watched) {
    counts[video.category] = (counts[video.category] ?? 0) + 1;
  }
  return counts;
}

/// A simple, explainable score (higher = recommended first):
/// - same channel as the video I'm watching: +3, same category: +2
/// - a channel I subscribe to: +2
/// - a category I watch a lot: up to +2
/// - not watched yet: +1
/// - popularity: + log10(views + 1) / 2
double recommendationScore(Video video, TasteProfile taste, {Video? current}) {
  var score = 0.0;
  if (current != null) {
    if (video.channelId == current.channelId) score += 3;
    if (video.category == current.category) score += 2;
  }
  if (taste.subscribedChannelIds.contains(video.channelId)) score += 2;
  final most = taste.categoryCounts.values.fold(0, max);
  if (most > 0) score += 2 * (taste.categoryCounts[video.category] ?? 0) / most;
  if (!taste.watchedIds.contains(video.id)) score += 1;
  score += log(video.views + 1) / ln10 / 2;
  return score;
}

/// Long, public videos that aren't hidden (and aren't [current]), best
/// first. With [unwatchedOnly], videos I already watched are left out.
List<Video> recommend(
  Iterable<Video> candidates,
  TasteProfile taste, {
  Video? current,
  bool unwatchedOnly = false,
}) {
  final list = [
    for (final video in candidates)
      if (!video.isShort &&
          !video.isUnlisted &&
          video.id != current?.id &&
          !taste.hides(video) &&
          !(unwatchedOnly && taste.watchedIds.contains(video.id)))
        (video, recommendationScore(video, taste, current: current)),
  ]..sort((a, b) => b.$2.compareTo(a.$2));
  return [for (final (video, _) in list) video];
}
