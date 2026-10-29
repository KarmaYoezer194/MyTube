import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/shared_preferences_provider.dart';
import '../../data/models/video.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/repositories/video_repository.dart';

/// One (fake) notification, made from a video:
/// "Gearhead Garage uploaded: Chasing Rally Cars With an FPV Drone".
class AppNotification {
  const AppNotification({required this.video, required this.text});

  final Video video;
  final String text;

  DateTime get time => video.createdAt;
}

/// When you last opened the notifications list. Anything newer is
/// "unread". Saved in the browser, so the badge stays correct after reload.
class NotificationsSeenController extends Notifier<DateTime?> {
  static const _key = 'notifications_seen_at';

  @override
  DateTime? build() {
    final ms = ref.watch(sharedPreferencesProvider).getInt(_key);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  void markAllSeen() {
    final now = DateTime.now();
    state = now;
    ref
        .read(sharedPreferencesProvider)
        .setInt(_key, now.millisecondsSinceEpoch);
  }
}

final notificationsSeenAtProvider =
    NotifierProvider<NotificationsSeenController, DateTime?>(
      NotificationsSeenController.new,
    );

/// The 8 newest videos from OTHER channels, turned into notifications.
/// (There is no real notification server in this demo.)
final notificationsProvider = Provider<AsyncValue<List<AppNotification>>>((
  ref,
) {
  final myUid = ref.watch(currentUidProvider);
  return ref
      .watch(allVideosProvider)
      .whenData(
        (videos) => videos
            .where((v) => v.uploaderUid != myUid && !v.isUnlisted)
            .take(8)
            .map(
              (v) => AppNotification(
                video: v,
                text: v.isShort
                    ? '${v.channelName} posted a new Short: ${v.title}'
                    : '${v.channelName} uploaded: ${v.title}',
              ),
            )
            .toList(),
      );
});

/// Number for the red badge on the bell.
final unreadNotificationsCountProvider = Provider<int>((ref) {
  final seenAt = ref.watch(notificationsSeenAtProvider);
  final all = ref.watch(notificationsProvider).value ?? const [];
  return all.where((n) => seenAt == null || n.time.isAfter(seenAt)).length;
});
