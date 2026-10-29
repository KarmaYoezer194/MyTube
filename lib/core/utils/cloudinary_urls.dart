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
