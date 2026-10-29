import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../core/constants/sample_media.dart';
import '../../core/utils/cloudinary_urls.dart';

/// One video (long video or Short), stored in Firestore at `videos/{id}`.
@immutable
class Video {
  const Video({
    required this.id,
    required this.title,
    required this.description,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.durationSeconds,
    required this.channelId,
    required this.channelName,
    required this.channelAvatarUrl,
    required this.subscriberCount,
    required this.views,
    required this.likes,
    required this.category,
    required this.isShort,
    required this.uploaderUid,
    required this.createdAt,
    this.visibility = 'public',
    this.channelAvatarColor,
  });

  final String id;
  final String title;
  final String description;
  final String videoUrl;
  final String thumbnailUrl;

  /// 0 means "not known yet". The player saves the real value the first
  /// time the video loads.
  final int durationSeconds;

  final String channelId;
  final String channelName;

  /// Empty string means "no picture": we show a colored letter avatar.
  final String channelAvatarUrl;

  /// The channel's letter-avatar color (a number like 0xFFD81B60).
  /// null on older videos: the color then comes from the channel name.
  final int? channelAvatarColor;

  final int subscriberCount;
  final int views;
  final int likes;

  /// Animation, Cars, Entertainment, Sci-Fi, ...
  final String category;

  /// true for Shorts (shown in the Shorts tab and Shorts shelf).
  final bool isShort;

  /// Who uploaded it. Seed videos use `seed`.
  final String uploaderUid;

  final DateTime createdAt;

  /// 'public' or 'unlisted'. Unlisted videos don't appear on Home.
  final String visibility;

  Duration get duration => Duration(seconds: durationSeconds);

  bool get isUnlisted => visibility == 'unlisted';

  /// Reads a Firestore document into a [Video].
  /// Every field has a safe default, so a half-filled document can't crash
  /// the app.
  factory Video.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    // Seed videos have a 'sampleKey'. Their links come from
    // core/constants/sample_media.dart, so a broken link can be swapped
    // there without editing Firestore.
    final sample = sampleClips[data['sampleKey']];
    return Video(
      id: doc.id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      // Uploads play as a phone-sized MP4 (see playableVideoUrl).
      videoUrl:
          sample?.videoUrl ??
          playableVideoUrl(data['videoUrl'] as String? ?? ''),
      thumbnailUrl:
          sample?.thumbnailUrl ?? data['thumbnailUrl'] as String? ?? '',
      durationSeconds: (data['durationSeconds'] as num?)?.toInt() ?? 0,
      channelId: data['channelId'] as String? ?? '',
      channelName: data['channelName'] as String? ?? '',
      channelAvatarUrl: data['channelAvatarUrl'] as String? ?? '',
      subscriberCount: (data['subscriberCount'] as num?)?.toInt() ?? 0,
      views: (data['views'] as num?)?.toInt() ?? 0,
      likes: (data['likes'] as num?)?.toInt() ?? 0,
      category: data['category'] as String? ?? '',
      isShort: data['isShort'] as bool? ?? false,
      uploaderUid: data['uploaderUid'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      visibility: data['visibility'] as String? ?? 'public',
      channelAvatarColor: (data['channelAvatarColor'] as num?)?.toInt(),
    );
  }

  /// Turns this [Video] into a map to save in Firestore (the id is the
  /// document name, so it isn't saved inside the document).
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'videoUrl': videoUrl,
      'thumbnailUrl': thumbnailUrl,
      'durationSeconds': durationSeconds,
      'channelId': channelId,
      'channelName': channelName,
      'channelAvatarUrl': channelAvatarUrl,
      'subscriberCount': subscriberCount,
      'views': views,
      'likes': likes,
      'category': category,
      'isShort': isShort,
      'uploaderUid': uploaderUid,
      'createdAt': Timestamp.fromDate(createdAt),
      'visibility': visibility,
      'channelAvatarColor': ?channelAvatarColor,
    };
  }

  Video copyWith({
    int? durationSeconds,
    int? views,
    int? likes,
    int? subscriberCount,
  }) {
    return Video(
      id: id,
      title: title,
      description: description,
      videoUrl: videoUrl,
      thumbnailUrl: thumbnailUrl,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      channelId: channelId,
      channelName: channelName,
      channelAvatarUrl: channelAvatarUrl,
      subscriberCount: subscriberCount ?? this.subscriberCount,
      views: views ?? this.views,
      likes: likes ?? this.likes,
      category: category,
      isShort: isShort,
      uploaderUid: uploaderUid,
      createdAt: createdAt,
      visibility: visibility,
      channelAvatarColor: channelAvatarColor,
    );
  }
}
