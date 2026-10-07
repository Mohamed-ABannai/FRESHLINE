import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'src/app.dart';
import 'src/services/push_notifications_service.dart';

export 'src/app.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  } catch (_) {
    // Ignore background Firebase init failures.
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  PushNotificationsService? pushNotificationsService;

  if (!kIsWeb) {
    final TargetPlatform platform = defaultTargetPlatform;
    if (platform == TargetPlatform.android || platform == TargetPlatform.iOS) {
      try {
        await Firebase.initializeApp();
        FirebaseMessaging.onBackgroundMessage(
          firebaseMessagingBackgroundHandler,
        );
        pushNotificationsService = FirebasePushNotificationsService();
      } catch (_) {
        // Keep app booting even if Firebase is not fully configured yet.
      }
    }
  }

  runApp(FreshlineApp(pushNotificationsService: pushNotificationsService));
}
