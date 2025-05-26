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
  
  // Arka planda alınan bildirimi detaylı logla
  debugPrint("================ ARKA PLAN BİLDİRİMİ ALINDI ================");
  debugPrint("Bildirim ID: ${message.messageId}");
  debugPrint("Gönderim Zamanı: ${message.sentTime}");
  
  // Bildirim verisi detaylı yazdırma
  debugPrint("------- Bildirim Verisi -------");
  message.data.forEach((key, value) {
    debugPrint("$key: $value");
  });
  
  // Bildirim içeriği detaylı yazdırma
  if (message.notification != null) {
    debugPrint("------- Bildirim İçeriği -------");
    debugPrint("Başlık: ${message.notification!.title}");
    debugPrint("İçerik: ${message.notification!.body}");
    debugPrint("Android Kanal ID: ${message.notification!.android?.channelId}");
    debugPrint("Android Öncelik: ${message.notification!.android?.priority}");
  }
  
  // iOS özel alanları kontrol et
  if (message.notification?.apple != null) {
    debugPrint("------- iOS Bildirim Detayları -------");
    debugPrint("Badge: ${message.notification!.apple!.badge}");
    debugPrint("Sound: ${message.notification!.apple!.sound}");
  }
  
  // Content-available kontrolü
  if (message.data.containsKey('content-available')) {
    debugPrint("Content-Available: ${message.data['content-available']}");
  }
  
  // Bildirim kaynağını kontrol et
  debugPrint("------- Bildirim Kaynağı -------");
  debugPrint("Mesaj Tipi: ${message.messageType}");
  debugPrint("Kaynak: ${message.from}");
  
  // Burada bildirimleri işleyebilirsiniz
  // Örnek: Yerel bildirim gösterme, veritabanı güncelleme, vb.
  
  debugPrint("==============================================================");
  
  // Arka plan işlemi tamamlandı
  return Future.value();
} 