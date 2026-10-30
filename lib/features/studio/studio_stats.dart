import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../data/models/video.dart';

/// Totals for the Studio's channel dashboard, worked out from my videos
/// (no extra Firestore reads).
@immutable
class ChannelStats {
  const ChannelStats({
    required this.videoCount,
    required this.shortCount,
    required this.views,
    required this.likes,
    required this.comments,
    required this.topVideo,
  });

  final int videoCount;
  final int shortCount;
  final int views;
  final int likes;
  final int comments;

  /// The most viewed upload, or null if there are none.
  final Video? topVideo;

  int get uploads => videoCount + shortCount;
}

ChannelStats channelStatsOf(Iterable<Video> videos) {
  var videoCount = 0, shortCount = 0, views = 0, likes = 0, comments = 0;
  Video? top;
  for (final video in videos) {
    video.isShort ? shortCount++ : videoCount++;
    views += video.views;
    likes += video.likes;
    comments += video.commentCount ?? 0;
    if (top == null || video.views > top.views) top = video;
  }
  return ChannelStats(
    videoCount: videoCount,
    shortCount: shortCount,
    views: views,
    likes: likes,
    comments: comments,
    topVideo: top,
  );
}

/// Likes per view (0..1), or null before the first view.
double? likeRate(Video video) =>
    video.views <= 0 ? null : video.likes / video.views;

/// Average views per day since upload (a video younger than a day counts
/// as one day old).
double viewsPerDay(Video video, DateTime now) {
  final days = now.difference(video.createdAt).inHours / 24;
  return video.views / max(1.0, days);
}

/// 1 = the most viewed of [videos].
int viewsRank(List<Video> videos, Video video) =>
    1 + videos.where((v) => v.views > video.views).length;

/// [part] out of [whole] (0..1); 0 when [whole] is 0.
double shareOf(int part, int whole) => whole <= 0 ? 0 : part / whole;

/// 0.125 -> "12.5%", 0.4 -> "40%", tiny -> "<0.1%", null -> "-".
String formatPercent(double? value) {
  if (value == null) return '-';
  final percent = value * 100;
  if (percent == 0) return '0%';
  if (percent < 0.1) return '<0.1%';
  if (percent < 10) {
    final text = percent.toStringAsFixed(1);
    return '${text.endsWith('.0') ? text.substring(0, text.length - 2) : text}%';
  }
  return '${percent.round()}%';
}

enum StudioFilter { all, videos, shorts }

enum StudioSort { newest, mostViewed, mostLiked }

/// My uploads for the Studio list, filtered and sorted.
List<Video> studioList(
  List<Video> videos,
  StudioFilter filter,
  StudioSort sort,
) {
  final list = [
    for (final video in videos)
      if (switch (filter) {
        StudioFilter.all => true,
        StudioFilter.videos => !video.isShort,
        StudioFilter.shorts => video.isShort,
      })
        video,
  ];
  list.sort(
    (a, b) => switch (sort) {
      StudioSort.newest => b.createdAt.compareTo(a.createdAt),
      StudioSort.mostViewed => b.views.compareTo(a.views),
      StudioSort.mostLiked => b.likes.compareTo(a.likes),
    },
  );
  return list;
}

/// The name of a file in Cloudinary (its "public id"), e.g. "abc123" or
/// "mytube/abc123", from any of its links (with or without size settings,
/// version or file extension). null if it isn't a Cloudinary upload link.
///
/// Shown when you delete a video, so you can find the file in Cloudinary's
/// Media Library and delete it there too.
String? cloudinaryPublicId(String url) {
  final match = RegExp(
    r'^https://res\.cloudinary\.com/[^/]+/(?:video|image)/upload/(.+)$',
  ).firstMatch(url);
  if (match == null) return null;
  final parts = match.group(1)!.split('/');
  // Skip settings like "c_limit,w_1280" or "so_1" and the version "v123".
  var start = 0;
  while (start < parts.length - 1 &&
      (RegExp(r'^[a-z]{1,3}_').hasMatch(parts[start]) ||
          RegExp(r'^v\d+$').hasMatch(parts[start]))) {
    start++;
  }
  final path = parts.sublist(start).join('/');
  final dot = path.lastIndexOf('.');
  final id = dot > path.lastIndexOf('/') ? path.substring(0, dot) : path;
  return id.isEmpty ? null : id;
}
