/// Turns the address of an UPLOADED Cloudinary video into one that plays
/// well on a phone (and in Chrome):
///
///   .../video/upload/v123/abc.mov
///   -> .../video/upload/c_limit,w_1280,h_1280/v123/abc.mp4
///
/// - `c_limit,w_1280,h_1280`: shrink to at most 1280px (a 4K upload is far
///   too heavy to stream and decode in the browser), never enlarge.
/// - `.mp4`: Cloudinary converts it to MP4/H.264, which every browser plays
///   (phone videos are often H.265/HEVC, which Chrome on many PCs can't).
///
/// The original file in Cloudinary is not changed. Cloudinary makes the
/// smaller copy the first time it's requested and keeps it.
/// Any other address is returned unchanged.
String playableVideoUrl(String url) {
  const marker = '/video/upload/';
  if (!url.contains('res.cloudinary.com') || !url.contains(marker)) return url;

  final start = url.indexOf(marker) + marker.length;
  final rest = url.substring(start);
  // Already has a size transformation? Leave it alone.
  if (rest.startsWith('c_')) return url;

  final dot = rest.lastIndexOf('.');
  final slash = rest.lastIndexOf('/');
  final withoutExtension = dot > slash ? rest.substring(0, dot) : rest;
  return '${url.substring(0, start)}c_limit,w_1280,h_1280/$withoutExtension.mp4';
}

/// Thumbnail widths we ask Cloudinary for. A few fixed sizes (instead of
/// the exact pixel width) keep the number of copies Cloudinary has to make
/// small - each new size counts once against the free plan.
const List<int> thumbnailWidths = [160, 320, 480, 720, 1080];

/// The smallest size in [thumbnailWidths] that is at least [pixels] wide.
int thumbnailBucket(double pixels) {
  for (final width in thumbnailWidths) {
    if (width >= pixels) return width;
  }
  return thumbnailWidths.last;
}

/// A smaller copy of a Cloudinary picture (or video frame), [width] pixels
/// wide at most, in automatic quality:
///
///   .../video/upload/so_60,w_640/mytube/seed/sintel.jpg
///   -> .../video/upload/so_60,w_640/c_limit,w_320,q_auto/mytube/seed/sintel.jpg
///
/// The size step goes AFTER the settings already in the link (so a video
/// frame is picked first, then shrunk). Pictures (`/image/upload/`) also
/// get `f_auto` (WebP / AVIF when the browser supports it). Any other link
/// is returned unchanged.
String sizedThumbnailUrl(String url, int width) {
  final match = RegExp(
    r'^(https://res\.cloudinary\.com/[^/]+/(image|video)/upload/)(.+)$',
  ).firstMatch(url);
  if (match == null) return url;
  final parts = match.group(3)!.split('/');
  var index = 0;
  while (index < parts.length - 1 &&
      RegExp(r'^[a-z]{1,3}_').hasMatch(parts[index])) {
    index++;
  }
  // Already sized by us.
  if (index > 0 && parts[index - 1].contains('q_auto')) return url;
  final format = match.group(2) == 'image' ? ',f_auto' : '';
  parts.insert(index, 'c_limit,w_$width,q_auto$format');
  return '${match.group(1)}${parts.join('/')}';
}
