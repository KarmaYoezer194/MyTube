import 'package:flutter/services.dart';

import '../../data/models/video.dart';

/// Links into the app. Flutter web uses "hash" addresses by default:
///   http://localhost:1234/#/watch?v=sintel
///   http://localhost:1234/#/shorts/fire_juggling
///   http://localhost:1234/#/@blenderfoundation
/// They work after a page refresh, and later on any static host (no
/// server rewrite rules needed).

String watchPath(String videoId) =>
    '/watch?v=${Uri.encodeQueryComponent(videoId)}';

String shortPath(String videoId) => '/shorts/${Uri.encodeComponent(videoId)}';

/// A Short opens in the Shorts tab, everything else on the watch page.
String videoPath(Video video) =>
    video.isShort ? shortPath(video.id) : watchPath(video.id);

/// "@blenderfoundation" -> "/@blenderfoundation".
String channelPath(String handle) =>
    '/${handle.startsWith('@') ? handle : '@$handle'}';

/// The full link for [path] on a site at [origin].
String buildAppLink(String origin, String path) => '$origin/#$path';

/// The full link for [path] on the site MyTube is running on right now.
String appLink(String path) {
  String origin;
  try {
    origin = Uri.base.origin;
  } catch (_) {
    origin = ''; // Not a web page (tests).
  }
  return buildAppLink(origin, path);
}

/// Shows [path] in the browser's address bar WITHOUT navigating (so a
/// refresh comes back to it). Used for the player, which is an overlay,
/// not a page of its own.
void showInAddressBar(String path) {
  SystemNavigator.routeInformationUpdated(uri: Uri.parse(path), replace: true);
}
