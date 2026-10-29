import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/text_styles.dart';
import '../../core/utils/time_ago.dart';
import '../../core/widgets/channel_avatar.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/network_thumbnail.dart';
import '../../core/widgets/skeleton.dart';
import '../../data/repositories/video_repository.dart';
import '../mini_player/player_panel_provider.dart';
import 'notifications_providers.dart';

/// The list behind the 🔔 on Home.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  /// "Last seen" from BEFORE this visit, so new items keep their blue dot
  /// while you are looking at them (the badge on Home is cleared already).
  late final DateTime? _seenBefore;

  @override
  void initState() {
    super.initState();
    _seenBefore = ref.read(notificationsSeenAtProvider);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(notificationsSeenAtProvider.notifier).markAllSeen(),
    );
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifications = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: _back,
          icon: const Icon(Symbols.arrow_back),
        ),
        title: const Text('Notifications'),
        actions: [
          IconButton(
            tooltip: 'Search',
            onPressed: () => context.push('/home/search'),
            icon: const Icon(Symbols.search),
          ),
        ],
      ),
      body: notifications.when(
        loading: () => ListView.builder(
          itemCount: 6,
          itemBuilder: (context, index) => const _NotificationSkeleton(),
        ),
        error: (error, stackTrace) => EmptyState(
          icon: Symbols.cloud_off,
          title: "Couldn't load notifications",
          message: 'Check your internet connection and try again.',
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(allVideosProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Symbols.notifications,
              title: 'Your notifications live here',
              message: 'New uploads from channels will show up here.',
            );
          }
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, index) {
              final n = list[index];
              final unread = _seenBefore == null || n.time.isAfter(_seenBefore);
              return _NotificationTile(
                notification: n,
                unread: unread,
                onTap: () {
                  if (n.video.isShort) {
                    context.go('/shorts?v=${n.video.id}');
                  } else {
                    ref.read(playerPanelProvider.notifier).open(n.video.id);
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.unread,
    required this.onTap,
  });

  final AppNotification notification;
  final bool unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final video = notification.video;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Blue dot = new since your last visit.
            SizedBox(
              width: 16,
              height: 48,
              child: Center(
                child: unread
                    ? Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF3EA6FF),
                          shape: BoxShape.circle,
                        ),
                      )
                    : null,
              ),
            ),
            ChannelAvatar(
              name: video.channelName,
              imageUrl: video.channelAvatarUrl,
              size: 48,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.text,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body.copyWith(
                      color: colors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timeAgo(notification.time),
                    style:
                        AppTextStyles.meta.copyWith(color: colors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                width: 112,
                height: 63,
                child: NetworkThumbnail(url: video.thumbnailUrl),
              ),
            ),
            IconButton(
              tooltip: 'More actions',
              visualDensity: VisualDensity.compact,
              onPressed: () => ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(const SnackBar(
                  content: Text('Notification settings are not part of this demo'),
                )),
              icon: const Icon(Symbols.more_vert, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationSkeleton extends StatelessWidget {
  const _NotificationSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Skeleton(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBox(width: 48, height: 48, circle: true),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: double.infinity, height: 14),
                  SizedBox(height: 6),
                  SkeletonBox(width: 140, height: 14),
                  SizedBox(height: 8),
                  SkeletonBox(width: 70, height: 12),
                ],
              ),
            ),
            SizedBox(width: 12),
            SkeletonBox(width: 112, height: 63, radius: 4),
          ],
        ),
      ),
    );
  }
}
