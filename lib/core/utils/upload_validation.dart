/// What may be uploaded. The same limits are set in the Cloudinary upload
/// preset (see docs/SECURITY_SETUP.md), so a file that skips the app's
/// checks is still refused by Cloudinary.
class UploadLimits {
  UploadLimits._();

  /// Video formats (must match "Allowed formats" in the preset).
  static const Set<String> videoFormats = {'mp4', 'mov', 'webm', 'm4v'};

  /// Picture formats for thumbnails, avatars and banners.
  static const Set<String> imageFormats = {'jpg', 'jpeg', 'png', 'webp'};

  /// Keep demo uploads small (Cloudinary free plan allows up to 100 MB).
  static const int maxVideoBytes = 50 * 1024 * 1024;
  static const int maxImageBytes = 5 * 1024 * 1024;

  /// Longest long video: 15 minutes.
  static const int maxVideoSeconds = 15 * 60;

  /// Longest Short: 60 seconds (+1 for rounding).
  static const int maxShortSeconds = 61;
}

/// "Clip.MOV" -> "mov". Empty if the name has no extension.
String fileExtension(String fileName) {
  final dot = fileName.lastIndexOf('.');
  if (dot < 0 || dot == fileName.length - 1) return '';
  return fileName.substring(dot + 1).toLowerCase();
}

String _mb(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(0);

/// null if this video file may be uploaded, otherwise the reason.
String? checkVideoFile({required String fileName, required int sizeBytes}) {
  final ext = fileExtension(fileName);
  if (!UploadLimits.videoFormats.contains(ext)) {
    return 'This file type is not supported. Please pick an MP4, MOV, '
        'WEBM or M4V video.';
  }
  if (sizeBytes <= 0) return "This file looks empty. Please pick another one.";
  if (sizeBytes > UploadLimits.maxVideoBytes) {
    return 'This video is ${_mb(sizeBytes)} MB. Please pick one under '
        '${_mb(UploadLimits.maxVideoBytes)} MB.';
  }
  return null;
}

/// null if this picture may be uploaded, otherwise the reason.
String? checkImageFile({required String fileName, required int sizeBytes}) {
  final ext = fileExtension(fileName);
  if (!UploadLimits.imageFormats.contains(ext)) {
    return 'Please pick a JPG, PNG or WEBP picture.';
  }
  if (sizeBytes <= 0) return "This file looks empty. Please pick another one.";
  if (sizeBytes > UploadLimits.maxImageBytes) {
    return 'Please pick a picture under '
        '${_mb(UploadLimits.maxImageBytes)} MB.';
  }
  return null;
}

/// null if the length is allowed, otherwise the reason.
/// A length of 0 means "unknown" and is allowed (Cloudinary still limits
/// the file size).
String? checkVideoLength({required int seconds, required bool isShort}) {
  if (seconds <= 0) return null;
  if (isShort && seconds > UploadLimits.maxShortSeconds) {
    return 'Shorts can be up to 60 seconds long. This video is '
        '${_clock(seconds)}.';
  }
  if (!isShort && seconds > UploadLimits.maxVideoSeconds) {
    return 'Videos can be up to 15 minutes long. This video is '
        '${_clock(seconds)}.';
  }
  return null;
}

/// 75 -> "1:15".
String _clock(int seconds) {
  final m = seconds ~/ 60;
  final s = (seconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}
