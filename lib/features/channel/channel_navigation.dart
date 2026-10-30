import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../mini_player/player_panel_provider.dart';

/// Where a page like `channel/<id>` or `playlist/<id>` opens, given the
/// page you are on now.
///
/// It opens INSIDE the current tab (Home, Subscriptions or You), so the
/// bottom nav bar stays and Back returns to where you were. From Shorts
/// (or anywhere else) it opens in the Home tab.
///
/// Returns null if you are already on that page.
String? tabPageLocation(String currentPath, String kind, String id) {
  final encoded = Uri.encodeComponent(id);
  if (currentPath.endsWith('/$kind/$encoded')) return null;
  for (final tab in const ['/subscriptions', '/you', '/home']) {
    if (currentPath == tab || currentPath.startsWith('$tab/')) {
      return '$tab/$kind/$encoded';
    }
  }
  return '/home/$kind/$encoded';
}

/// Where a channel page opens (see [tabPageLocation]).
String? channelLocation(String currentPath, String channelId) =>
    tabPageLocation(currentPath, 'channel', channelId);

/// Opens `<tab>/<kind>/<id>`. A full-screen player shrinks to the mini
/// player first, like on YouTube.
void openTabPage(BuildContext context, WidgetRef ref, String kind, String id) {
  if (id.isEmpty) return;
  ref.read(playerPanelProvider.notifier).minimize();
  final router = GoRouter.of(context);
  final current = router.routerDelegate.currentConfiguration.uri.path;
  final location = tabPageLocation(current, kind, id);
  if (location == null) return;
  if (location.startsWith('/home/') && !current.startsWith('/home')) {
    // From Shorts: switch to the Home tab (this also pauses the Short).
    router.go(location);
  } else {
    router.push(location);
  }
}

/// Opens a channel page (from a channel name or avatar).
void openChannel(BuildContext context, WidgetRef ref, String channelId) =>
    openTabPage(context, ref, 'channel', channelId);

/// Opens a playlist page.
void openPlaylist(BuildContext context, WidgetRef ref, String playlistId) =>
    openTabPage(context, ref, 'playlist', playlistId);
