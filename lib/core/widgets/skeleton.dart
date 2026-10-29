import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/app_colors.dart';

/// Adds the moving grey "shimmer" shine to everything inside it.
///
/// Build the shape of the real content with [SkeletonBox]es, then wrap it
/// in a [Skeleton]. Used instead of a spinner while lists load.
class Skeleton extends StatelessWidget {
  const Skeleton({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDarkMode;
    return Shimmer.fromColors(
      baseColor: dark ? const Color(0xFF272727) : const Color(0xFFE5E5E5),
      highlightColor: dark ? const Color(0xFF3A3A3A) : const Color(0xFFF5F5F5),
      child: child,
    );
  }
}

/// A grey block in a skeleton (a line of text, a thumbnail, an avatar...).
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.radius = 4,
    this.circle = false,
  });

  final double? width;
  final double? height;
  final double radius;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    // The color only has to be solid: Shimmer paints over it.
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.placeholderLight,
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(radius),
      ),
    );
  }
}
