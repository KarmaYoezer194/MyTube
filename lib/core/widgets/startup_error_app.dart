import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/app_theme.dart';
import 'empty_state.dart';
import 'phone_frame.dart';

/// Shown instead of the app when Firebase can't start or sign in.
class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MyTube',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      builder: (context, child) =>
          PhoneFrame(child: child ?? const SizedBox.shrink()),
      home: Scaffold(
        body: EmptyState(
          icon: Symbols.cloud_off,
          title: "Couldn't connect to Firebase",
          message:
              'Check your internet connection and that Anonymous '
              'sign-in is enabled in the Firebase Console '
              '(Authentication → Sign-in method).\n\nDetails: $error',
        ),
      ),
    );
  }
}
