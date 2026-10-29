import 'package:firebase_auth/firebase_auth.dart';

/// Turns a Firebase sign-in error into a short message anyone understands.
/// Returns null when there is nothing to show (e.g. you closed the Google
/// pop-up yourself).
String? friendlyAuthError(Object error) {
  if (error is! FirebaseAuthException) {
    return 'Something went wrong. Please try again.';
  }
  switch (error.code) {
    case 'invalid-email':
      return 'That email address doesn\'t look right.';
    case 'missing-password':
      return 'Please enter your password.';
    case 'weak-password':
      return 'Use at least 6 characters for your password.';
    case 'email-already-in-use':
    case 'credential-already-in-use':
      return 'This email already has an account. Sign in instead.';
    case 'user-not-found':
    case 'wrong-password':
    case 'invalid-credential':
    case 'invalid-login-credentials':
      // Firebase doesn't say which one is wrong (on purpose, for safety).
      return 'Wrong email or password.';
    case 'user-disabled':
      return 'This account has been disabled.';
    case 'too-many-requests':
      return 'Too many attempts. Please wait a minute and try again.';
    case 'network-request-failed':
      return 'No internet connection. Check your connection and try again.';
    case 'popup-closed-by-user':
    case 'cancelled-popup-request':
    case 'user-cancelled':
      return null; // You closed the Google window: not an error.
    case 'popup-blocked':
      return 'Your browser blocked the Google window. Allow pop-ups for '
          'this site and try again.';
    case 'operation-not-allowed':
      return 'This sign-in method is turned off in the Firebase Console.';
    case 'unauthorized-domain':
      return 'This website address isn\'t allowed to use Google sign-in. '
          'Add it in Firebase Console > Authentication > Settings > '
          'Authorized domains.';
    case 'provider-already-linked':
      return 'You\'re already signed in with this method.';
    default:
      return 'Couldn\'t sign in (${error.code}). Please try again.';
  }
}
