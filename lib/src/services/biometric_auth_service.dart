import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

abstract class BiometricAuthService {
  Future<bool> canAuthenticate();

  Future<bool> authenticate({required String reason});

  Future<void> stopAuthentication();
}

class DeviceBiometricAuthService implements BiometricAuthService {
  DeviceBiometricAuthService({LocalAuthentication? localAuthentication})
    : _localAuthentication = localAuthentication ?? LocalAuthentication();

  final LocalAuthentication _localAuthentication;

  @override
  Future<bool> canAuthenticate() async {
    try {
      final bool deviceSupported = await _localAuthentication
          .isDeviceSupported();
      final bool canCheckBiometrics =
          await _localAuthentication.canCheckBiometrics;
      final List<BiometricType> available = await _localAuthentication
          .getAvailableBiometrics();
      return (deviceSupported || canCheckBiometrics) && available.isNotEmpty;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<bool> authenticate({required String reason}) async {
    try {
      final bool supported = await canAuthenticate();
      if (!supported) {
        return false;
      }
      return await _localAuthentication.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          sensitiveTransaction: true,
          useErrorDialogs: true,
        ),
      );
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<void> stopAuthentication() async {
    try {
      await _localAuthentication.stopAuthentication();
    } on PlatformException {
      // Ignore platform failures while cancelling auth.
    } on MissingPluginException {
      // Ignore missing plugin on unsupported test/device environments.
    }
  }
}

class MemoryBiometricAuthService implements BiometricAuthService {
  MemoryBiometricAuthService({
    this.supported = true,
    this.authenticationResult = true,
  });

  bool supported;
  bool authenticationResult;

  @override
  Future<bool> canAuthenticate() async => supported;

  @override
  Future<bool> authenticate({required String reason}) async {
    return supported && authenticationResult;
  }

  @override
  Future<void> stopAuthentication() async {}
}
