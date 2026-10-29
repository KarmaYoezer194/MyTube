import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

/// How App Check proves to Firebase that requests come from THIS app
/// (and not from a script that copied our public Firebase config).
enum AppCheckMode {
  /// App Check is not started (no key or token given). Fine while
  /// "Enforce" is OFF in the Firebase console.
  off,

  /// Local runs: a debug token that you registered in the console.
  debug,

  /// A published site: invisible reCAPTCHA v3 (free).
  recaptcha,
}

/// The two settings come from `--dart-define-from-file=app_check.local.json`
/// (see app_check.example.json and docs/SECURITY_SETUP.md). That file is
/// git-ignored, so the debug token is never committed.
const String appCheckDebugToken = String.fromEnvironment(
  'APP_CHECK_DEBUG_TOKEN',
);
const String recaptchaSiteKey = String.fromEnvironment('RECAPTCHA_SITE_KEY');

/// Picks the App Check mode.
///
/// - Debug/profile builds prefer the debug token (reCAPTCHA doesn't trust
///   `localhost` unless you add it as a domain).
/// - Release builds NEVER use a debug token, only reCAPTCHA.
AppCheckMode chooseAppCheckMode({
  required String debugToken,
  required String siteKey,
  required bool isRelease,
}) {
  if (!isRelease && debugToken.trim().isNotEmpty) return AppCheckMode.debug;
  if (siteKey.trim().isNotEmpty) return AppCheckMode.recaptcha;
  return AppCheckMode.off;
}

/// Debug tokens made by the Firebase console look like a UUID:
/// `123e4567-e89b-42d3-a456-426614174000`.
bool looksLikeDebugToken(String token) => RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
).hasMatch(token.trim());

/// Starts App Check. Call it right after `Firebase.initializeApp` and
/// before anything talks to Firestore or Auth.
///
/// Never throws: if App Check can't start, the app still runs (and works
/// as long as enforcement is off in the console).
Future<AppCheckMode> activateAppCheck() async {
  final mode = chooseAppCheckMode(
    debugToken: appCheckDebugToken,
    siteKey: recaptchaSiteKey,
    isRelease: kReleaseMode,
  );
  try {
    switch (mode) {
      case AppCheckMode.off:
        debugPrint(
          'APP CHECK: off (no APP_CHECK_DEBUG_TOKEN or RECAPTCHA_SITE_KEY). '
          'Run with --dart-define-from-file=app_check.local.json to turn it on.',
        );
      case AppCheckMode.debug:
        if (!looksLikeDebugToken(appCheckDebugToken)) {
          debugPrint(
            'APP CHECK: the debug token does not look like the one the '
            'Firebase console makes (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx).',
          );
        }
        await FirebaseAppCheck.instance.activate(
          providerWeb: WebDebugProvider(debugToken: appCheckDebugToken.trim()),
        );
        debugPrint('APP CHECK: on (debug token)');
      case AppCheckMode.recaptcha:
        await FirebaseAppCheck.instance.activate(
          providerWeb: ReCaptchaV3Provider(recaptchaSiteKey.trim()),
        );
        debugPrint('APP CHECK: on (reCAPTCHA v3)');
    }
  } catch (error) {
    debugPrint('APP CHECK: could not start: $error');
  }
  return mode;
}
