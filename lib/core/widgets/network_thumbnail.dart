import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/app_colors.dart';

/// Shows an image from the internet, filling its space.
///
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

    if (kIsWeb) {
      return Image.network(
        url,
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
        errorBuilder: (context, error, stackTrace) => failed,
      );
    }

    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      placeholder: (context, url) => loading,
      errorWidget: (context, url, error) => failed,
    );
  }
}
