import 'package:web/web.dart' as web;

/// Chrome only lets a page play sound after you have clicked / tapped
/// something on it. This says whether that has happened yet.
bool canPlaySoundNow() => web.window.navigator.userActivation.hasBeenActive;
