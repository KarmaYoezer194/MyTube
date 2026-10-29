import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Is the browser online right now?
bool isOnlineNow() => web.window.navigator.onLine;

/// true / false every time the browser goes online / offline.
Stream<bool> onlineChanges() {
  late final StreamController<bool> controller;
  final onOnline = ((web.Event _) => controller.add(true)).toJS;
  final onOffline = ((web.Event _) => controller.add(false)).toJS;

  controller = StreamController<bool>(
    onListen: () {
      web.window.addEventListener('online', onOnline);
      web.window.addEventListener('offline', onOffline);
    },
    onCancel: () {
      web.window.removeEventListener('online', onOnline);
      web.window.removeEventListener('offline', onOffline);
    },
  );
  return controller.stream;
}
