import 'cloudinary_config.dart';

/// Video + thumbnail address of one seed clip.
class SampleClip {
  const SampleClip({required this.videoUrl, required this.thumbnailUrl});

  final String videoUrl;
  final String thumbnailUrl;
}

/// Base address of videos in your Cloudinary account.
const String _cdn =
    'https://res.cloudinary.com/$cloudinaryCloudName/video/upload';

/// ALL 13 SEED VIDEO LINKS LIVE HERE.
///
/// The seed videos in Firestore only store a key (like 'sintel'), and the
/// app looks the real links up in this map. So if a link ever breaks, change
/// it here and reload: no need to touch Firestore.
///
/// Every link ends in .mp4, even for clips that were uploaded as WebM:
/// Cloudinary then delivers MP4/H.264, which every browser can play (Chrome
/// on some PCs rejected some of the WebM files with "Format error").
///
/// Thumbnails are made by Cloudinary from the video itself:
/// `so_60` = "the frame at second 60", `w_640` = 640px wide, `.jpg` = image.
const Map<String, SampleClip> sampleClips = {
  // ---------- Long videos ----------
  'big_buck_bunny': SampleClip(
    videoUrl: '$_cdn/mytube/seed/big_buck_bunny.mp4',
    thumbnailUrl: '$_cdn/so_60,w_640/mytube/seed/big_buck_bunny.jpg',
  ),
  'elephants_dream': SampleClip(
    videoUrl: '$_cdn/mytube/seed/elephants_dream.mp4',
    thumbnailUrl: '$_cdn/so_90,w_640/mytube/seed/elephants_dream.jpg',
  ),
  'sintel': SampleClip(
    videoUrl: '$_cdn/mytube/seed/sintel.mp4',
    thumbnailUrl: '$_cdn/so_330,w_640/mytube/seed/sintel.jpg',
  ),
  'tears_of_steel': SampleClip(
    videoUrl: '$_cdn/mytube/seed/tears_of_steel.mp4',
    thumbnailUrl: '$_cdn/so_60,w_640/mytube/seed/tears_of_steel.jpg',
  ),
  'zeekr_x_review': SampleClip(
    videoUrl: '$_cdn/mytube/seed/zeekr_x_review.mp4',
    thumbnailUrl: '$_cdn/so_30,w_640/mytube/seed/zeekr_x_review.jpg',
  ),
  'rally_drone_chase': SampleClip(
    videoUrl: '$_cdn/mytube/seed/rally_drone_chase.mp4',
    thumbnailUrl: '$_cdn/so_20,w_640/mytube/seed/rally_drone_chase.jpg',
  ),
  'snow_forest_drive': SampleClip(
    videoUrl: '$_cdn/mytube/seed/snow_forest_drive.mp4',
    thumbnailUrl: '$_cdn/so_10,w_640/mytube/seed/snow_forest_drive.jpg',
  ),
  'sherp_icebergs': SampleClip(
    videoUrl: '$_cdn/mytube/seed/sherp_icebergs.mp4',
    thumbnailUrl: '$_cdn/so_60,w_640/mytube/seed/sherp_icebergs.jpg',
  ),
  'bund_fireworks': SampleClip(
    videoUrl: '$_cdn/mytube/seed/bund_fireworks.mp4',
    thumbnailUrl: '$_cdn/so_75,w_640/mytube/seed/bund_fireworks.jpg',
  ),
  'fire_juggling': SampleClip(
    videoUrl: '$_cdn/mytube/seed/fire_juggling.mp4',
    thumbnailUrl: '$_cdn/so_10,w_640/mytube/seed/fire_juggling.jpg',
  ),

  // ---------- Shorts (vertical) ----------
  'vettisfossen_waterfall': SampleClip(
    videoUrl: '$_cdn/mytube/seed/vettisfossen_waterfall.mp4',
    thumbnailUrl: '$_cdn/so_5,w_400/mytube/seed/vettisfossen_waterfall.jpg',
  ),
  'tgv_passing': SampleClip(
    videoUrl: '$_cdn/mytube/seed/tgv_passing.mp4',
    thumbnailUrl: '$_cdn/so_3,w_400/mytube/seed/tgv_passing.jpg',
  ),
  'magpies_calling': SampleClip(
    videoUrl: '$_cdn/mytube/seed/magpies_calling.mp4',
    thumbnailUrl: '$_cdn/so_10,w_400/mytube/seed/magpies_calling.jpg',
  ),
};
