import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Arka plan mesajları için Firebase'i başlat
  try {
    // Arka plan işleyicilerde her zaman Firebase'i başlatmak gerekiyor
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint("Firebase arka plan mesaj işleyicide başlatıldı");
    } else {
      debugPrint("Firebase zaten başlatılmış durumda");
    }
  } catch (e) {
    debugPrint("Firebase başlatılırken hata: $e");
  }
  
  // Bu fonksiyon, uygulama arka planda veya kapalıyken FCM mesajlarını işler
  // NOT: arka planda yalnızca basit işlemler yapılmalıdır, karmaşık işlemler yapılmamalıdır
  debugPrint("================ ARKA PLAN BİLDİRİMİ ALINDI ================");
  debugPrint("Bildirim ID: ${message.messageId}");
  debugPrint("Gönderim Zamanı: ${message.sentTime}");
  debugPrint("TTL: ${message.ttl}");
  debugPrint("Bildirim Kategori: ${message.category}");
  
  // Bildirim verisi detaylı yazdırma
  debugPrint("------- Bildirim Verisi -------");
  message.data.forEach((key, value) {
    debugPrint("$key: $value");
  });
  debugPrint("-------------------------------");
  
  // Bildirim başlığı ve içeriği
  if (message.notification != null) {
    debugPrint("------- Bildirim İçeriği -------");
    debugPrint("Başlık: ${message.notification!.title}");
    debugPrint("İçerik: ${message.notification!.body}");
    
    // Android özellikleri
    if (message.notification!.android != null) {
      debugPrint("Android Kanal ID: ${message.notification!.android!.channelId}");
      debugPrint("Android Tıklama Aksiyonu: ${message.notification!.android!.clickAction}");
    }
    
    // iOS özellikleri
    if (message.notification!.apple != null) {
      debugPrint("iOS Badge: ${message.notification!.apple!.badge}");
      debugPrint("iOS Subtitle: ${message.notification!.apple!.subtitle}");
    }
    
    debugPrint("--------------------------------");
  }
  
  debugPrint("==============================================================");
} 