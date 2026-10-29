import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/mytube_logo.dart';

/// Logo + big title + small subtitle at the top of the sign-in pages.
class AuthHeader extends StatelessWidget {
  const AuthHeader({super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      children: [
        const MyTubeLogo(size: 32),
        const SizedBox(height: 24),
        Text(
          title,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.textSecondary, fontSize: 15),
        ),
      ],
    );
  }
}

/// Rounded text field used on the sign-in pages.
class AuthTextField extends StatelessWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    this.validator,
    this.keyboardType,
    this.autofillHints,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    this.enabled = true,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String label;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      autofillHints: autofillHints,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      onFieldSubmitted: onSubmitted,
      validator: validator,
      decoration: authInputDecoration(context, label),
    );
  }
}

/// Password field with an 👁 button to show / hide what you typed.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    this.label = 'Password',
    this.validator,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    this.enabled = true,
    this.newPassword = false,
  });

  final TextEditingController controller;
  final String label;
  final FormFieldValidator<String>? validator;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;

  /// true on the sign-up page (lets the browser suggest a strong password).
  final bool newPassword;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      enabled: widget.enabled,
      obscureText: _hidden,
      autofillHints: [
        widget.newPassword ? AutofillHints.newPassword : AutofillHints.password,
      ],
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onSubmitted,
      validator: widget.validator,
      decoration: authInputDecoration(context, widget.label).copyWith(
        suffixIcon: IconButton(
          tooltip: _hidden ? 'Show password' : 'Hide password',
          onPressed: () => setState(() => _hidden = !_hidden),
          icon: Icon(_hidden ? Symbols.visibility : Symbols.visibility_off),
        ),
      ),
    );
  }
}

InputDecoration authInputDecoration(BuildContext context, String label) {
  final colors = context.colors;
  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: width),
      );
  return InputDecoration(
    labelText: label,
    border: border(colors.divider),
    enabledBorder: border(colors.divider),
    focusedBorder: border(colors.textPrimary, 2),
    errorBorder: border(AppColors.brandRed),
    focusedErrorBorder: border(AppColors.brandRed, 2),
    errorStyle: const TextStyle(color: Color(0xFFFF4E45)),
  );
}

/// Big pill button. While [loading], shows a small spinner and can't be
/// tapped again.
class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          // Keep the normal colors while loading (not the grey "disabled").
          disabledBackgroundColor: colors.chipSelectedBackground.withValues(
            alpha: 0.7,
          ),
          disabledForegroundColor: colors.chipSelectedForeground,
        ),
        child: loading
            ? SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: colors.chipSelectedForeground,
                ),
              )
            : Text(label, style: const TextStyle(fontSize: 15)),
      ),
    );
  }
}

/// "Continue with Google" outlined pill with a multicolored G.
class GoogleButton extends StatelessWidget {
  const GoogleButton({
    super.key,
    required this.onPressed,
    this.loading = false,
  });

  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: loading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.textPrimary,
          side: BorderSide(color: colors.divider),
          shape: const StadiumBorder(),
        ),
        child: loading
            ? SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: colors.textPrimary,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const _GoogleG(),
                  const SizedBox(width: 12),
                  Text(
                    'Continue with Google',
                    style: TextStyle(color: colors.textPrimary, fontSize: 15),
                  ),
                ],
              ),
      ),
    );
  }
}

/// A simple "G" in Google's four colors (no image file needed).
class _GoogleG extends StatelessWidget {
  const _GoogleG();

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => const SweepGradient(
        colors: [
          Color(0xFFEA4335), // red
          Color(0xFFFBBC05), // yellow
          Color(0xFF34A853), // green
          Color(0xFF4285F4), // blue
          Color(0xFFEA4335),
        ],
      ).createShader(bounds),
      child: const Text(
        'G',
        style: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}

/// Thin line with "or" in the middle.
class OrDivider extends StatelessWidget {
  const OrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        Expanded(child: Divider(color: colors.divider)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('or', style: TextStyle(color: colors.textSecondary)),
        ),
        Expanded(child: Divider(color: colors.divider)),
      ],
    );
  }
}

/// Red (error) or blue (info) message box above the main button.
class AuthMessageBox extends StatelessWidget {
  const AuthMessageBox({super.key, required this.text, this.isError = true});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? const Color(0xFFFF4E45) : const Color(0xFF3EA6FF);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(isError ? Symbols.error : Symbols.info, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: context.colors.textPrimary, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

/// Simple checks shared by both pages.
class AuthValidators {
  AuthValidators._();

  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter your email';
    if (!_email.hasMatch(v)) return 'Enter a valid email address';
    return null;
  }

  static String? password(String? value) {
    if ((value ?? '').isEmpty) return 'Enter a password';
    if (value!.length < 6) return 'Use at least 6 characters';
    return null;
  }

  static String? name(String? value) {
    final v = value?.trim() ?? '';
    if (v.length < 2) return 'Enter your name (at least 2 letters)';
    if (v.length > 30) return 'Keep it under 30 characters';
    return null;
  }
}
