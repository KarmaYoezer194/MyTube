import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/shared_preferences_provider.dart';
import '../../data/models/video.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/repositories/video_repository.dart';
import 'recommendations.dart';

/// A set of ids saved in this browser (survives a reload).
class _SavedIdsController extends Notifier<Set<String>> {
  _SavedIdsController(this._key);

  final String _key;

  /// Keep the list small.
  static const int _max = 300;

  @override
  Set<String> build() =>
      (ref.watch(sharedPreferencesProvider).getStringList(_key) ?? const [])
          .toSet();

  void hide(String id) => _save({...state, id});

  void undo(String id) => _save({...state}..remove(id));

  void clear() => _save(const {});

  void _save(Set<String> ids) {
    final list = ids.toList();
    final kept = list.length > _max ? list.sublist(list.length - _max) : list;
    state = kept.toSet();
    ref.read(sharedPreferencesProvider).setStringList(_key, kept);
  }
}

/// Videos hidden with "Not interested" (Home, Explore, search, Up next).
class NotInterestedController extends _SavedIdsController {
  NotInterestedController() : super('hidden_videos');
}

/// Channels hidden with "Don't recommend channel".
class HiddenChannelsController extends _SavedIdsController {
  HiddenChannelsController() : super('hidden_channels');
}

final notInterestedProvider =
    NotifierProvider<NotInterestedController, Set<String>>(
      NotInterestedController.new,
    );

final hiddenChannelsProvider =
    NotifierProvider<HiddenChannelsController, Set<String>>(
      HiddenChannelsController.new,
    );

/// My taste, from data the app already has: history, subscriptions and
/// what I hid. Used for "Recommended for you" and "Up next".
final tasteProfileProvider = Provider<TasteProfile>((ref) {
  final history = ref.watch(historyEntriesProvider).value ?? const [];
  final watchedIds = {for (final entry in history) entry.videoId};
  final videos = ref.watch(allVideosProvider).value ?? const <Video>[];
  return TasteProfile(
    watchedIds: watchedIds,
    categoryCounts: countCategories(
      videos.where((v) => watchedIds.contains(v.id)),
    ),
    subscribedChannelIds: (ref.watch(subscribedIdsProvider).value ?? const [])
        .toSet(),
    hiddenVideoIds: ref.watch(notInterestedProvider),
    hiddenChannelIds: ref.watch(hiddenChannelsProvider),
  );
});
