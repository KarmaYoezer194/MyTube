import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/channel/channel_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/search/search_screen.dart';
import '../../features/shorts/shorts_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/subscriptions/subscriptions_screen.dart';
import '../../features/you/video_list_screen.dart';
import '../../features/you/you_screen.dart';
import '../widgets/app_shell.dart';

/// The navigator that sits above the tabs. Screens pushed with this key
/// (later: search, settings, upload) cover the bottom nav bar.
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// All the app's routes (pages and their URLs).
///
/// StatefulShellRoute = bottom tabs that each remember their own state
/// (scroll position, pages opened inside the tab) when you switch tabs.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/home',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
                // Opened on top of Home (the nav bar stays visible and
                // the player can still open over them).
                routes: [
                  GoRoute(
                    path: 'search',
                    builder: (context, state) => const SearchScreen(),
                  ),
                  GoRoute(
                    path: 'notifications',
                    builder: (context, state) => const NotificationsScreen(),
                  ),
                  _channelRoute(),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/shorts',
                // /shorts?v=<id> opens at that Short.
                builder: (context, state) => ShortsScreen(
                  initialVideoId: state.uri.queryParameters['v'],
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/subscriptions',
                builder: (context, state) => const SubscriptionsScreen(),
                routes: [_channelRoute()],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/you',
                builder: (context, state) => const YouScreen(),
                routes: [
                  GoRoute(
                    path: 'history',
                    builder: (context, state) =>
                        const VideoListScreen(kind: VideoListKind.history),
                  ),
                  GoRoute(
                    path: 'liked',
                    builder: (context, state) =>
                        const VideoListScreen(kind: VideoListKind.liked),
                  ),
                  GoRoute(
                    path: 'watch-later',
                    builder: (context, state) =>
                        const VideoListScreen(kind: VideoListKind.watchLater),
                  ),
                  GoRoute(
                    path: 'videos',
                    builder: (context, state) =>
                        const VideoListScreen(kind: VideoListKind.yourVideos),
                  ),
                  GoRoute(
                    path: 'settings',
                    builder: (context, state) => const SettingsScreen(),
                  ),
                  _channelRoute(),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

/// `<tab>/channel/<channelId>`: a channel page inside a tab (see
/// features/channel/channel_navigation.dart).
GoRoute _channelRoute() => GoRoute(
  path: 'channel/:channelId',
  builder: (context, state) => ChannelScreen(
    // A new key per channel, so going from one channel to another starts
    // fresh (tabs, scroll position).
    key: ValueKey(state.pathParameters['channelId']),
    channelId: state.pathParameters['channelId'] ?? '',
  ),
);
