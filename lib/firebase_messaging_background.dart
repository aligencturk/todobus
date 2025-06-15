import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'firebase_options.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    // Firebase'i başlat
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    
    debugPrint("🔔 Background bildirim alındı: ${message.notification?.title}");
    debugPrint("📱 Bildirim gövdesi: ${message.notification?.body}");
    
    // Bildirim verilerini detaylı işle
    if (message.data.isNotEmpty) {
      debugPrint("📋 Bildirim verisi: ${message.data}");
      
      // Veri içinden type bilgisini al
      final dataString = message.data['keysandvalues'] as String?;
      if (dataString != null) {
        debugPrint("🔍 Veri anahtarları: $dataString");
      }
      
      // Notification type'a göre özel işlemler
      final notificationType = message.data['type'] ?? 'unknown';
      debugPrint("📌 Bildirim tipi: $notificationType");
      
      switch (notificationType) {
        case 'project_assigned':
          debugPrint("👥 Proje atama bildirimi");
          break;
        case 'task_assigned':
          debugPrint("📝 Görev atama bildirimi");
          break;
        case 'comment_added':
          debugPrint("💬 Yorum bildirimi");
          break;
        default:
          debugPrint("ℹ️ Genel bildirim");
      }
    }
    
    // Background'da local notification göster
    await _showBackgroundNotification(message);
    
  } catch (e) {
    debugPrint("❌ Background bildirim işleme hatası: $e");
  }
}

// Background'da local notification göstermek için
Future<void> _showBackgroundNotification(RemoteMessage message) async {
  try {
    final FlutterLocalNotificationsPlugin localNotifications = FlutterLocalNotificationsPlugin();
    
    // Android initialization
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // iOS initialization
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    
    await localNotifications.initialize(initializationSettings);
    
    // Bildirim göster
    await localNotifications.show(
      message.notification.hashCode,
      message.notification?.title ?? 'TodoBus',
      message.notification?.body ?? 'Yeni bildirim var',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'todobus_channel',
          'TodoBus Bildirimleri',
          channelDescription: 'TodoBus uygulaması bildirimleri',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: message.data.toString(),
    );
    
    debugPrint("✅ Background local notification gösterildi");
    
  } catch (e) {
    debugPrint("❌ Background local notification hatası: $e");
  }
} 