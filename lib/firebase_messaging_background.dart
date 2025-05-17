import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Arka plan mesajları için Firebase'i başlat
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint("Firebase arka plan mesaj işleyicide başlatıldı");
    }
  } catch (e) {
    debugPrint("Firebase başlatılırken hata: $e");
  }
  
  // Arka planda alınan bildirimi logla
  debugPrint("================ ARKA PLAN BİLDİRİMİ ALINDI ================");
  debugPrint("Bildirim ID: ${message.messageId}");
  debugPrint("Gönderim Zamanı: ${message.sentTime}");
  
  // Bildirim verisi detaylı yazdırma
  debugPrint("------- Bildirim Verisi -------");
  message.data.forEach((key, value) {
    debugPrint("$key: $value");
  });
  
  // Bildirim başlığı ve içeriği
  if (message.notification != null) {
    debugPrint("Başlık: ${message.notification!.title}");
    debugPrint("İçerik: ${message.notification!.body}");
  }
  
  debugPrint("==============================================================");
} 