import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';
import 'user_service.dart';
import 'logger_service.dart';
import '../models/notification_model.dart' as app_notification;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  static NotificationService get instance => _instance;

  late final FirebaseMessaging _firebaseMessaging;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final UserService _userService = UserService();
  final LoggerService _logger = LoggerService();
  
  String? _fcmToken;
  String? get fcmToken => _fcmToken;
  
  List<app_notification.NotificationModel>? _notifications;
  List<app_notification.NotificationModel>? get notifications => _notifications;
  int _unreadCount = 0;
  int get unreadCount => _unreadCount;
  
  NotificationService._internal();
  
  Future<void> init() async {
    _logger.i('NotificationService başlatılıyor...');
    
    // Önce Firebase'i başlat
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        _logger.i('Firebase NotificationService içinde başlatıldı');
      }
      
      // Firebase başlatıldıktan sonra FirebaseMessaging instance'ını oluştur
      _firebaseMessaging = FirebaseMessaging.instance;
    } catch (e) {
      _logger.e('Firebase başlatılırken hata oluştu: $e');
      rethrow;
    }
    
    // Firebase Messaging izinlerini talep et
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    
    _logger.i('Kullanıcı bildirim izin durumu: ${settings.authorizationStatus}');
    
    // APNs token (iOS için)
    if (Platform.isIOS) {
      String? apnsToken = await _firebaseMessaging.getAPNSToken();
      _logger.i('APNs Token: $apnsToken');
    }
    
    // FCM token al
    _fcmToken = await _firebaseMessaging.getToken();
    _logger.i('-------------------  FCM TOKEN  -------------------');
    _logger.i('FCM Token: $_fcmToken');
    _logger.i('---------------------------------------------------');
    
    // Android için token'ı logla
    if (Platform.isAndroid) {
      _logger.i('Android için FCM token: $_fcmToken');
    }
    
    // iOS için token'ı logla
    if (Platform.isIOS) {
      _logger.i('iOS için FCM token: $_fcmToken');
    }
    
    // Token'ı sunucuya gönder
    if (_fcmToken != null) {
      await _userService.updateFcmToken(_fcmToken!).then((success) {
        if (success) {
          _logger.i('FCM Token sunucuya başarıyla gönderildi: $_fcmToken');
        } else {
          _logger.w('FCM Token sunucuya gönderilemedi!');
        }
      });
    }
    
    // Token yenilendiğinde olayı dinle
    _firebaseMessaging.onTokenRefresh.listen((newToken) async {
      _fcmToken = newToken;
      _logger.i('-------------------  FCM TOKEN YENİLENDİ  -------------------');
      _logger.i('Yeni FCM Token: $_fcmToken');
      _logger.i('---------------------------------------------------------------');
      
      // Yeni token'ı sunucuya gönder
      if (_fcmToken != null) {
        await _userService.updateFcmToken(_fcmToken!).then((success) {
          if (success) {
            _logger.i('Yenilenen FCM Token sunucuya gönderildi.');
          } else {
            _logger.w('Yenilenen FCM Token sunucuya gönderilemedi!');
          }
        });
      }
    });
    
    // Yerel bildirimleri yapılandır
    await _initLocalNotifications();
    
    // Ön planda bildirim alma
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    
    // Uygulama arkaplanda iken bildirime tıklanma
    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessageOpen);
    
    // Uygulama kapalıyken bildirimlere tıklama
    await _checkInitialMessage();
  }
  
  Future<void> _initLocalNotifications() async {
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    DarwinInitializationSettings iosSettings = const DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    final InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        // Bildirime tıklandığında yapılacak işlemler
        debugPrint('Yerel bildirime tıklandı: ${details.payload}');
      },
    );
    
    // Android için notification channel oluştur
    if (Platform.isAndroid) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'high_importance_channel',
        'Yüksek Öncelikli Bildirimler',
        description: 'Bu kanal önemli bildirimleri göstermek için kullanılır',
        importance: Importance.high,
      );
      
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
  }
  
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    _logger.i('======== Ön plan bildirim alındı ========');
    _logger.i('Bildirim ID: ${message.messageId}');
    _logger.i('Bildirim Başlık: ${message.notification?.title}');
    _logger.i('Bildirim İçerik: ${message.notification?.body}');
    _logger.i('Bildirim Verileri: ${message.data}');
    
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;
    
    // Ön planda bildirim göster
    if (notification != null) {
      _logger.i('Bildirimi yerel olarak gösteriyorum...');
      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: const AndroidNotificationDetails(
            'high_importance_channel',
            'Yüksek Öncelikli Bildirimler',
            channelDescription: 'Bu kanal önemli bildirimleri göstermek için kullanılır',
            icon: '@mipmap/ic_launcher',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: message.data.toString(),
      );
      _logger.i('Bildirim gösterildi.');
    }
  }
  
  void _handleBackgroundMessageOpen(RemoteMessage message) {
    _logger.i('======== Arka plan bildirimine tıklandı ========');
    _logger.i('Bildirim ID: ${message.messageId}');
    _logger.i('Bildirim Başlık: ${message.notification?.title}');
    _logger.i('Bildirim İçerik: ${message.notification?.body}');
    _logger.i('Bildirim Verileri: ${message.data}');
    _handleNotificationData(message.data);
  }
  
  Future<void> _checkInitialMessage() async {
    _logger.i('Uygulama başlangıç bildirimleri kontrol ediliyor...');
    RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    
    if (initialMessage != null) {
      _logger.i('========== UYGULAMA BAŞLANGIÇ BİLDİRİMİ BULUNDU ==========');
      _logger.i('Bildirim ID: ${initialMessage.messageId}');
      _logger.i('Bildirim Başlık: ${initialMessage.notification?.title}');
      _logger.i('Bildirim İçerik: ${initialMessage.notification?.body}');
      _logger.i('Bildirim Verileri: ${initialMessage.data}');
      _logger.i('===========================================================');
      
      _handleNotificationData(initialMessage.data);
    } else {
      _logger.i('Uygulama başlangıç bildirimi bulunamadı.');
    }
  }
  
  void _handleNotificationData(Map<String, dynamic> data) {
    _logger.i('---------------------- BİLDİRİM VERİSİ İŞLENİYOR ----------------------');
    _logger.i('Veri: $data');
    
    // Veri içeriğini detaylı logla
    data.forEach((key, value) {
      _logger.i('$key: $value');
    });
    
    // Yeni bildirim geldiğinde bildirimleri güncelle
    fetchNotifications();
    
    // Bildirim içeriğine göre yönlendirme veya işlem yapma
    if (data.containsKey('screen')) {
      String screenName = data['screen'] as String;
      _logger.i('Bildirim ekran yönlendirmesi: $screenName');
      
      // TODO: Navigator ile ekrana yönlendirme işlemi yapılabilir
      // Örneğin: NavigationService.instance.navigateTo(screenName, arguments: data);
    }
    
    // Bildirimde action mevcutsa, özel aksiyonlar
    if (data.containsKey('action')) {
      String action = data['action'] as String;
      _logger.i('Bildirim aksiyonu: $action');
      
      // TODO: Aksiyona özgü işlemler yapılabilir
    }
    
    _logger.i('------------------------------------------------------------------------');
  }
  
  // Ek işlevler
  Future<void> subscribeToTopic(String topic) async {
    await _firebaseMessaging.subscribeToTopic(topic);
    debugPrint('$topic konusuna abone olundu');
  }
  
  Future<void> unsubscribeFromTopic(String topic) async {
    await _firebaseMessaging.unsubscribeFromTopic(topic);
    debugPrint('$topic konusundan abonelik iptal edildi');
  }
  
  // FCM token alın ve API'ye gönderin (örnek)
  Future<void> sendTokenToServer() async {
    if (_fcmToken != null) {
      // API'ye token gönderme işlemi burada yapılabilir
      debugPrint('Token sunucuya gönderildi: $_fcmToken');
    }
  }
  
  // Kullanıcının bildirimlerini getir
  Future<List<app_notification.NotificationModel>?> fetchNotifications() async {
    try {
      final response = await _userService.getNotifications();
      
      if (response.success && response.notifications != null) {
        _notifications = response.notifications;
        _unreadCount = response.unreadCount ?? 0;
        _logger.i('Bildirimler başarıyla alındı: ${_notifications?.length} bildirim, $_unreadCount okunmamış');
        return _notifications;
      } else {
        _logger.w('Bildirimler alınamadı: ${response.errorMessage}');
        return null;
      }
    } catch (e) {
      _logger.e('Bildirimler yüklenirken hata: $e');
      return null;
    }
  }
  
  // Bildirimi okundu olarak işaretle
  Future<bool> markAsRead(int notificationId) async {
    try {
      final success = await _userService.markNotificationAsRead(notificationId);
      if (success) {
        // Başarıyla işaretlendiyse, bildirimleri güncelle
        await fetchNotifications();
      }
      return success;
    } catch (e) {
      _logger.e('Bildirim okundu olarak işaretlenirken hata: $e');
      return false;
    }
  }
  
  // FCM Token bilgilerini yazdır (debug ve test için)
  void printFcmTokenInfo() {
    _logger.i('================ FCM TOKEN BİLGİLERİ ================');
    _logger.i('Token: $_fcmToken');
    _logger.i('Platform: ${Platform.operatingSystem}');
    _logger.i('OS Versiyonu: ${Platform.operatingSystemVersion}');
    _logger.i('===============================================');
  }
  
  // FCM Token'ı al (diğer servisler için)
  String? getFcmToken() {
    printFcmTokenInfo();
    return _fcmToken;
  }
} 