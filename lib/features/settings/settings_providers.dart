import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/shared_preferences_provider.dart';

/// Which theme the app uses: device (system), dark or light.
/// Dark is the default. The choice is saved, so it survives a page reload.
class ThemeModeController extends Notifier<ThemeMode> {
  static const _key = 'theme_mode';

  @override
  ThemeMode build() {
    final saved = ref.watch(sharedPreferencesProvider).getString(_key);
    return ThemeMode.values.firstWhere(
      (mode) => mode.name == saved,
      orElse: () => ThemeMode.dark,
    );
  }

  void setMode(ThemeMode mode) {
    state = mode;
    ref.read(sharedPreferencesProvider).setString(_key, mode.name);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);

/// Whether the next video plays automatically when one ends. On by default.
class AutoplayController extends Notifier<bool> {
  static const _key = 'autoplay';

  @override
  bool build() => ref.watch(sharedPreferencesProvider).getBool(_key) ?? true;

  void setEnabled(bool enabled) {
    state = enabled;
    ref.read(sharedPreferencesProvider).setBool(_key, enabled);
  }
}

final autoplayProvider = NotifierProvider<AutoplayController, bool>(
  AutoplayController.new,
);
