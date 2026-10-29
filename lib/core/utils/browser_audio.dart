// Picks the web version in Chrome and the stub everywhere else.
export 'browser_audio_stub.dart'
    if (dart.library.js_interop) 'browser_audio_web.dart';
