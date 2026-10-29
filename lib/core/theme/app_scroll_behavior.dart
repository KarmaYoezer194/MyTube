import 'dart:ui';

import 'package:flutter/material.dart';

/// On Flutter web, lists can only be dragged with touch by default.
/// This lets you drag with the MOUSE too, so swiping in Chrome
/// (Shorts, chips row, pull to refresh) feels like a phone.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}
