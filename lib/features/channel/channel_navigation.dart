import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../mini_player/player_panel_provider.dart';

/// Where a channel page opens, given the page you are on now.
///
/// The channel page is opened INSIDE the current tab (Home, Subscriptions
/// or You), so the bottom nav bar stays and Back returns to where you were.
/// From Shorts (or anywhere else) it opens in the Home tab.
///
/// Returns null if you are already on that channel's page.
String? channelLocation(String currentPath, String channelId) {
  final encoded = Uri.encodeComponent(channelId);
  if (currentPath.endsWith('/channel/$encoded')) return null;
  for (final tab in const ['/subscriptions', '/you', '/home']) {
    if (currentPath == tab || currentPath.startsWith('$tab/')) {
      return '$tab/channel/$encoded';
    }
  }
  return '/home/channel/$encoded';
}

/// Opens a channel page (from a channel name or avatar). A full-screen
/// player shrinks to the mini player first, like on YouTube.
void openChannel(BuildContext context, WidgetRef ref, String channelId) {
  if (channelId.isEmpty) return;
  ref.read(playerPanelProvider.notifier).minimize();
  final router = GoRouter.of(context);
  final current = router.routerDelegate.currentConfiguration.uri.path;
  final location = channelLocation(current, channelId);
  if (location == null) return;
  if (location.startsWith('/home/') && !current.startsWith('/home')) {
    // From Shorts: switch to the Home tab (this also pauses the Short).
    router.go(location);
  } else {
    router.push(location);
  }
}
