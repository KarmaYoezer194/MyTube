import 'package:flutter_riverpod/flutter_riverpod.dart';

// Picks the web version in Chrome and the stub everywhere else.
import 'online_status_stub.dart'
    if (dart.library.js_interop) 'online_status_web.dart' as platform;

/// true while the device has an internet connection.
/// Used to show the "You're offline" bar.
final isOnlineProvider = StreamProvider<bool>((ref) async* {
  yield platform.isOnlineNow();
  yield* platform.onlineChanges();
});
