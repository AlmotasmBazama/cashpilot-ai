import 'package:cashpilot_ai/features/auth/domain/entities/auth_user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('email users require verification until verified', () {
    const user = AuthUser(
      uid: 'uid',
      email: 'pilot@example.com',
      emailVerified: false,
      isAnonymous: false,
    );

    expect(user.needsEmailVerification, isTrue);
    expect(user.copyWith(emailVerified: true).needsEmailVerification, isFalse);
  });

  test('profile completion requires personalisation fields', () {
    const incomplete = AuthUser(
      uid: 'uid',
      emailVerified: true,
      isAnonymous: false,
      displayName: 'Pilot',
      currency: 'USD',
      language: 'en',
    );

    final complete = incomplete.copyWith(country: 'US', timezone: 'UTC');

    expect(incomplete.isProfileComplete, isFalse);
    expect(complete.isProfileComplete, isTrue);
  });

  test('anonymous users do not require email verification', () {
    const user = AuthUser(
      uid: 'guest',
      emailVerified: false,
      isAnonymous: true,
    );

    expect(user.needsEmailVerification, isFalse);
  });
}
