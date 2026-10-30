import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/app_notification.dart';
import '../../data/repositories/notification_repository.dart';
import '../../data/repositories/user_repository.dart';

/// My newest notifications (live). Guests have none: notifications are
/// sent to accounts only.
final notificationsProvider = StreamProvider<List<AppNotification>>((ref) {
  if (!ref.watch(isSignedInProvider)) return Stream.value(const []);
  return ref.watch(notificationRepositoryProvider).watchMine();
});

/// Number for the red badge on the bell: unread among the newest
/// [NotificationRepository.listLimit].
final unreadNotificationsCountProvider = Provider<int>(
  (ref) => unreadCount(ref.watch(notificationsProvider).value ?? const []),
);

int unreadCount(Iterable<AppNotification> notifications) =>
    notifications.where((n) => !n.read).length;
