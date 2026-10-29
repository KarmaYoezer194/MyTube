import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_colors.dart';
import '../../data/repositories/auth_repository.dart';
import 'auth_errors.dart';
import 'sign_up_screen.dart';
import 'widgets/auth_widgets.dart';

/// Opens the Sign in page on top of everything (tabs, player, nav).
/// When you finish, it closes and you're back exactly where you were.
/// Returns true if you signed in.
Future<bool> openSignIn(BuildContext context) {
  return openSignInWith(Navigator.of(context, rootNavigator: true));
}

/// Same as [openSignIn], for when you already have the navigator (e.g.
/// from a snackbar button, after the widget that showed it is gone).
Future<bool> openSignInWith(NavigatorState navigator) async {
  final signedIn = await navigator.push<bool>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const SignInScreen(),
    ),
  );
  return signedIn ?? false;
}

enum _Busy { none, email, google, reset }

/// "Sign in to continue to MyTube": email + password, Forgot password?,
/// Continue with Google, and a link to Create account.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  _Busy _busy = _Busy.none;
  String? _error;
  String? _info;

  bool get _isBusy => _busy != _Busy.none;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Closes the page and says hello.
  void _finish(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
    Navigator.of(context).pop(true);
  }

  String _nameOfCurrentUser() {
    final user = ref.read(authRepositoryProvider).currentUser;
    final name = user?.displayName?.trim() ?? '';
    return name.isNotEmpty ? name : (user?.email ?? '');
  }

  void _showError(Object error) {
    final message = friendlyAuthError(error);
    debugPrint('AUTH ERROR: $error');
    if (!mounted) return;
    setState(() {
      _busy = _Busy.none;
      _error = message;
      _info = null;
    });
  }

  // ---- Email + password ----

  Future<void> _signInWithEmail() async {
    setState(() {
      _error = null;
      _info = null;
    });
    if (!_form.currentState!.validate()) return;

    setState(() => _busy = _Busy.email);
    try {
      await ref
          .read(authRepositoryProvider)
          .signInWithEmail(email: _email.text.trim(), password: _password.text);
      if (mounted) _finish('Welcome back, ${_nameOfCurrentUser()}!');
    } catch (error) {
      _showError(error);
    }
  }

  // ---- Google ----

  /// Starts the Google pop-up IMMEDIATELY (no waiting before it), because
  /// Chrome only allows pop-ups that open straight from a click.
  Future<void> _signInWithGoogle() async {
    final signingIn = ref.read(authRepositoryProvider).signInWithGoogle();
    setState(() {
      _busy = _Busy.google;
      _error = null;
      _info = null;
    });
    try {
      final outcome = await signingIn;
      if (!mounted) return;
      _finish(
        outcome == AuthOutcome.linked
            ? 'Welcome, ${_nameOfCurrentUser()}! Your history and likes were '
                  'kept.'
            : 'Signed in as ${_nameOfCurrentUser()}.',
      );
    } catch (error) {
      _showError(error);
    }
  }

  // ---- Forgot password ----

  Future<void> _forgotPassword() async {
    final emailProblem = AuthValidators.email(_email.text);
    if (emailProblem != null) {
      setState(() {
        _error = 'Type your email above, then tap "Forgot password?" again.';
        _info = null;
      });
      return;
    }
    setState(() {
      _busy = _Busy.reset;
      _error = null;
      _info = null;
    });
    try {
      final email = _email.text.trim();
      await ref.read(authRepositoryProvider).sendPasswordReset(email);
      if (!mounted) return;
      setState(() {
        _busy = _Busy.none;
        // Firebase doesn't reveal whether an account exists (for safety),
        // so we can't say "sent" for sure.
        _info =
            'If $email has a MyTube account, we sent it a link to reset '
            'your password. Check your inbox (and the spam folder).';
      });
    } catch (error) {
      _showError(error);
    }
  }

  // ---- Create account ----

  Future<void> _openSignUp() async {
    final created = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const SignUpScreen()));
    // Signed up (or in) on the next page: close this one too.
    if ((created ?? false) && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Close',
          onPressed: _isBusy ? null : () => Navigator.of(context).pop(false),
          icon: const Icon(Symbols.close),
        ),
      ),
      body: SafeArea(
        child: AutofillGroup(
          child: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              children: [
                const AuthHeader(
                  title: 'Sign in',
                  subtitle: 'to like, comment, subscribe and upload on MyTube',
                ),
                const SizedBox(height: 32),
                AuthTextField(
                  controller: _email,
                  label: 'Email',
                  enabled: !_isBusy,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  validator: AuthValidators.email,
                ),
                const SizedBox(height: 16),
                PasswordField(
                  controller: _password,
                  enabled: !_isBusy,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _signInWithEmail(),
                  validator: (v) =>
                      (v ?? '').isEmpty ? 'Enter your password' : null,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _isBusy ? null : _forgotPassword,
                    child: _busy == _Busy.reset
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Forgot password?'),
                  ),
                ),
                if (_error != null) ...[
                  AuthMessageBox(text: _error!),
                  const SizedBox(height: 16),
                ],
                if (_info != null) ...[
                  AuthMessageBox(text: _info!, isError: false),
                  const SizedBox(height: 16),
                ],
                AuthPrimaryButton(
                  label: 'Sign in',
                  loading: _busy == _Busy.email,
                  onPressed: _isBusy ? null : _signInWithEmail,
                ),
                const SizedBox(height: 20),
                const OrDivider(),
                const SizedBox(height: 20),
                GoogleButton(
                  loading: _busy == _Busy.google,
                  onPressed: _isBusy ? null : _signInWithGoogle,
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'New to MyTube?',
                      style: TextStyle(color: colors.textSecondary),
                    ),
                    TextButton(
                      onPressed: _isBusy ? null : _openSignUp,
                      child: const Text('Create account'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
