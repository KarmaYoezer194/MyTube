import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/app_user.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/channel_repository.dart';
import '../../data/repositories/user_repository.dart';
import 'sign_in_prompt.dart';

export 'sign_in_prompt.dart' show SignInReason;

/// Liking, commenting, subscribing, saving and uploading need a real
/// account. Guests (anonymous users) can only watch.
///
/// Quick check, no waiting: true if signed in. For a guest it shows the
/// "Sign in to …" sheet for [reason] and returns false (so the action
/// doesn't happen; after signing in they're back on the same screen and
/// can tap again).
///
/// Being instant matters for uploads: the file picker may only open
/// straight after a click.
bool checkSignedIn(
  BuildContext context,
  WidgetRef ref, {
  required SignInReason reason,
}) {
  if (ref.read(isSignedInProvider)) return true;
  showSignInPrompt(context, reason);
  return false;
}

/// Your profile (name, @handle, avatar color) - needed to comment and
/// upload. Returns null for guests (after showing the sign-in sheet) or
/// if the database can't be reached.
///
/// If you're signed in but have no profile yet (e.g. your very first
/// Google sign-in), one is made from your account's name.
Future<AppUser?> requireAccount(
  BuildContext context,
  WidgetRef ref, {
  required SignInReason reason,
}) async {
  if (!checkSignedIn(context, ref, reason: reason)) return null;
  return loadMyProfile(context, ref);
}

/// Reads (or creates) the signed-in user's profile. See [requireAccount].
Future<AppUser?> loadMyProfile(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final repository = ref.read(userRepositoryProvider);
  try {
    // Read straight from Firestore (not through a provider: in Riverpod 3
    // an unwatched provider is paused and its future would never finish).
    var profile = await repository.getProfile().timeout(
      const Duration(seconds: 10),
    );
    if (profile == null) {
      final user = ref.read(authRepositoryProvider).currentUser;
      final name = (user?.displayName?.trim().isNotEmpty ?? false)
          ? user!.displayName!
          : (user?.email?.split('@').first ?? 'MyTube user');
      profile = await repository
          .saveProfile(name)
          .timeout(const Duration(seconds: 10));
    }
    return await _withChannel(ref, profile);
  } catch (error) {
    debugPrint('PROFILE: could not load your profile: $error');
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          "Can't reach the database. Check your internet "
          'connection and try again.',
        ),
      ),
    );
    return null;
  }
}

/// Makes sure the account has its channel (older accounts don't yet).
/// Creating it can give a new @handle (if the old one was taken), so the
/// returned profile always has the channel's handle.
Future<AppUser> _withChannel(WidgetRef ref, AppUser profile) async {
  try {
    final channel = await ref
        .read(channelRepositoryProvider)
        .ensureMyChannel(profile)
        .timeout(const Duration(seconds: 10));
    if (channel.handle == profile.handle) return profile;
    return AppUser(
      uid: profile.uid,
      displayName: profile.displayName,
      handle: channel.handle,
      avatarUrl: profile.avatarUrl,
      avatarColor: profile.avatarColor,
      createdAt: profile.createdAt,
    );
  } catch (error) {
    debugPrint('CHANNEL: could not set up your channel: $error');
    return profile;
  }
}
