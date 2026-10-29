import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/shared_preferences_provider.dart';
import '../../data/models/video.dart';

/// Your last 10 searches, newest first. Saved in the browser
/// (SharedPreferences), so they survive a reload but stay on this device.
class RecentSearchesController extends Notifier<List<String>> {
  static const _key = 'recent_searches';
  static const _max = 10;

  @override
  List<String> build() =>
      ref.watch(sharedPreferencesProvider).getStringList(_key) ?? const [];

  void add(String query) {
    final q = query.trim();
    if (q.isEmpty) return;
    // Move it to the top if it was already there.
    _save([q, ...state.where((s) => s.toLowerCase() != q.toLowerCase())]
        .take(_max)
        .toList());
  }

  void remove(String query) => _save(state.where((s) => s != query).toList());

  void _save(List<String> list) {
    state = list;
    ref.read(sharedPreferencesProvider).setStringList(_key, list);
  }
}

final recentSearchesProvider =
    NotifierProvider<RecentSearchesController, List<String>>(
  RecentSearchesController.new,
);

/// Up to 8 video titles / channel names containing what you typed.
List<String> searchSuggestions(List<Video> videos, String typed) {
  final q = typed.trim().toLowerCase();
  if (q.isEmpty) return const [];
  final seen = <String>{};
  final out = <String>[];
  for (final v in videos) {
    if (v.isUnlisted) continue;
    for (final text in [v.title, v.channelName]) {
      if (text.toLowerCase().contains(q) && seen.add(text.toLowerCase())) {
        out.add(text);
      }
    }
    if (out.length >= 8) break;
  }
  return out.take(8).toList();
}

/// Videos matching ALL the words you typed (in the title, channel,
/// category or description). Videos whose title contains the whole query
/// come first.
List<Video> searchVideos(List<Video> videos, String query) {
  final q = query.trim().toLowerCase();
  final words = q.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return const [];

  final matches = videos.where((v) {
    if (v.isUnlisted) return false;
    final haystack =
        '${v.title} ${v.channelName} ${v.category} ${v.description}'
            .toLowerCase();
    return words.every(haystack.contains);
  }).toList();

  bool inTitle(Video v) => v.title.toLowerCase().contains(q);
  return [...matches.where(inTitle), ...matches.where((v) => !inTitle(v))];
}
