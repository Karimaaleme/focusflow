import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'api_service.dart';

// ⚠️  Replace with your VAPID key from:
// Firebase Console → Project Settings → Cloud Messaging → Web Push certificates
const _webVapidKey = 'BFFtl5Ac4rfmOqUxgPiyXVHkXYtIxk1XvNsiDszxxEtcxm5vJnbMyQ5-0LGz6yFK9b1ITHYXV9R4eV2kV25bleE';

/// Top-level handler for background messages (must be a top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('FCM background message: ${message.notification?.title}');
}

class PushNotificationService {
  static final _messaging = FirebaseMessaging.instance;

  static Future<void> init() async {
    // Register background handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Request permission (Android 13+, iOS, Web)
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('FCM permission denied');
      return;
    }

    // Get token and save to backend
    await _refreshAndSaveToken();

    // Listen for token refresh
    _messaging.onTokenRefresh.listen(_saveToken);

    // Handle foreground messages (show a debug print; add flutter_local_notifications for a banner)
    FirebaseMessaging.onMessage.listen((message) {
      debugPrint('FCM foreground: ${message.notification?.title} — ${message.notification?.body}');
    });
  }

  static Future<void> _refreshAndSaveToken() async {
    try {
      String? token;
      if (kIsWeb) {
        token = await _messaging.getToken(vapidKey: _webVapidKey);
      } else {
        token = await _messaging.getToken();
      }
      if (token != null) await _saveToken(token);
    } catch (e) {
      debugPrint('FCM get token error: $e');
    }
  }

  static Future<void> _saveToken(String token) async {
    try {
      await ApiService.saveFcmToken(token);
      debugPrint('FCM token saved');
    } catch (e) {
      debugPrint('FCM save token error: $e');
    }
  }
}
