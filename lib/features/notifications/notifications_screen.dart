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
import '../../data/models/app_notification.dart';
import '../../data/repositories/notification_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../auth/sign_in_screen.dart';
import '../comments/comments_sheet.dart';
import '../mini_player/player_panel_provider.dart';
import 'notifications_providers.dart';

/// The list behind the 🔔 on Home: uploads from channels I subscribe to,
/// comments on my videos and replies to my comments.
///
/// Blue dot = unread. Tap = open (and mark read). Swipe left or ⋮ to
/// remove; ⋮ also marks read / unread. "Mark all as read" in the top bar.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  void _back(BuildContext context) =>
      context.canPop() ? context.pop() : context.go('/home');

  void _showMessage(BuildContext context, String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    AppNotification n,
  ) async {
    final repository = ref.read(notificationRepositoryProvider);
    if (!n.read) {
      repository.setRead(n.id, read: true).catchError((Object _) {});
    }
    // Shorts play in the Shorts tab, videos in the player.
    if (n.isShort) {
      context.go('/shorts?v=${n.videoId}');
    } else {
      ref.read(playerPanelProvider.notifier).open(n.videoId);
    }
    // Comments and replies: show them in the comments, at the top.
    if (n.type != NotificationType.upload) {
      await showCommentsSheet(
        context,
        n.videoId,
        highlightCommentId: n.commentId,
        openReplies: n.type == NotificationType.reply,
        useRootNavigator: true,
      );
    }
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    AppNotification n,
  ) async {
    try {
      await ref.read(notificationRepositoryProvider).remove(n.id);
    } catch (_) {
      if (context.mounted) {
        _showMessage(context, "Couldn't remove it. Check your connection.");
      }
    }
  }

  Future<void> _showMenu(
    BuildContext context,
    WidgetRef ref,
    AppNotification n,
  ) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                n.read ? Symbols.mark_email_unread : Symbols.mark_email_read,
              ),
              title: Text(n.read ? 'Mark as unread' : 'Mark as read'),
              onTap: () => Navigator.pop(sheetContext, 'read'),
            ),
            ListTile(
              leading: const Icon(Symbols.delete),
              title: const Text('Remove this notification'),
              onTap: () => Navigator.pop(sheetContext, 'remove'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    switch (choice) {
      case 'read':
        ref
            .read(notificationRepositoryProvider)
            .setRead(n.id, read: !n.read)
            .catchError((Object _) {
              if (context.mounted) {
                _showMessage(context, "Couldn't save. Check your connection.");
              }
            });
      case 'remove':
        await _remove(context, ref, n);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(isSignedInProvider);
    final notifications = ref.watch(notificationsProvider);
    final unread = [
      for (final n in notifications.value ?? const <AppNotification>[])
        if (!n.read) n.id,
    ];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => _back(context),
          icon: const Icon(Symbols.arrow_back),
        ),
        title: const Text('Notifications'),
        actions: [
          if (unread.isNotEmpty)
            IconButton(
              tooltip: 'Mark all as read',
              onPressed: () => ref
                  .read(notificationRepositoryProvider)
                  .markAllRead(unread)
                  .catchError((Object _) {
                    if (context.mounted) {
                      _showMessage(
                        context,
                        "Couldn't save. Check your connection.",
                      );
                    }
                  }),
              icon: const Icon(Symbols.done_all),
            ),
        ],
      ),
      body: !signedIn
          ? EmptyState(
              icon: Symbols.notifications,
              title: "Don't miss new videos",
              message:
                  'Sign in to get notified about uploads from channels you '
                  'subscribe to, and comments and replies for you.',
              actionLabel: 'Sign in',
              onAction: () => openSignIn(context),
            )
          : notifications.when(
              loading: () => ListView.builder(
                itemCount: 6,
                itemBuilder: (context, index) => const _NotificationSkeleton(),
              ),
              error: (error, stackTrace) => EmptyState(
                icon: Symbols.cloud_off,
                title: "Couldn't load notifications",
                message: 'Check your internet connection and try again.',
                actionLabel: 'Retry',
                onAction: () => ref.invalidate(notificationsProvider),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return const EmptyState(
                    icon: Symbols.notifications,
                    title: 'Your notifications live here',
                    message:
                        'Subscribe to channels to hear about their new videos. '
                        'Comments on your videos and replies to you show up '
                        'here too.',
                  );
                }
                return ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final n = list[index];
                    return Dismissible(
                      key: ValueKey(n.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: AppColors.brandRed,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 24),
                        child: const Icon(Symbols.delete, color: Colors.white),
                      ),
                      onDismissed: (_) => _remove(context, ref, n),
                      child: NotificationTile(
                        notification: n,
                        onTap: () => _open(context, ref, n),
                        onMore: () => _showMenu(context, ref, n),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

/// One notification: blue dot (unread), sender's avatar, message, time,
/// video thumbnail and ⋮.
class NotificationTile extends StatelessWidget {
  const NotificationTile({
    super.key,
    required this.notification,
    required this.onTap,
    required this.onMore,
  });

  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final n = notification;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 16,
              height: 48,
              child: Center(
                child: n.read
                    ? null
                    : Container(
                        key: const ValueKey('unread-dot'),
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF3EA6FF),
                          shape: BoxShape.circle,
                        ),
                      ),
              ),
            ),
            ChannelAvatar(
              name: n.fromName,
              imageUrl: n.fromAvatarUrl,
              color: avatarColorOrNull(n.fromAvatarColor),
              size: 48,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    n.message,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body.copyWith(
                      color: colors.textPrimary,
                      fontSize: 14,
                      fontWeight: n.read ? FontWeight.w400 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timeAgo(n.createdAt),
                    style: AppTextStyles.meta.copyWith(
                      color: colors.textSecondary,
                    ),
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
                child: NetworkThumbnail(url: n.thumbnailUrl),
              ),
            ),
            IconButton(
              tooltip: 'More actions',
              visualDensity: VisualDensity.compact,
              onPressed: onMore,
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
