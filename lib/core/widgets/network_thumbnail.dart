import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/app_colors.dart';
import '../utils/cloudinary_urls.dart';

/// Shows an image from the internet, filling its space.
///
/// - Cloudinary images are asked for at about the size they are shown
///   (e.g. 320 px wide for a small row instead of the full picture): much
///   less to download. If Cloudinary refuses the smaller copy, the
///   original is used.
/// - While loading: plain grey, then the image fades in.
/// - Empty url or failed load: grey with a play icon.
/// - On the WEB we use Image.network with an HTML <img> fallback, so images
///   still show even if the server doesn't send CORS headers.
///   On phones we use CachedNetworkImage (saves images on the device).
class NetworkThumbnail extends StatelessWidget {
  const NetworkThumbnail({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
  });

  final String url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final grey = context.isDarkMode
        ? AppColors.placeholderDark
        : AppColors.placeholderLight;
    final loading = ColoredBox(color: grey);
    final failed = ColoredBox(
      color: grey,
      child: Center(
        child: Icon(
          Symbols.play_circle,
          size: 40,
          color: context.colors.textSecondary,
        ),
      ),
    );

    if (url.isEmpty) return failed;

    return LayoutBuilder(
      builder: (context, box) {
        // The width in real screen pixels, rounded up to a few fixed sizes.
        final pixels = box.maxWidth * MediaQuery.devicePixelRatioOf(context);
        final sized = pixels.isFinite && pixels > 0
            ? sizedThumbnailUrl(url, thumbnailBucket(pixels))
            : url;
        return _image(
          sized,
          loading: loading,
          // The smaller copy failed: try the original once.
          onError: sized == url
              ? failed
              : _image(url, loading: loading, onError: failed),
        );
      },
    );
  }

  Widget _image(
    String src, {
    required Widget loading,
    required Widget onError,
  }) {
    if (kIsWeb) {
      return Image.network(
        src,
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded) return child;
          return Stack(
            fit: StackFit.expand,
            children: [
              loading,
              AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: const Duration(milliseconds: 250),
                child: child,
              ),
            ],
          );
        },
        errorBuilder: (context, error, stackTrace) => onError,
      );
    }

    return CachedNetworkImage(
      imageUrl: src,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      placeholder: (context, url) => loading,
      errorWidget: (context, url, error) => onError,
    );
  }
}
