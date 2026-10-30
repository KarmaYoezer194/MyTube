import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/text_styles.dart';
import '../../core/widgets/channel_avatar.dart';
import '../../core/widgets/compact_video_row.dart';
import '../../core/widgets/duration_badge.dart';
import '../../core/widgets/network_thumbnail.dart';
import '../../core/widgets/skeleton.dart';
import '../../data/models/video.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/models/channel.dart';
import '../../data/models/playlist.dart';
import '../../data/repositories/playlist_repository.dart';
import '../../data/repositories/video_repository.dart';
import '../auth/sign_in_screen.dart';
import '../channel/channel_navigation.dart';
import '../mini_player/player_panel_provider.dart';
import '../playlists/playlist_dialogs.dart';
import '../upload/create_sheet.dart';
import 'you_providers.dart';

/// You tab.
///
/// - Guest: "You're not signed in" + Sign in button, and History (guests
///   have a watch history too).
/// - Signed in: avatar, name, @handle, email, History, Playlists (Liked
///   videos, Watch later) and Your videos.
///
/// The ⚙ opens Settings (with Sign out).
class YouScreen extends ConsumerWidget {
  const YouScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(isSignedInProvider);
    final history = ref.watch(historyVideosProvider);
    final liked = ref.watch(likedVideosProvider);
    final watchLater = ref.watch(watchLaterVideosProvider);
    final mine = ref.watch(myVideosProvider);
    final playlists = ref.watch(myPlaylistsProvider).value ?? const [];
    final videosById = {
      for (final v in ref.watch(allVideosProvider).value ?? const <Video>[])
        v.id: v,
    };

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: 'Search',
            onPressed: () => context.go('/home/search'),
            icon: const Icon(Symbols.search),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: () => context.push('/you/settings'),
            icon: const Icon(Symbols.settings),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const _ProfileHeader(),
          const SizedBox(height: 20),

          // ---- History ----
          _SectionHeader(
            title: 'History',
            onViewAll: () => context.push('/you/history'),
          ),
          SizedBox(
            height: 160,
            child: history.when(
              loading: () => const _CardRowSkeleton(),
              error: (error, stackTrace) =>
                  const _RowMessage("Couldn't load your history."),
              data: (items) => items.isEmpty
                  ? const _RowMessage('Videos you watch will show up here.')
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: items.length.clamp(0, 10),
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 10),
                      itemBuilder: (context, index) =>
                          _HistoryCard(item: items[index]),
                    ),
            ),
          ),
          const SizedBox(height: 12),

          // Liked videos, Watch later and uploads need an account.
          if (signedIn) ...[
            // ---- Playlists ----
            _SectionHeader(
              title: 'Playlists',
              onAdd: () async {
                final id = await createPlaylistFlow(context, ref);
                if (id != null && context.mounted) {
                  context.push('/you/playlist/$id');
                }
              },
            ),
            SizedBox(
              height: 150,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _PlaylistCard(
                    title: 'Liked videos',
                    icon: Symbols.thumb_up,
                    thumbnailUrl: liked.value?.firstOrNull?.video.thumbnailUrl,
                    subtitle: _videoCount(liked.value?.length),
                    onTap: () => context.push('/you/liked'),
                  ),
                  const SizedBox(width: 10),
                  _PlaylistCard(
                    title: 'Watch later',
                    icon: Symbols.schedule,
                    thumbnailUrl:
                        watchLater.value?.firstOrNull?.video.thumbnailUrl,
                    subtitle: _videoCount(watchLater.value?.length),
                    onTap: () => context.push('/you/watch-later'),
                  ),
                  for (final playlist in playlists) ...[
                    const SizedBox(width: 10),
                    _PlaylistCard(
                      key: ValueKey(playlist.id),
                      title: playlist.title,
                      icon: Symbols.playlist_play,
                      thumbnailUrl: _firstThumbnail(playlist, videosById),
                      subtitle: playlistSubtitle(
                        isPrivate: playlist.isPrivate,
                        count: playlist.videoIds.length,
                      ),
                      onTap: () => context.push('/you/playlist/${playlist.id}'),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ---- Your videos ----
            _SectionHeader(
              title: 'Your videos',
              onViewAll: (mine.value?.isNotEmpty ?? false)
                  ? () => context.push('/you/videos')
                  : null,
            ),
            ...mine.when(
              loading: () => const [CompactVideoRowSkeleton()],
              error: (error, stackTrace) => const [
                _RowMessage("Couldn't load your videos."),
              ],
              data: (items) => items.isEmpty
                  ? [
                      ListTile(
                        leading: const Icon(Symbols.upload),
                        title: const Text('Upload your first video'),
                        onTap: () => showCreateSheet(context, ref),
                      ),
                    ]
                  : [
                      for (final item in items.take(3))
                        CompactVideoRow(
                          key: ValueKey(item.video.id),
                          video: item.video,
                        ),
                    ],
            ),
          ],
          const Divider(height: 32),

          // ---- Settings shortcut ----
          ListTile(
            leading: const Icon(Symbols.settings),
            title: const Text('Settings'),
            onTap: () => context.push('/you/settings'),
          ),
        ],
      ),
    );
  }
}

/// The top of the You tab: signed-out or signed-in version.
class _ProfileHeader extends ConsumerWidget {
  const _ProfileHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(isSignedInProvider)
        ? const _SignedInHeader()
        : const _SignedOutHeader();
  }
}

/// YouTube's signed-out layout: grey avatar, what signing in gives you,
/// and a Sign in pill.
class _SignedOutHeader extends StatelessWidget {
  const _SignedOutHeader();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const ChannelAvatar(name: '', size: 64),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "You're not signed in",
                      style: AppTextStyles.sectionHeader.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sign in to like videos, comment, subscribe and '
                      'upload.',
                      style: AppTextStyles.meta.copyWith(
                        color: colors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => openSignIn(context),
            icon: const Icon(Symbols.account_circle),
            label: const Text('Sign in'),
          ),
        ],
      ),
    );
  }
}

/// Avatar, name, @handle · View channel, and email.
/// Updates by itself the moment you sign in or change account.
class _SignedInHeader extends ConsumerWidget {
  const _SignedInHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final profile = ref.watch(myProfileProvider).value;
    final user = ref.watch(authUserProvider).value;
    // Right after signing up, the profile can take a moment to arrive:
    // use the account's own name / email meanwhile.
    final name =
        profile?.displayName ??
        user?.displayName ??
        user?.email?.split('@').first ??
        '';
    final meta = AppTextStyles.meta.copyWith(
      color: colors.textSecondary,
      fontSize: 13,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          ChannelAvatar(
            name: name,
            imageUrl: profile?.avatarUrl ?? '',
            color: profile?.avatarColorValue,
            size: 64,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.sectionHeader.copyWith(
                    fontSize: 24,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                GestureDetector(
                  onTap: () => openChannel(
                    context,
                    ref,
                    Channel.idForUser(ref.read(currentUidProvider)),
                  ),
                  child: Text.rich(
                    TextSpan(
                      text: profile == null ? '' : '${profile.handle} · ',
                      children: [
                        TextSpan(
                          text: 'View channel ›',
                          style: TextStyle(color: colors.textPrimary),
                        ),
                      ],
                    ),
                    style: meta,
                  ),
                ),
                if (user?.email != null)
                  Text(
                    user!.email!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: meta,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "3 videos", or '' while loading.
String _videoCount(int? count) => switch (count) {
  null => '',
  1 => '1 video',
  _ => '$count videos',
};

/// The thumbnail of the first video in [playlist] that still exists.
String? _firstThumbnail(Playlist playlist, Map<String, Video> videosById) {
  for (final id in playlist.videoIds) {
    if (videosById[id] case final video?) return video.thumbnailUrl;
  }
  return null;
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.onViewAll, this.onAdd});

  final String title;
  final VoidCallback? onViewAll;

  /// Shows a + button (e.g. "New playlist").
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: AppTextStyles.sectionHeader.copyWith(
                fontSize: 18,
                color: colors.textPrimary,
              ),
            ),
          ),
          if (onAdd != null)
            IconButton(
              tooltip: 'New playlist',
              onPressed: onAdd,
              icon: Icon(Symbols.add, color: colors.textPrimary),
            ),
          if (onViewAll != null)
            OutlinedButton(
              onPressed: onViewAll,
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.textPrimary,
                side: BorderSide(color: colors.divider),
                shape: const StadiumBorder(),
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('View all'),
            ),
        ],
      ),
    );
  }
}

/// A small video card in the History row, with the red "watched" bar.
class _HistoryCard extends ConsumerWidget {
  const _HistoryCard({required this.item});

  final ListedVideo item;

  static const double width = 150;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final Video video = item.video;

    return GestureDetector(
      onTap: () => video.isShort
          ? context.go('/shorts?v=${video.id}')
          : ref.read(playerPanelProvider.notifier).open(video.id),
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    NetworkThumbnail(url: video.thumbnailUrl),
                    if (video.durationSeconds > 0)
                      Positioned(
                        right: 4,
                        bottom: 7,
                        child: DurationBadge(duration: video.duration),
                      ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 3,
                      child: LinearProgressIndicator(
                        value: item.progress ?? 0,
                        backgroundColor: Colors.white38,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              video.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.videoTitle.copyWith(
                fontSize: 13,
                color: colors.textPrimary,
              ),
            ),
            Text(
              video.channelName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.meta.copyWith(color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// A playlist card (Liked videos, Watch later or one of mine): first
/// video's thumbnail (or a grey box), the name and a subtitle.
class _PlaylistCard extends StatelessWidget {
  const _PlaylistCard({
    super.key,
    required this.title,
    required this.icon,
    required this.thumbnailUrl,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final String? thumbnailUrl;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 150,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (thumbnailUrl != null)
                      NetworkThumbnail(url: thumbnailUrl!)
                    else
                      ColoredBox(color: colors.surface),
                    // Dark strip with the icon, like YouTube's playlist cards.
                    Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        width: 52,
                        color: Colors.black54,
                        alignment: Alignment.center,
                        child: Icon(icon, color: Colors.white, size: 22),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.videoTitle.copyWith(
                fontSize: 13,
                color: colors.textPrimary,
              ),
            ),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.meta.copyWith(color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// A short grey message inside a horizontal row (empty / error).
class _RowMessage extends StatelessWidget {
  const _RowMessage(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        text,
        style: AppTextStyles.body.copyWith(color: context.colors.textSecondary),
      ),
    );
  }
}

/// Grey shimmering cards while the History row loads.
class _CardRowSkeleton extends StatelessWidget {
  const _CardRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return Skeleton(
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: 3,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) => const SizedBox(
          width: _HistoryCard.width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(aspectRatio: 16 / 9, child: SkeletonBox(radius: 12)),
              SizedBox(height: 6),
              SkeletonBox(width: 130, height: 12),
              SizedBox(height: 4),
              SkeletonBox(width: 90, height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
