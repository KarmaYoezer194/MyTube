import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_colors.dart';
import 'sign_in_screen.dart';

/// Why a guest is being asked to sign in. Each has its own YouTube-style
/// title, message and icon.
enum SignInReason {
  like(
    Symbols.thumb_up,
    'Like this video?',
    'Sign in to make your opinion count.',
  ),
  dislike(
    Symbols.thumb_down,
    "Don't like this video?",
    'Sign in to make your opinion count.',
  ),
  comment(
    Symbols.comment,
    'Want to join the conversation?',
    'Sign in to comment on videos.',
  ),
  likeComment(
    Symbols.thumb_up,
    'Like this comment?',
    'Sign in to make your opinion count.',
  ),
  subscribe(
    Symbols.subscriptions,
    'Want to subscribe to this channel?',
    'Sign in to subscribe to this channel.',
  ),
  save(
    Symbols.schedule,
    'Want to watch this again later?',
    'Sign in to add this video to Watch later.',
  ),
  upload(
    Symbols.add_circle,
    'Want to share your own videos?',
    'Sign in to upload videos and Shorts.',
  );

  const SignInReason(this.icon, this.title, this.message);

  final IconData icon;
  final String title;
  final String message;
}

/// Shows the "Sign in to …" bottom sheet. If the guest taps Sign in, opens
/// the Sign in page. Returns true if they ended up signed in.
///
/// Everything opens ON TOP of the current screen, so when it closes the
/// guest is back exactly where they were (same video, same sheet).
Future<bool> showSignInPrompt(BuildContext context, SignInReason reason) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final wantsToSignIn = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    builder: (_) => _SignInPromptSheet(reason: reason),
  );
  if (!(wantsToSignIn ?? false)) return false;
  return openSignInWith(navigator);
}

class _SignInPromptSheet extends StatelessWidget {
  const _SignInPromptSheet({required this.reason});

  final SignInReason reason;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(reason.icon, size: 32, color: colors.textPrimary),
            const SizedBox(height: 16),
            Text(
              reason.title,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              reason.message,
              style: TextStyle(color: colors.textSecondary, fontSize: 15),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Sign in'),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context, false),
                style: TextButton.styleFrom(
                  foregroundColor: colors.textPrimary,
                ),
                child: const Text('Not now'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
