import 'dart:io';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
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
  
  // Callback fonksiyonlar
  Function(Map<String, dynamic>)? onNotificationTap;
  Function(String)? onTokenUpdate;
  
  NotificationService._internal();
  
  Future<void> init() async {
    _logger.i('🚀 NotificationService başlatılıyor...');
    
    try {
      // Firebase başlatma kontrolü
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        _logger.i('✅ Firebase başlatıldı');
      }
      
      _firebaseMessaging = FirebaseMessaging.instance;
      
      // İzin talep et
      await _requestPermissions();
      
      // Token al
      await _getToken();
      
      // Local notifications başlat
      await _initLocalNotifications();
      
      // Message handlers ayarla
      _setupMessageHandlers();
      
      // User topic subscription
      await _subscribeToUserTopic();
      
      _logger.i('✅ NotificationService başarıyla başlatıldı');
    } catch (e) {
      _logger.e('❌ NotificationService başlatılamadı: $e');
      rethrow;
    }
  }
  
  Future<void> _requestPermissions() async {
    try {
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
        criticalAlert: true,
        carPlay: false,
        announcement: false,
      );
      
      _logger.i('📱 Bildirim izin durumu: ${settings.authorizationStatus}');
      
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        _logger.w('⚠️ Kullanıcı bildirim izinlerini reddetti');
        return;
      }
      
      if (Platform.isIOS) {
        await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
        _logger.i('🍎 iOS foreground notification ayarları yapılandırıldı');
      }
    } catch (e) {
      _logger.e('❌ Bildirim izinleri alınırken hata: $e');
    }
  }
  
  Future<void> _getToken() async {
    try {
      // iOS için APNs token'ı bekle
      if (Platform.isIOS) {
        String? apnsToken = await _firebaseMessaging.getAPNSToken();
        if (apnsToken == null) {
          _logger.w('⚠️ APNs token henüz hazır değil, bekleniyor...');
          // APNs token'ı için maksimum 30 saniye bekle
          for (int i = 0; i < 30; i++) {
            await Future.delayed(const Duration(seconds: 1));
            apnsToken = await _firebaseMessaging.getAPNSToken();
            if (apnsToken != null) {
              _logger.i('✅ APNs token alındı: ${apnsToken.substring(0, 20)}...');
              break;
            }
          }
          
          if (apnsToken == null) {
            _logger.e('❌ APNs token 30 saniye içinde alınamadı');
          }
        }
      }
      
      _fcmToken = await _firebaseMessaging.getToken();
      if (_fcmToken != null) {
        _logger.i('✅ FCM Token alındı: ${_fcmToken!.substring(0, 20)}...');
        
        // Token'ı sunucuya gönder
        await _sendTokenToServer(_fcmToken!);
        
        // Callback çağır
        onTokenUpdate?.call(_fcmToken!);
      } else {
        _logger.e('❌ FCM Token alınamadı');
      }
      
      // Token yenilenme dinleyicisi
      _firebaseMessaging.onTokenRefresh.listen((newToken) async {
        _logger.i('🔄 FCM Token yenilendi');
        _fcmToken = newToken;
        await _sendTokenToServer(newToken);
        onTokenUpdate?.call(newToken);
      });
    } catch (e) {
      _logger.e('❌ Token alma hatası: $e');
    }
  }
  
  Future<void> _sendTokenToServer(String token) async {
    try {
      final success = await _userService.updateFcmToken(token);
      if (success) {
        _logger.i('✅ Token sunucuya gönderildi');
      } else {
        _logger.e('❌ Token sunucuya gönderilemedi');
      }
    } catch (e) {
      _logger.e('❌ Token gönderme hatası: $e');
    }
  }
  
  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _handleNotificationTap,
    );
    
    // Android kanal oluştur
    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        'todobus_channel',
        'TodoBus Bildirimleri',
        description: 'TodoBus uygulaması bildirimleri',
        importance: Importance.high,
        enableVibration: true,
        playSound: true,
      );
      
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
          
      _logger.i('🤖 Android bildirim kanalı oluşturuldu');
    }
  }
  
  void _setupMessageHandlers() {
    // Foreground mesajlar
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _logger.i('🔔 Foreground mesaj alındı: ${message.notification?.title}');
      _handleForegroundMessage(message);
    });
    
    // Background mesaj tıklamaları
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _logger.i('📱 Background mesaj tıklandı: ${message.notification?.title}');
      _handleMessageTap(message);
    });
    
    // Uygulama kapalıyken tıklama
    _firebaseMessaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        _logger.i('🚀 Uygulama kapalıyken tıklandı: ${message.notification?.title}');
        Future.delayed(const Duration(seconds: 2), () {
          _handleMessageTap(message);
        });
      }
    });
  }
  
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    try {
      // Foreground'da local notification göster
      await _showLocalNotification(message);
    } catch (e) {
      _logger.e('❌ Foreground mesaj işleme hatası: $e');
    }
  }
  
  Future<void> _showLocalNotification(RemoteMessage message) async {
    try {
      final notification = message.notification;
      if (notification == null) return;
      
      // Bildirim ID'si oluştur
      final notificationId = DateTime.now().millisecondsSinceEpoch.remainder(100000);
      
      await _localNotifications.show(
        notificationId,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'todobus_channel',
            'TodoBus Bildirimleri',
            channelDescription: 'TodoBus uygulaması bildirimleri',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            enableVibration: true,
            playSound: true,
            ticker: notification.title,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            interruptionLevel: InterruptionLevel.active,
          ),
        ),
        payload: jsonEncode(message.data),
      );
      
      _logger.i('✅ Local notification gösterildi');
    } catch (e) {
      _logger.e('❌ Local notification gösterme hatası: $e');
    }
  }
  
  void _handleNotificationTap(NotificationResponse response) {
    try {
      _logger.i('👆 Local notification tıklandı');
      
      if (response.payload != null) {
        final data = jsonDecode(response.payload!);
        _processNotificationData(data);
        onNotificationTap?.call(data);
      }
    } catch (e) {
      _logger.e('❌ Notification tap işleme hatası: $e');
    }
  }
  
  void _handleMessageTap(RemoteMessage message) {
    try {
      _logger.i('👆 Firebase mesaj tıklandı: ${message.data}');
      _processNotificationData(message.data);
      onNotificationTap?.call(message.data);
    } catch (e) {
      _logger.e('❌ Message tap işleme hatası: $e');
    }
  }
  
  void _processNotificationData(Map<String, dynamic> data) {
    try {
      // keysandvalues içindeki veriyi parse et
      final keysAndValues = data['keysandvalues'] as String?;
      if (keysAndValues != null) {
        final parsedData = jsonDecode(keysAndValues);
        final notificationType = parsedData['type'] as String?;
        final id = parsedData['id'];
        
        _logger.i('📌 Bildirim tipi: $notificationType, ID: $id');
        
        // Bildirim tipine göre navigasyon
        switch (notificationType) {
          case 'project_assigned':
            _logger.i('👥 Proje atama bildirimi - Navigasyon gerekli');
            break;
          case 'task_assigned':
            _logger.i('📝 Görev atama bildirimi - Navigasyon gerekli');
            break;
          case 'comment_added':
            _logger.i('💬 Yorum bildirimi - Navigasyon gerekli');
            break;
          default:
            _logger.i('ℹ️ Genel bildirim');
        }
      }
    } catch (e) {
      _logger.e('❌ Bildirim data işleme hatası: $e');
    }
  }
  
  // User topic aboneliği
  Future<void> _subscribeToUserTopic() async {
    try {
      final userResponse = await _userService.getUser();
      if (userResponse.success && userResponse.data != null) {
        final userId = userResponse.data!.user.userID;
        await subscribeToUserTopic(userId);
      }
    } catch (e) {
      _logger.e('❌ User topic aboneliği hatası: $e');
    }
  }
  
  // Topic aboneliği
  Future<bool> subscribeToUserTopic(int userId) async {
    try {
      final topic = "$userId";
      await _firebaseMessaging.subscribeToTopic(topic);
      _logger.i('✅ Topic aboneliği başarılı: $topic');
      return true;
    } catch (e) {
      _logger.e('❌ Topic aboneliği hatası: $e');
      return false;
    }
  }
  
  // Topic aboneliğini iptal et
  Future<bool> unsubscribeFromUserTopic(int userId) async {
    try {
      final topic = "user_$userId";
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      _logger.i('✅ Topic aboneliği iptal edildi: $topic');
      return true;
    } catch (e) {
      _logger.e('❌ Topic aboneliği iptal etme hatası: $e');
      return false;
    }
  }
  
  // Bildirimleri çek
  Future<List<app_notification.NotificationModel>?> fetchNotifications() async {
    try {
      final response = await _userService.getNotifications();
      
      if (response.success && response.notifications != null) {
        _notifications = response.notifications;
        _unreadCount = response.unreadCount ?? 0;
        _logger.i('✅ Bildirimler alındı: ${_notifications?.length}');
        return _notifications;
      }
    } catch (e) {
      _logger.e('❌ Bildirim çekme hatası: $e');
    }
    return null;
  }
  
  // Test bildirimi gönder
  Future<void> sendTestNotification() async {
    try {
      if (_fcmToken == null) {
        _logger.e('❌ FCM token yok, test bildirimi gönderilemez');
        return;
      }
      
      _logger.i('🧪 Test bildirimi gönderiliyor...');
      _logger.i('Token: $_fcmToken');
      _logger.i('Firebase Console\'dan bu token\'a test bildirimi gönderebilirsiniz');
      
    } catch (e) {
      _logger.e('❌ Test bildirimi hatası: $e');
    }
  }
  
  // Debug fonksiyonu
  Future<void> debug() async {
    _logger.i('========== FCM DETAYLI TEŞHIS ==========');
    
    try {
      // Platform bilgisi
      _logger.i('📱 Platform: ${Platform.operatingSystem}');
      _logger.i('📱 OS Version: ${Platform.operatingSystemVersion}');
      
      // Firebase App durumu
      _logger.i('🔥 Firebase Apps: ${Firebase.apps.length}');
      
      // FCM token kontrolü
      final token = await _firebaseMessaging.getToken();
      if (token == null || token.isEmpty) {
        _logger.e('❌ FCM Token alınamadı!');
        _logger.e('   - google-services.json (Android) / GoogleService-Info.plist (iOS) kontrol edin');
        _logger.e('   - Bundle ID\'ler eşleşiyor mu?');
        _logger.e('   - Internet bağlantısı var mı?');
      } else {
        _logger.i('✅ FCM Token alındı');
        _logger.i('📋 Token: ${token.substring(0, 50)}...');
        _logger.i('📋 Token uzunluğu: ${token.length} karakter');
      }
      
      // Bildirim izinleri kontrolü
      final settings = await _firebaseMessaging.getNotificationSettings();
      _logger.i('🔔 Bildirim izin durumu: ${settings.authorizationStatus}');
      
      switch (settings.authorizationStatus) {
        case AuthorizationStatus.authorized:
          _logger.i('✅ Bildirim izinleri TAMAM');
          break;
        case AuthorizationStatus.denied:
          _logger.e('❌ Bildirim izinleri REDDEDİLDİ!');
          _logger.e('   Kullanıcı sistem ayarlarından bildirimleri açmalı');
          break;
        case AuthorizationStatus.notDetermined:
          _logger.w('⚠️ Bildirim izinleri henüz belirlenmedi');
          break;
        case AuthorizationStatus.provisional:
          _logger.w('⚠️ Geçici bildirim izni');
          break;
        default:
          _logger.w('❓ Bilinmeyen izin durumu: ${settings.authorizationStatus}');
      }
      
      // Platform özel kontroller
      if (Platform.isIOS) {
        _logger.i('🍎 iOS özel kontroller:');
        
        final apnsToken = await _firebaseMessaging.getAPNSToken();
        if (apnsToken == null || apnsToken.isEmpty) {
          _logger.e('❌ APNs token alınamadı!');
          _logger.e('   - Gerçek iOS cihaz kullanıyor musunuz?');
          _logger.e('   - Xcode\'da Push Notifications capability var mı?');
          _logger.e('   - Runner.entitlements dosyası doğru mu?');
          _logger.e('   - Firebase Console\'da APNs sertifikası var mı?');
        } else {
          _logger.i('✅ APNs token alındı');
          _logger.i('📋 APNs Token: ${apnsToken.substring(0, 30)}...');
        }
        
        _logger.i('🔔 iOS Alert izni: ${settings.alert}');
        _logger.i('🔔 iOS Badge izni: ${settings.badge}');
        _logger.i('🔔 iOS Sound izni: ${settings.sound}');
        
      } else if (Platform.isAndroid) {
        _logger.i('🤖 Android özel kontroller:');
        _logger.i('📋 Android Kontrol Listesi:');
        _logger.i('   1. google-services.json doğru konumda mı?');
        _logger.i('   2. ApplicationId: com.rivorya.todobus');
        _logger.i('   3. build.gradle\'da google-services plugin var mı?');
        _logger.i('   4. AndroidManifest.xml\'de izinler var mı?');
      }
      
      // Token gönderme test
      if (token != null) {
        _logger.i('📤 Token backend\'e test ediliyor...');
        try {
          final success = await _userService.updateFcmToken(token);
          if (success) {
            _logger.i('✅ Token backend\'e başarıyla gönderildi');
          } else {
            _logger.e('❌ Token backend\'e gönderilemedi!');
          }
        } catch (e) {
          _logger.e('❌ Token gönderme hatası: $e');
        }
      }
      
      // Kullanıcı topic aboneliği
      try {
        final userResponse = await _userService.getUser();
        if (userResponse.success && userResponse.data != null) {
          final userId = userResponse.data!.user.userID;
          _logger.i('👤 Kullanıcı ID: $userId');
          
          final topicSuccess = await subscribeToUserTopic(userId);
          if (topicSuccess) {
            _logger.i('✅ Topic aboneliği başarılı: user_$userId');
          } else {
            _logger.e('❌ Topic aboneliği başarısız!');
          }
        } else {
          _logger.e('❌ Kullanıcı bilgileri alınamadı!');
        }
      } catch (e) {
        _logger.e('❌ Kullanıcı kontrolü hatası: $e');
      }
      
      // Test token bilgisi
      if (token != null) {
        _logger.i('🧪 TEST İÇİN FCM TOKEN:');
        _logger.i(token);
        _logger.i('Bu token\'ı Firebase Console > Cloud Messaging > Send test message kısmında kullanabilirsiniz');
      }
      
    } catch (e) {
      _logger.e('❌ Teşhis sırasında hata: $e');
    }
    
    _logger.i('==========================================');
  }
} 