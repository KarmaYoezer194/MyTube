import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../features/mini_player/player_panel.dart';
import '../../features/mini_player/player_panel_provider.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../features/upload/create_sheet.dart';
import '../utils/app_links.dart';
import '../utils/online_status.dart';
import 'app_bottom_nav_bar.dart';
import 'channel_avatar.dart';

/// The frame around the 4 tabs (Home, Shorts, Subscriptions, You).
///
/// Layers from bottom to top:
///   1. the current tab, with the bottom nav bar under it
///   2. the player panel (full watch page or mini player)
///
/// The panel is ABOVE the nav bar, so the full watch page covers it, and
/// while you drag the page down the nav bar appears underneath. Because the
/// player lives here and not inside a tab, it keeps playing when you switch
/// tabs.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  /// The nav bar has 5 items but only 4 tabs, because the (+) button opens
  /// a sheet. These two helpers translate between the two numberings.
  static int _branchToNavItem(int branch) => branch < 2 ? branch : branch + 1;
  static int _navItemToBranch(int item) => item < 2 ? item : item - 1;

  static const int _shortsBranch = 1;

  void _onNavTap(BuildContext context, WidgetRef ref, int item) {
    if (item == AppBottomNavBar.createIndex) {
      showCreateSheet(context, ref);
      return;
    }
    final branch = _navItemToBranch(item);
    navigationShell.goBranch(
      branch,
      // Tapping the tab you are already on goes back to its first page.
      initialLocation: branch == navigationShell.currentIndex,
    );
  }

  /// Your small avatar for the "You" tab when signed in (null for guests).
  /// It updates by itself the moment you sign in, out, or switch account.
  Widget? _youAvatar(WidgetRef ref) {
    if (!ref.watch(isSignedInProvider)) return null;
    final profile = ref.watch(myProfileProvider).value;
    final user = ref.watch(authUserProvider).value;
    final name =
        profile?.displayName ?? user?.displayName ?? user?.email ?? 'Me';
    return ChannelAvatar(
      name: name,
      imageUrl: profile?.avatarUrl ?? '',
      color: profile?.avatarColorValue,
      size: 24,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keeps my subscriptions loaded while the app runs: this also fills in
    // the channelId on older ones, so channels can notify me of uploads.
    ref.listen(subscribedIdsProvider, (_, _) {});
    // While the full player is open, the address bar shows /watch?v=ID
    // (a refresh or a copied address opens that video). Back to the page
    // underneath when it shrinks or closes.
    ref.listen(playerPanelProvider, (previous, next) {
      if (next.isExpanded && next.videoId != null) {
        showInAddressBar(watchPath(next.videoId!));
      } else if (previous?.isExpanded ?? false) {
        showInAddressBar(
          GoRouter.of(
            context,
          ).routerDelegate.currentConfiguration.uri.toString(),
        );
      }
    });
    final panel = ref.watch(playerPanelProvider);
    final navHeight = AppBottomNavBar.totalHeight(context);
    final onShorts = navigationShell.currentIndex == _shortsBranch;

    // Like YouTube, the mini player is hidden on the Shorts tab (the Shorts
    // screen also pauses it). It comes back when you leave Shorts.
    final showMini = panel.isMini && !onShorts;

    // Snackbars float just above the nav bar (and the mini player).
    final theme = Theme.of(context);
    final snackBarBottom = panel.isExpanded
        ? 10.0
        : navHeight + (showMini ? kMiniPlayerHeight : 0) + 10;

    return Theme(
      data: theme.copyWith(
        snackBarTheme: theme.snackBarTheme.copyWith(
          insetPadding: EdgeInsets.fromLTRB(12, 5, 12, snackBarBottom),
        ),
      ),
      child: Scaffold(
        body: Stack(
          children: [
            Column(
              children: [
                // "You're offline" (slides in/out with the connection).
                _OfflineBar(
                  offline: !(ref.watch(isOnlineProvider).value ?? true),
                ),
                // Leave room so the mini player doesn't cover content.
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: showMini ? kMiniPlayerHeight : 0,
                    ),
                    child: navigationShell,
                  ),
                ),
                AppBottomNavBar(
                  selectedIndex: _branchToNavItem(navigationShell.currentIndex),
                  forceDark: onShorts,
                  onTap: (item) => _onNavTap(context, ref, item),
                  youAvatar: _youAvatar(ref),
                ),
              ],
            ),
            Positioned.fill(
              // Offstage = hidden but kept alive (the video isn't reloaded).
              child: Offstage(
                offstage: onShorts && !panel.isExpanded,
                child: PlayerPanel(bottomInset: navHeight),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dark strip at the top while there is no internet connection.
/// Firestore keeps working from its local copy and syncs when you're back.
class _OfflineBar extends StatelessWidget {
  const _OfflineBar({required this.offline});

  final bool offline;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      child: offline
          ? Material(
              color: const Color(0xFF323232),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: const [
                      Icon(Symbols.wifi_off, color: Colors.white, size: 18),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "You're offline. Check your connection.",
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : const SizedBox(width: double.infinity),
    );
  }
}
