import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../data/app_data.dart';

abstract class PushNotificationsService {
  Future<void> configureForUser({
    required AppUser user,
    required Future<void> Function(String token) onTokenSync,
    void Function(RemoteMessage message)? onForegroundMessage,
    void Function(RemoteMessage message)? onMessageOpenedApp,
  });

  Future<void> removeCurrentToken({
    required AppUser user,
    required Future<void> Function(String token) onTokenRemove,
  });

  void dispose() {}
}

class NoopPushNotificationsService implements PushNotificationsService {
  const NoopPushNotificationsService();

  @override
  Future<void> configureForUser({
    required AppUser user,
    required Future<void> Function(String token) onTokenSync,
    void Function(RemoteMessage message)? onForegroundMessage,
    void Function(RemoteMessage message)? onMessageOpenedApp,
  }) async {}

  @override
  Future<void> removeCurrentToken({
    required AppUser user,
    required Future<void> Function(String token) onTokenRemove,
  }) async {}

  @override
  void dispose() {}
}

class FirebasePushNotificationsService implements PushNotificationsService {
  FirebasePushNotificationsService({FirebaseMessaging? messaging})
    : _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseMessaging _messaging;
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  Future<void> Function(String token)? _tokenSyncCallback;
  void Function(RemoteMessage message)? _foregroundCallback;
  void Function(RemoteMessage message)? _openedCallback;
  bool _isInitialized = false;

  bool get _isSupportedPlatform {
    if (kIsWeb) {
      return false;
    }
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  @override
  Future<void> configureForUser({
    required AppUser user,
    required Future<void> Function(String token) onTokenSync,
    void Function(RemoteMessage message)? onForegroundMessage,
    void Function(RemoteMessage message)? onMessageOpenedApp,
  }) async {
    if (!_isSupportedPlatform) {
      return;
    }

    final String profileId = user.profileId?.trim() ?? '';
    if (profileId.isEmpty) {
      return;
    }

    _tokenSyncCallback = onTokenSync;
    _foregroundCallback = onForegroundMessage;
    _openedCallback = onMessageOpenedApp;

    try {
      await _messaging.requestPermission(alert: true, badge: true, sound: true);
      await _messaging.setAutoInitEnabled(true);

      if (!_isInitialized) {
        _foregroundSubscription = FirebaseMessaging.onMessage.listen((
          RemoteMessage message,
        ) {
          _foregroundCallback?.call(message);
        });
        _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen((
          RemoteMessage message,
        ) {
          _openedCallback?.call(message);
        });
        _tokenRefreshSubscription = _messaging.onTokenRefresh.listen((
          String token,
        ) {
          final Future<void> Function(String token)? callback =
              _tokenSyncCallback;
          if (callback != null && token.trim().isNotEmpty) {
            unawaited(
              Future<void>(() async {
                try {
                  await callback(token.trim());
                } catch (_) {
                  // Ignore token refresh sync failures and retry next refresh.
                }
              }),
            );
          }
        });
        _isInitialized = true;
      }

      final RemoteMessage? initialMessage = await _messaging
          .getInitialMessage();
      if (initialMessage != null) {
        _openedCallback?.call(initialMessage);
      }

      final String? token = await _messaging.getToken();
      if (token != null && token.trim().isNotEmpty) {
        await onTokenSync(token.trim());
      }
    } catch (_) {
      // Keep app startup resilient if Firebase Messaging is unavailable.
    }
  }

  @override
  Future<void> removeCurrentToken({
    required AppUser user,
    required Future<void> Function(String token) onTokenRemove,
  }) async {
    if (!_isSupportedPlatform) {
      return;
    }

    try {
      final String? token = await _messaging.getToken();
      if (token != null && token.trim().isNotEmpty) {
        await onTokenRemove(token.trim());
      }
      await _messaging.deleteToken();
    } catch (_) {
      // Keep logout resilient if token cleanup fails.
    }
  }

  @override
  void dispose() {
    unawaited(_tokenRefreshSubscription?.cancel() ?? Future<void>.value());
    unawaited(_foregroundSubscription?.cancel() ?? Future<void>.value());
    unawaited(_openedSubscription?.cancel() ?? Future<void>.value());
  }
}
