import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../core/constants/cloudinary_config.dart';
import '../../core/constants/sample_media.dart';
import '../../core/theme/avatar_colors.dart';

/// One seed video. Views, likes and subscriber numbers are made up for the
/// demo. The clips themselves are real and free to use (credits are in each
/// description).
class _SeedVideo {
  const _SeedVideo({
    required this.key,
    required this.title,
    required this.description,
    required this.category,
    required this.channelId,
    required this.channelName,
    required this.subscriberCount,
    required this.views,
    required this.likes,
    required this.daysAgo,
    required this.durationSeconds,
    this.isShort = false,
  });

  /// Also the Firestore document id, and the key in sample_media.dart.
  final String key;
  final String title;
  final String description;
  final String category;
  final String channelId;
  final String channelName;
  final int subscriberCount;
  final int views;
  final int likes;

  /// Upload date, counted back from the first launch.
  final int daysAgo;

  /// Close to the real length. The player corrects it on first play.
  final int durationSeconds;
  final bool isShort;

  Map<String, dynamic> toFirestore(DateTime now) {
    final clip = sampleClips[key]!;
    return {
      'sampleKey': key,
      'title': title,
      'description': description,
      'videoUrl': clip.videoUrl,
      'thumbnailUrl': clip.thumbnailUrl,
      'durationSeconds': durationSeconds,
      'channelId': channelId,
      'channelName': channelName,
      'channelAvatarUrl': '',
      'subscriberCount': subscriberCount,
      'views': views,
      'likes': likes,
      'category': category,
      'isShort': isShort,
      'uploaderUid': 'seed',
      'visibility': 'public',
      // A few extra hours so the videos don't all share the same time.
      'createdAt': Timestamp.fromDate(
        now.subtract(Duration(days: daysAgo, hours: key.length)),
      ),
    };
  }
}

// Channels (the same channel always has the same subscriber count).
const _blender = ('blender-foundation', 'Blender Foundation', 1340000);
const _evWeekly = ('ev-weekly', 'EV Weekly', 286000);
const _gearhead = ('gearhead-garage', 'Gearhead Garage', 742000);
const _trail = ('trail-and-tarmac', 'Trail & Tarmac', 158000);
const _nightOut = ('night-out-live', 'Night Out Live', 92400);
const _quickClips = ('quick-clips', 'Quick Clips', 51200);

/// One sample channel (written to `channels/{id}`).
class _SeedChannel {
  const _SeedChannel({
    required this.id,
    required this.name,
    required this.handle,
    required this.subscriberCount,
    required this.description,
    required this.bannerFrom,
    required this.daysAgo,
  });

  final String id;
  final String name;
  final String handle;
  final int subscriberCount;
  final String description;

  /// The banner is a wide crop of this seed video's frame:
  /// (video key, second).
  final (String, int) bannerFrom;

  /// Channel age, counted back from the first launch.
  final int daysAgo;

  Map<String, dynamic> toFirestore(DateTime now) {
    final (key, second) = bannerFrom;
    return {
      'name': name,
      'handle': handle,
      'description': description,
      'bannerUrl':
          'https://res.cloudinary.com/$cloudinaryCloudName/video/upload/'
          'so_$second,c_fill,w_1280,h_320/mytube/seed/$key.jpg',
      'avatarUrl': '',
      'avatarColor': avatarColorFor(name).toARGB32(),
      'subscriberCount': subscriberCount,
      'ownerUid': 'seed',
      'createdAt': Timestamp.fromDate(now.subtract(Duration(days: daysAgo))),
    };
  }
}

final List<_SeedChannel> _seedChannels = [
  _SeedChannel(
    id: _blender.$1,
    name: _blender.$2,
    handle: '@blenderfoundation',
    subscriberCount: _blender.$3,
    description:
        'The Blender Foundation makes free, open-source 3D software and '
        'the "open movies" made with it: Big Buck Bunny, Elephants Dream, '
        'Sintel and Tears of Steel. Every film and its production files '
        'are shared under Creative Commons.',
    bannerFrom: ('sintel', 330),
    daysAgo: 2900,
  ),
  _SeedChannel(
    id: _evWeekly.$1,
    name: _evWeekly.$2,
    handle: '@evweekly',
    subscriberCount: _evWeekly.$3,
    description:
        'Electric car reviews, road tests and range checks. New EVs every '
        'week.',
    bannerFrom: ('zeekr_x_review', 30),
    daysAgo: 1100,
  ),
  _SeedChannel(
    id: _gearhead.$1,
    name: _gearhead.$2,
    handle: '@gearheadgarage',
    subscriberCount: _gearhead.$3,
    description: 'Rally, racing and anything with an engine, filmed up close.',
    bannerFrom: ('rally_drone_chase', 20),
    daysAgo: 1600,
  ),
  _SeedChannel(
    id: _trail.$1,
    name: _trail.$2,
    handle: '@trailandtarmac',
    subscriberCount: _trail.$3,
    description:
        'Off-road adventures and calm drives through beautiful places.',
    bannerFrom: ('snow_forest_drive', 10),
    daysAgo: 800,
  ),
  _SeedChannel(
    id: _nightOut.$1,
    name: _nightOut.$2,
    handle: '@nightoutlive',
    subscriberCount: _nightOut.$3,
    description: 'Fireworks, street performers and city nights.',
    bannerFrom: ('bund_fireworks', 75),
    daysAgo: 650,
  ),
  _SeedChannel(
    id: _quickClips.$1,
    name: _quickClips.$2,
    handle: '@quickclips',
    subscriberCount: _quickClips.$3,
    description: 'Short, surprising clips from around the world.',
    bannerFrom: ('vettisfossen_waterfall', 5),
    daysAgo: 300,
  ),
];

final List<_SeedVideo> _seedVideos = [
  // ---------------- Animation ----------------
  _SeedVideo(
    key: 'big_buck_bunny',
    title: 'Big Buck Bunny | Blender Open Movie (Full Film)',
    description:
        'A giant, gentle rabbit just wants to enjoy a sunny day in the '
        'forest, until three rodent bullies push him too far. Big Buck Bunny '
        'is a short comedy made entirely with free, open-source software.\n\n'
        'Credits: © 2008 Blender Foundation | peach.blender.org\n'
        'Licensed under Creative Commons Attribution 3.0 (CC BY 3.0).\n'
        'Source: Internet Archive.',
    category: 'Animation',
    channelId: _blender.$1,
    channelName: _blender.$2,
    subscriberCount: _blender.$3,
    views: 18400000,
    likes: 212000,
    daysAgo: 540,
    durationSeconds: 596,
  ),
  _SeedVideo(
    key: 'elephants_dream',
    title: 'Elephants Dream | The First Open Movie',
    description:
        'Emo and Proog wander through an endless, mechanical world that only '
        'one of them believes is real. Released in 2006, Elephants Dream was '
        'the world\'s first "open movie": the film and all of its production '
        'files were shared for anyone to study and reuse.\n\n'
        'Credits: © 2006 Blender Foundation | orange.blender.org\n'
        'Licensed under a Creative Commons Attribution (CC BY) license.\n'
        'Source: Internet Archive.',
    category: 'Animation',
    channelId: _blender.$1,
    channelName: _blender.$2,
    subscriberCount: _blender.$3,
    views: 4900000,
    likes: 61000,
    daysAgo: 690,
    durationSeconds: 654,
  ),
  _SeedVideo(
    key: 'sintel',
    title: 'Sintel | Blender Open Movie (Full Film)',
    description:
        'A lonely young woman named Sintel sets out to find Scales, the baby '
        'dragon she once rescued and raised. Her search takes her across '
        'frozen mountains, deserts and strange cities, and to a discovery '
        'she never expected.\n\n'
        'Credits: © Blender Foundation | durian.blender.org\n'
        'Licensed under Creative Commons Attribution 3.0 (CC BY 3.0).\n'
        'Source: Internet Archive.',
    category: 'Animation',
    channelId: _blender.$1,
    channelName: _blender.$2,
    subscriberCount: _blender.$3,
    views: 25700000,
    likes: 388000,
    daysAgo: 320,
    durationSeconds: 888,
  ),

  // ---------------- Sci-Fi ----------------
  _SeedVideo(
    key: 'tears_of_steel',
    title: 'Tears of Steel | Sci-Fi Short Film',
    description:
        'In a future Amsterdam, a group of warriors and scientists gather at '
        'the Oude Kerk to restage a moment from the past: their last chance '
        'to save the world from destructive robots. Tears of Steel is the '
        'Blender Foundation\'s live-action and visual effects open movie.\n\n'
        'Credits: (CC) Blender Foundation | mango.blender.org\n'
        'Licensed under Creative Commons Attribution 3.0 (CC BY 3.0).\n'
        'Source: Wikimedia Commons.',
    category: 'Sci-Fi',
    channelId: _blender.$1,
    channelName: _blender.$2,
    subscriberCount: _blender.$3,
    views: 9800000,
    likes: 143000,
    daysAgo: 150,
    durationSeconds: 734,
  ),

  // ---------------- Cars ----------------
  _SeedVideo(
    key: 'zeekr_x_review',
    title: '2024 Zeekr X Review: Fast, Funky and Full-Featured',
    description:
        'A full review of the compact electric Zeekr X: design, interior, '
        'tech, range and how it drives on real roads. Is it time to take '
        'Chinese EVs seriously?\n\n'
        'Original video by MrChia SG, licensed under CC BY 3.0.\n'
        'Source: Wikimedia Commons.',
    category: 'Cars',
    channelId: _evWeekly.$1,
    channelName: _evWeekly.$2,
    subscriberCount: _evWeekly.$3,
    views: 1240000,
    likes: 18300,
    daysAgo: 12,
    durationSeconds: 912,
  ),
  _SeedVideo(
    key: 'rally_drone_chase',
    title: 'Chasing Rally Cars With an FPV Drone',
    description:
        'A racing drone chases rally cars flat-out through a forest stage. '
        'Dust, jumps and some very close calls.\n\n'
        'Footage by Flykit production, licensed under CC BY 3.0.\n'
        'Source: Wikimedia Commons.',
    category: 'Cars',
    channelId: _gearhead.$1,
    channelName: _gearhead.$2,
    subscriberCount: _gearhead.$3,
    views: 2310000,
    likes: 41500,
    daysAgo: 4,
    durationSeconds: 124,
  ),
  _SeedVideo(
    key: 'snow_forest_drive',
    title: 'Winter Drive Through a Snowy Forest (Aerial View)',
    description:
        'Calm aerial shots of a car winding along a snow-covered forest road. '
        'Put this on in the background and relax.\n\n'
        'Footage by Vladislav Sanikovich, licensed under CC BY 3.0.\n'
        'Source: Wikimedia Commons.',
    category: 'Cars',
    channelId: _trail.$1,
    channelName: _trail.$2,
    subscriberCount: _trail.$3,
    views: 864000,
    likes: 22100,
    daysAgo: 75,
    durationSeconds: 52,
  ),
  _SeedVideo(
    key: 'sherp_icebergs',
    title: 'This Amphibious Off-Roader Crosses a River of Icebergs',
    description:
        'The SHERP all-terrain vehicle floats, climbs and crawls its way over '
        'drifting ice on a frozen river. Can anything stop it?\n\n'
        'Video by Sherp ET (with Jon Bowe), licensed under CC BY 3.0.\n'
        'Source: Wikimedia Commons.',
    category: 'Cars',
    channelId: _trail.$1,
    channelName: _trail.$2,
    subscriberCount: _trail.$3,
    views: 3050000,
    likes: 67800,
    daysAgo: 210,
    durationSeconds: 535,
  ),

  // ---------------- Entertainment ----------------
  _SeedVideo(
    key: 'bund_fireworks',
    title: 'Spectacular Fireworks Over the Shanghai Bund',
    description:
        'Three minutes of fireworks lighting up the skyline along the Bund in '
        'Shanghai. Turn the volume up!\n\n'
        'Video by Fumikas Sagisavas, licensed under CC BY 4.0.\n'
        'Source: Wikimedia Commons.',
    category: 'Entertainment',
    channelId: _nightOut.$1,
    channelName: _nightOut.$2,
    subscriberCount: _nightOut.$3,
    views: 412000,
    likes: 6900,
    daysAgo: 25,
    durationSeconds: 165,
  ),
  _SeedVideo(
    key: 'fire_juggling',
    title: 'Fire Juggling at Night | Street Performance',
    description:
        'A street performer juggles flaming torches after dark. Do not try '
        'this at home.\n\n'
        'Video © 2009 Tomasz Sienicki, licensed under CC BY 3.0.\n'
        'Source: Wikimedia Commons.',
    category: 'Entertainment',
    channelId: _nightOut.$1,
    channelName: _nightOut.$2,
    subscriberCount: _nightOut.$3,
    views: 1080000,
    likes: 15200,
    daysAgo: 400,
    durationSeconds: 30,
  ),

  // ---------------- Shorts ----------------
  _SeedVideo(
    key: 'vettisfossen_waterfall',
    title: "Norway's tallest free-falling waterfall 😳",
    description:
        'Vettisfossen, Norway.\n\n'
        'Video by kallerna, licensed under CC BY-SA 3.0.\n'
        'Source: Wikimedia Commons.',
    category: 'Entertainment',
    channelId: _quickClips.$1,
    channelName: _quickClips.$2,
    subscriberCount: _quickClips.$3,
    views: 2600000,
    likes: 98000,
    daysAgo: 2,
    durationSeconds: 17,
    isShort: true,
  ),
  _SeedVideo(
    key: 'tgv_passing',
    title: "When the TGV doesn't stop at your station 🚄💨",
    description:
        'A high-speed train passes Labenne station, France.\n\n'
        'Video by Bastoche*, licensed under CC BY-SA 4.0.\n'
        'Source: Wikimedia Commons.',
    category: 'Entertainment',
    channelId: _quickClips.$1,
    channelName: _quickClips.$2,
    subscriberCount: _quickClips.$3,
    views: 5100000,
    likes: 210000,
    daysAgo: 9,
    durationSeconds: 8,
    isShort: true,
  ),
  _SeedVideo(
    key: 'magpies_calling',
    title: 'These magpies have a LOT to say 🐦',
    description:
        'A noisy group of magpies.\n\n'
        'Video by LyaiDemon, licensed under CC BY 4.0.\n'
        'Source: Wikimedia Commons.',
    category: 'Entertainment',
    channelId: _quickClips.$1,
    channelName: _quickClips.$2,
    subscriberCount: _quickClips.$3,
    views: 734000,
    likes: 31000,
    daysAgo: 33,
    durationSeconds: 53,
    isShort: true,
  ),
];

/// Writes the sample data to Firestore the first time the app starts.
class VideoSeeder {
  VideoSeeder._();

  /// The 13 seed videos, when the `videos` collection is empty.
  static Future<void> seedIfEmpty(FirebaseFirestore db) async {
    final videos = db.collection('videos');
    final existing = await videos.limit(1).get();
    if (existing.docs.isNotEmpty) return;

    // A batch writes all 13 documents in one go (all or nothing).
    final batch = db.batch();
    final now = DateTime.now();
    for (final video in _seedVideos) {
      batch.set(videos.doc(video.key), video.toFirestore(now));
    }
    await batch.commit();
    debugPrint('Seeded ${_seedVideos.length} videos.');
  }

  /// The 6 sample channels, if they don't exist yet (databases made before
  /// Phase 13 have the videos but no channels). Costs one read when they
  /// already exist.
  static Future<void> seedChannelsIfMissing(FirebaseFirestore db) async {
    final channels = db.collection('channels');
    final last = await channels.doc(_seedChannels.last.id).get();
    if (last.exists) return;

    final batch = db.batch();
    final now = DateTime.now();
    for (final channel in _seedChannels) {
      batch.set(channels.doc(channel.id), channel.toFirestore(now));
    }
    await batch.commit();
    debugPrint('Seeded ${_seedChannels.length} channels.');
  }
}

/// The sample channel ids (also listed in firestore.rules).
List<String> get seedChannelIds => [for (final c in _seedChannels) c.id];

/// The sample channels' handles, by channel id.
Map<String, String> get seedChannelHandles => {
  for (final c in _seedChannels) c.id: c.handle,
};
