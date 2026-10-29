import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../core/utils/browser_audio.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/repositories/video_repository.dart';
import '../mini_player/player_panel_provider.dart';

/// Thrown when a video has no link or the link can't be played.
class VideoUnavailableException implements Exception {
  const VideoUnavailableException(this.url);
  final String url;

  @override
  String toString() => 'Video unavailable: $url';
}

/// Is the sound off? Shared by the watch page, mini player and Shorts.
///
/// Sound is ON by default. Chrome allows sound once you have clicked
/// something on the page, and in MyTube a video only starts after a tap
/// (on a video or the Shorts tab), so that's normally already true.
/// Only if you haven't clicked anything yet do we start muted (Chrome would
/// refuse to play otherwise) and show "Tap to unmute".
/// Whatever you choose with the 🔇/🔊 button stays for the next videos.
class PlayerMutedController extends Notifier<bool> {
  @override
  bool build() => !canPlaySoundNow();

  void setMuted(bool muted) => state = muted;
}

final playerMutedProvider =
    NotifierProvider<PlayerMutedController, bool>(PlayerMutedController.new);

/// Playback speed (0.25x - 2x), kept for the next videos too.
class PlaybackSpeedController extends Notifier<double> {
  @override
  double build() => 1.0;

  void setSpeed(double speed) => state = speed;
}

final playbackSpeedProvider =
    NotifierProvider<PlaybackSpeedController, double>(
  PlaybackSpeedController.new,
);

/// THE video player of the app.
///
/// There is only one, shared by the watch page and the mini player, so the
/// video keeps playing when you shrink the page or switch tabs.
///
/// It follows the player panel: when the panel's video changes, the old
/// player is thrown away and a new one is loaded. When the panel closes,
/// the value becomes null.
class PlaybackController extends AsyncNotifier<VideoPlayerController?> {
  @override
  Future<VideoPlayerController?> build() async {
    final videoId = ref.watch(playerPanelProvider.select((p) => p.videoId));
    if (videoId == null) return null;

    // `read`, not `watch`: we only want to reload when the video id changes,
    // not every time the video's view count changes in Firestore.
    final video = await ref.read(videoProvider(videoId).future);
    final url = video?.videoUrl ?? '';
    if (video == null || url.isEmpty) {
      throw VideoUnavailableException(url);
    }

    // Ask Firestore where you stopped last time, while the video loads.
    final userRepository = ref.read(userRepositoryProvider);
    // At most 3 seconds: on a slow connection, starting from 0:00 is better
    // than a spinner that never stops.
    final resumeFuture = userRepository
        .getHistoryPosition(video.id)
        .timeout(const Duration(seconds: 3))
        .then<int?>((seconds) => seconds, onError: (Object _) => null);

    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    ref.onDispose(() {
      controller.pause();
      // Dispose after the current frame, so the screen never tries to draw
      // a player that is already gone.
      WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    });

    try {
      await controller.initialize();
    } catch (error) {
      debugPrint('VIDEO UNAVAILABLE (${video.id}): $url\n$error');
      throw VideoUnavailableException(url);
    }
    // You may have tapped another video while this one was loading.
    if (!ref.mounted) return null;

    await controller.setVolume(ref.read(playerMutedProvider) ? 0 : 1);
    await controller.setPlaybackSpeed(ref.read(playbackSpeedProvider));
    ref.listen(playerMutedProvider, (_, muted) {
      controller.setVolume(muted ? 0 : 1);
    });
    ref.listen(playbackSpeedProvider, (_, speed) {
      controller.setPlaybackSpeed(speed);
    });

    // Save the length ONLY if Firestore doesn't have one yet (0).
    // Never overwrite a known length: the first time Cloudinary converts a
    // video it streams it while converting, and the browser can't see the
    // full length yet, so its number can be wrong.
    final seconds = controller.value.duration.inSeconds;
    if (seconds > 0 && video.durationSeconds == 0) {
      ref
          .read(videoRepositoryProvider)
          .updateDuration(video.id, seconds)
          .catchError((Object e) => debugPrint('Saving duration failed: $e'));
    }

    // ---- Resume where you left off ----
    // (Not if you were in the first 5 seconds or the last 10.)
    final resumeAt = await resumeFuture;
    if (!ref.mounted) return null;
    if (resumeAt != null && resumeAt > 5 && resumeAt < seconds - 10) {
      await controller.seekTo(Duration(seconds: resumeAt));
    }

    // ---- Watch history ----
    // Saved now, every 10 seconds while playing, and when you leave.
    void saveProgress() {
      if (!controller.value.isInitialized) return;
      userRepository
          .saveHistory(video.id, controller.value.position.inSeconds)
          .catchError((Object e) => debugPrint('Saving history failed: $e'));
    }

    final historyTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (controller.value.isPlaying) saveProgress();
    });
    ref.onDispose(() {
      historyTimer.cancel();
      saveProgress();
    });
    saveProgress();

    await controller.play();

    // ---- +1 view ----
    ref
        .read(videoRepositoryProvider)
        .incrementViews(video.id)
        .catchError((Object e) => debugPrint('Counting view failed: $e'));

    return controller;
  }
}

final playbackProvider =
    AsyncNotifierProvider<PlaybackController, VideoPlayerController?>(
  PlaybackController.new,
  // Riverpod normally retries failed providers. A broken video link won't
  // fix itself, so we show "Video unavailable" with a Retry button instead.
  retry: (retryCount, error) => null,
);

/// The ready player, or null while loading / on error / when closed.
/// (Never returns a player that is being replaced.)
VideoPlayerController? readyController(
  AsyncValue<VideoPlayerController?> playback,
) {
  return switch (playback) {
    AsyncData(:final value) => value,
    _ => null,
  };
}
