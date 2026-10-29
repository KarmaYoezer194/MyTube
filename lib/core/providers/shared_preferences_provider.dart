import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Gives every provider access to SharedPreferences (small key/value storage
/// saved in the browser, used for theme, autoplay and recent searches).
///
/// It is loaded once in main.dart and "overridden" there, because loading it
/// is async and we want it ready before the first screen appears.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in main.dart',
  ),
);
