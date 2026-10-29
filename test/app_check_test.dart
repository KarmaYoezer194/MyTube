import 'package:flutter_test/flutter_test.dart';
import 'package:mytube/core/security/app_check.dart';

void main() {
  const token = '123e4567-e89b-42d3-a456-426614174000';

  group('chooseAppCheckMode', () {
    test('off without a token or key', () {
      expect(
        chooseAppCheckMode(debugToken: '', siteKey: '', isRelease: false),
        AppCheckMode.off,
      );
      expect(
        chooseAppCheckMode(debugToken: ' ', siteKey: ' ', isRelease: true),
        AppCheckMode.off,
      );
    });

    test('local runs prefer the debug token', () {
      expect(
        chooseAppCheckMode(debugToken: token, siteKey: 'key', isRelease: false),
        AppCheckMode.debug,
      );
    });

    test('release builds never use the debug token', () {
      expect(
        chooseAppCheckMode(debugToken: token, siteKey: 'key', isRelease: true),
        AppCheckMode.recaptcha,
      );
      expect(
        chooseAppCheckMode(debugToken: token, siteKey: '', isRelease: true),
        AppCheckMode.off,
      );
    });

    test('reCAPTCHA when only the site key is given', () {
      expect(
        chooseAppCheckMode(debugToken: '', siteKey: 'key', isRelease: false),
        AppCheckMode.recaptcha,
      );
    });
  });

  test('looksLikeDebugToken', () {
    expect(looksLikeDebugToken(token), isTrue);
    expect(looksLikeDebugToken(' $token '), isTrue);
    expect(looksLikeDebugToken('not-a-token'), isFalse);
    expect(looksLikeDebugToken(''), isFalse);
  });
}
