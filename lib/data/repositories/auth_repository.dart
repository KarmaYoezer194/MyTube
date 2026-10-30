import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';
import 'channel_repository.dart';
import 'user_repository.dart';
import 'video_repository.dart';

/// How a sign-in / sign-up ended.
enum AuthOutcome {
  /// The guest became a real account: same user id, so their watch
  /// history, likes and uploads are kept.
  linked,

  /// Signed in to an account that already existed. The guest's data stays
  /// with the old guest user (it isn't merged).
  switchedToExisting,
}

/// Everything about WHO is using the app.
///
/// There is always a Firebase user:
/// - a GUEST = an anonymous user, created automatically at start-up, so
///   watch history and view counts work without an account;
/// - a SIGNED-IN user = someone with an email/password or Google account.
class AuthRepository {
  AuthRepository(this._auth, this._db);

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  User? get currentUser => _auth.currentUser;

  bool get _isGuest => _auth.currentUser?.isAnonymous ?? true;

  // ---------------- Email + password ----------------

  /// Creates an account. A guest's anonymous user is LINKED to the new
  /// email login (linkWithCredential), so nothing they did is lost.
  ///
  /// If the email already has an account and the password is right, signs
  /// in to it instead; otherwise the 'email-already-in-use' error is
  /// passed on (and shown as a friendly message).
  Future<AuthOutcome> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    final credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );
    AuthOutcome outcome;
    try {
      final guest = _auth.currentUser;
      if (guest != null && guest.isAnonymous) {
        await guest.linkWithCredential(credential);
      } else {
        await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      }
      outcome = AuthOutcome.linked;
    } on FirebaseAuthException catch (e) {
      if (e.code != 'email-already-in-use' &&
          e.code != 'credential-already-in-use') {
        rethrow;
      }
      // The account exists. Same password? Then just sign in to it.
      try {
        await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } on FirebaseAuthException {
        // Wrong password for that existing account: report "already in use".
        throw FirebaseAuthException(code: 'email-already-in-use');
      }
      outcome = AuthOutcome.switchedToExisting;
    }

    final user = _auth.currentUser!;
    final isNewAccount = outcome == AuthOutcome.linked;
    if (isNewAccount) await user.updateDisplayName(name.trim());
    // Only a NEW account takes the name typed in the form; an existing
    // account keeps its own name.
    await _afterSignIn(user, chosenName: isNewAccount ? name : null);
    return outcome;
  }

  /// Signs in to an existing email account. (A guest can't be linked to
  /// an account that already exists, so their guest data stays behind.)
  Future<AuthOutcome> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final wasGuest = _isGuest;
    await _auth.signInWithEmailAndPassword(email: email, password: password);
    await _afterSignIn(_auth.currentUser!);
    return wasGuest ? AuthOutcome.switchedToExisting : AuthOutcome.linked;
  }

  /// Sends Firebase's free "reset your password" email.
  Future<void> sendPasswordReset(String email) {
    return _auth.sendPasswordResetEmail(email: email);
  }

  // ---------------- Google ----------------

  /// "Continue with Google" (web pop-up, no extra package needed).
  ///
  /// A guest is LINKED to their Google account (data kept). If that Google
  /// account is already used by a MyTube account, we sign in to that
  /// account instead of failing.
  ///
  /// Must be called straight from a button tap: Chrome blocks pop-ups that
  /// don't come directly from a click.
  Future<AuthOutcome> signInWithGoogle() async {
    final provider = GoogleAuthProvider()
      ..setCustomParameters({'prompt': 'select_account'});
    AuthOutcome outcome;

    final guest = _auth.currentUser;
    if (guest != null && guest.isAnonymous) {
      try {
        await guest.linkWithPopup(provider);
        outcome = AuthOutcome.linked;
      } on FirebaseAuthException catch (e) {
        const alreadyUsed = {
          'credential-already-in-use',
          'email-already-in-use',
          'account-exists-with-different-credential',
        };
        if (!alreadyUsed.contains(e.code)) rethrow;
        final existing = e.credential;
        if (existing != null) {
          // Firebase hands us the Google login it just made: use it.
          await _auth.signInWithCredential(existing);
        } else {
          await _auth.signInWithPopup(provider);
        }
        outcome = AuthOutcome.switchedToExisting;
      }
    } else {
      await _auth.signInWithPopup(provider);
      outcome = AuthOutcome.switchedToExisting;
    }

    await _afterSignIn(_auth.currentUser!);
    return outcome;
  }

  // ---------------- Sign out ----------------

  /// Signs out and immediately becomes a brand-new guest, so the app keeps
  /// working (history, views) without an account.
  Future<void> signOutToGuest() async {
    await _auth.signOut();
    await _auth.signInAnonymously();
  }

  // ---------------- After any sign-in ----------------

  /// 1. Get a fresh login token: the security rules read the sign-in method
  ///    from it, and right after linking it may still say "anonymous".
  /// 2. Make sure users/{uid} exists with name, @handle and avatar color:
  ///    - sign-up: saves the name you typed ([chosenName]);
  ///    - other sign-ins: keeps your profile, or creates one from your
  ///      Google name / email if you don't have one yet.
  Future<void> _afterSignIn(User user, {String? chosenName}) async {
    await user.reload();
    final fresh = _auth.currentUser ?? user;
    await fresh.getIdToken(true);

    // A repository for THIS user id (the app-wide one may still be
    // switching over from the guest).
    final users = UserRepository(_db, fresh.uid);
    AppUser? profile;
    if (chosenName != null) {
      profile = await users.saveProfile(chosenName);
    } else {
      profile = await users.getProfile();
      if (profile == null) {
        final googleName = fresh.displayName?.trim() ?? '';
        profile = await users.saveProfile(
          googleName.isNotEmpty
              ? googleName
              : (fresh.email?.split('@').first ?? 'MyTube user'),
        );
      }
    }
    // 3. Make sure I have a channel (channels/user-{uid}). Not fatal: it is
    //    tried again before uploading or opening "Your channel".
    try {
      await ChannelRepository(_db, fresh.uid).ensureMyChannel(profile);
    } catch (error) {
      debugPrint('AUTH: could not set up your channel yet: $error');
    }
    // (No email in the log: the browser console is visible to anyone.)
    debugPrint('AUTH: signed in (${fresh.uid})');
  }
}

final firebaseAuthProvider = Provider<FirebaseAuth>(
  (ref) => FirebaseAuth.instance,
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    ref.watch(firebaseAuthProvider),
    ref.watch(firestoreProvider),
  ),
);

/// The current Firebase user, live. `userChanges` also fires when a guest
/// turns into a real account (linking) or their name changes, so every
/// screen updates immediately.
final authUserProvider = StreamProvider<User?>(
  (ref) => ref.watch(firebaseAuthProvider).userChanges(),
);

/// true = signed in with a real account (email or Google).
/// false = a guest (anonymous) - can watch, but not like, comment,
/// subscribe, save or upload.
final isSignedInProvider = Provider<bool>((ref) {
  final user =
      ref.watch(authUserProvider).value ??
      ref.watch(firebaseAuthProvider).currentUser;
  return user != null && !user.isAnonymous;
});

/// The current user's id (guest or signed in). Changes when you sign in to
/// another account or sign out, and every provider that uses it reloads
/// with the new user's data.
final currentUidProvider = Provider<String>((ref) {
  final user =
      ref.watch(authUserProvider).value ??
      ref.watch(firebaseAuthProvider).currentUser;
  // For a split second during sign-out there is no user at all. A
  // placeholder id avoids an invalid Firestore path; reads simply fail
  // until the new guest arrives a moment later.
  return user?.uid ?? '_signed_out';
});
