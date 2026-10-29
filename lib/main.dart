import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/providers/shared_preferences_provider.dart';
import 'core/router/app_router.dart';
import 'core/security/app_check.dart';
import 'core/theme/app_scroll_behavior.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/phone_frame.dart';
import 'core/widgets/startup_error_app.dart';
import 'data/seed/seed_videos.dart';
import 'features/settings/settings_providers.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final clock = Stopwatch()..start();
  void log(String step) =>
      debugPrint('STARTUP (${clock.elapsedMilliseconds} ms): $step');

  // Small local storage for theme, autoplay and recent searches.
  final prefs = await SharedPreferences.getInstance();
  log('local storage ready');

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    log('Firebase ready');

    // App Check: proves requests come from this app. Must start before
    // anything talks to Firestore or Auth. See docs/SECURITY_SETUP.md.
    final appCheck = await activateAppCheck();
    log('App Check: ${appCheck.name}');

    // Some networks (e.g. university Wi-Fi) break Firestore's normal
    // streaming connection in Chrome (QUIC_NETWORK_IDLE_TIMEOUT / 400 errors
    // in the console). This lets Firestore switch to plain HTTP requests
    // ("long polling") automatically when that happens.
    // (After a hot restart Firestore is already running and the settings
    // can't be changed any more; that's fine, so the error is ignored.)
    if (kIsWeb) {
      try {
        FirebaseFirestore.instance.settings = const Settings(
          webExperimentalAutoDetectLongPolling: true,
        );
      } catch (error) {
        debugPrint('Firestore settings not changed: $error');
      }
    }

    // On web, Firebase needs a moment to restore the user from the last
    // visit. Waiting for the first auth event means we reuse the SAME
    // anonymous user after a page reload instead of making a new one.
    final auth = FirebaseAuth.instance;
    final existingUser = await auth.authStateChanges().first;
    if (existingUser == null) {
      await auth.signInAnonymously();
    }
    log('signed in as ${auth.currentUser?.uid}');
  } catch (error) {
    // Most common cause: Anonymous sign-in is not enabled in the console.
    runApp(StartupErrorApp(error: error));
    return;
  }

  // Show the app NOW. Nothing below may wait for the network, otherwise a
  // slow connection leaves you looking at a white screen.
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const MyTubeApp(),
    ),
  );
  log('app is on screen');

  // First launch only: fill the empty database with the 13 seed videos.
  // Runs in the background; Home shows skeletons until the videos arrive.
  final db = FirebaseFirestore.instance;
  VideoSeeder.seedIfEmpty(db)
      .then((_) => VideoSeeder.seedChannelsIfMissing(db))
      .timeout(const Duration(seconds: 30))
      .then((_) => log('seed check done'))
      .catchError((Object error) => log('seed check failed: $error'));
}

class MyTubeApp extends ConsumerWidget {
  const MyTubeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'MyTube',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ref.watch(themeModeProvider),
      scrollBehavior: const AppScrollBehavior(),
      routerConfig: ref.watch(appRouterProvider),
      // Wrap every screen in the 430px "phone" column.
      builder: (context, child) =>
          PhoneFrame(child: child ?? const SizedBox.shrink()),
    );
  }
}
