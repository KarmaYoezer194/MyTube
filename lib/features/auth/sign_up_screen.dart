import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_colors.dart';
import '../../data/repositories/auth_repository.dart';
import 'auth_errors.dart';
import 'widgets/auth_widgets.dart';

enum _Busy { none, email, google }

/// "Create your MyTube account": name, email, password, confirm password.
///
/// A guest who signs up KEEPS everything (history, likes, uploads): the
/// new login is linked to their existing guest user.
/// Closes with `true` when you're signed in.
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  _Busy _busy = _Busy.none;
  String? _error;

  /// After the first "Create account" tap, fields re-check as you type.
  AutovalidateMode _autovalidate = AutovalidateMode.disabled;

  bool get _isBusy => _busy != _Busy.none;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _finish(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
    Navigator.of(context).pop(true);
  }

  void _showError(Object error) {
    debugPrint('AUTH ERROR: $error');
    if (!mounted) return;
    setState(() {
      _busy = _Busy.none;
      _error = friendlyAuthError(error);
    });
  }

  Future<void> _createAccount() async {
    setState(() {
      _error = null;
      _autovalidate = AutovalidateMode.onUserInteraction;
    });
    if (!_form.currentState!.validate()) return;

    setState(() => _busy = _Busy.email);
    try {
      final name = _name.text.trim();
      final outcome = await ref
          .read(authRepositoryProvider)
          .signUpWithEmail(
            name: name,
            email: _email.text.trim(),
            password: _password.text,
          );
      if (!mounted) return;
      _finish(
        outcome == AuthOutcome.linked
            ? 'Welcome to MyTube, $name! Everything you did as a guest was '
                  'kept.'
            : 'You already had an account with this email, so we signed you '
                  'in.',
      );
    } catch (error) {
      _showError(error);
    }
  }

  /// Google pop-up, started IMMEDIATELY (Chrome blocks delayed pop-ups).
  Future<void> _continueWithGoogle() async {
    final signingIn = ref.read(authRepositoryProvider).signInWithGoogle();
    setState(() {
      _busy = _Busy.google;
      _error = null;
    });
    try {
      final outcome = await signingIn;
      if (!mounted) return;
      final user = ref.read(authRepositoryProvider).currentUser;
      final name = user?.displayName ?? user?.email ?? '';
      _finish(
        outcome == AuthOutcome.linked
            ? 'Welcome to MyTube, $name! Everything you did as a guest was '
                  'kept.'
            : 'This Google account already had a MyTube account, so you\'re '
                  'now signed in to it.',
      );
    } catch (error) {
      _showError(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: _isBusy ? null : () => Navigator.of(context).pop(false),
          icon: const Icon(Symbols.arrow_back),
        ),
      ),
      body: SafeArea(
        child: AutofillGroup(
          child: Form(
            key: _form,
            autovalidateMode: _autovalidate,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              children: [
                const AuthHeader(
                  title: 'Create your account',
                  subtitle: 'Your history and likes are kept when you sign up',
                ),
                const SizedBox(height: 32),
                AuthTextField(
                  controller: _name,
                  label: 'Name',
                  enabled: !_isBusy,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.name],
                  validator: AuthValidators.name,
                ),
                const SizedBox(height: 16),
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
                  newPassword: true,
                  validator: AuthValidators.password,
                ),
                const SizedBox(height: 16),
                PasswordField(
                  controller: _confirm,
                  label: 'Confirm password',
                  enabled: !_isBusy,
                  newPassword: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _createAccount(),
                  validator: (value) {
                    if ((value ?? '').isEmpty) {
                      return 'Type your password again';
                    }
                    if (value != _password.text) {
                      return "Passwords don't match";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'Use at least 6 characters.',
                  style: TextStyle(color: colors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 20),
                if (_error != null) ...[
                  AuthMessageBox(text: _error!),
                  const SizedBox(height: 16),
                ],
                AuthPrimaryButton(
                  label: 'Create account',
                  loading: _busy == _Busy.email,
                  onPressed: _isBusy ? null : _createAccount,
                ),
                const SizedBox(height: 20),
                const OrDivider(),
                const SizedBox(height: 20),
                GoogleButton(
                  loading: _busy == _Busy.google,
                  onPressed: _isBusy ? null : _continueWithGoogle,
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an account?',
                      style: TextStyle(color: colors.textSecondary),
                    ),
                    TextButton(
                      onPressed: _isBusy
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: const Text('Sign in'),
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
