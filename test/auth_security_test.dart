import 'package:flutter_test/flutter_test.dart';

import 'package:freshline_tt/src/data/app_data.dart';
import 'package:freshline_tt/src/services/platform_repository.dart';

void main() {
  test('memory repo keeps email 2FA disabled for sign in', () async {
    final MemoryPlatformRepository repository = MemoryPlatformRepository();

    final SignInAttempt firstSignIn = await repository.beginSignIn(
      role: AppRole.customer,
      email: 'alex@freshline.app',
      password: 'freshline123',
    );

    expect(firstSignIn.requiresEmailOtp, isFalse);
    final AppUser user = firstSignIn.user!;

    await repository.sendEmailTwoFactorSetupCode(user: user);
    final AppUser updatedUser = await repository.enableEmailTwoFactor(
      user: user,
      code: '246810',
    );

    expect(updatedUser.isEmailTwoFactorEnabled, isFalse);

    final SignInAttempt secondSignIn = await repository.beginSignIn(
      role: AppRole.customer,
      email: updatedUser.email,
      password: 'freshline123',
    );

    expect(secondSignIn.requiresEmailOtp, isFalse);
    expect(secondSignIn.user?.email, updatedUser.email);
  });

  test(
    'memory repo lets a new customer sign in immediately and verify email later',
    () async {
      final MemoryPlatformRepository repository = MemoryPlatformRepository();

      final AppUser registeredUser = await repository.registerCustomer(
        name: 'New User',
        email: 'new@freshline.app',
        phone: '+97333334444',
        city: 'Manama',
        password: 'freshline123',
      );

      expect(registeredUser.isEmailVerified, isFalse);

      final SignInAttempt initialSignIn = await repository.beginSignIn(
        role: AppRole.customer,
        email: 'new@freshline.app',
        password: 'freshline123',
      );
      expect(initialSignIn.requiresEmailOtp, isFalse);
      expect(initialSignIn.user?.email, 'new@freshline.app');

      await repository.sendEmailVerificationCode(email: 'new@freshline.app');
      await repository.verifyEmailAddressCode(
        email: 'new@freshline.app',
        code: '246810',
      );

      final SignInAttempt signInAttempt = await repository.beginSignIn(
        role: AppRole.customer,
        email: 'new@freshline.app',
        password: 'freshline123',
      );

      expect(signInAttempt.requiresEmailOtp, isFalse);
      expect(signInAttempt.user?.isEmailVerified, isTrue);
    },
  );

  test('memory repo resets password with a 6-digit email code', () async {
    final MemoryPlatformRepository repository = MemoryPlatformRepository();

    await repository.sendPasswordResetCode(email: 'alex@freshline.app');
    await repository.resetPasswordWithCode(
      email: 'alex@freshline.app',
      code: '246810',
      newPassword: 'newpass123',
    );

    final SignInAttempt signInAttempt = await repository.beginSignIn(
      role: AppRole.customer,
      email: 'alex@freshline.app',
      password: 'newpass123',
    );

    expect(signInAttempt.requiresEmailOtp, isFalse);
    expect(signInAttempt.user?.email, 'alex@freshline.app');
  });
}
