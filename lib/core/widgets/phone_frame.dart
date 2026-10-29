import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Makes the app look like a phone in a wide Chrome window.
///
/// The app is drawn in a centered column at most 430px wide, with black on
/// both sides. We also tell the app (through MediaQuery) that the screen is
/// only that wide, so every screen lays itself out like on a real phone.
class PhoneFrame extends StatelessWidget {
  const PhoneFrame({super.key, required this.child});

  static const double maxWidth = 430;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final width = math.min(media.size.width, maxWidth);

    return ColoredBox(
      color: AppColors.outsideFrame,
      child: Center(
        child: SizedBox(
          width: width,
          height: media.size.height,
          child: MediaQuery(
            data: media.copyWith(size: Size(width, media.size.height)),
            child: ClipRect(child: child),
          ),
        ),
      ),
    );
  }
}
