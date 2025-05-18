import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../services/logger_service.dart';
import '../services/user_service.dart';
import '../firebase_messaging_background.dart';

/// Firebase bildirimlerini yönetecek servis sınıfı
class FirebaseMessagingService {
  static final FirebaseMessagingService _instance = FirebaseMessagingService._internal();
  
  static FirebaseMessagingService get instance => _instance;

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final LoggerService _logger = LoggerService();
  final UserService _userService = UserService();
  
  // Bildirim tıklandığında geri çağırım
  final StreamController<RemoteMessage> _onMessageOpenedAppController = StreamController<RemoteMessage>.broadcast();
  Stream<RemoteMessage> get onMessageOpenedApp => _onMessageOpenedAppController.stream;
  
  // Bildirim kanalı ID'si
  static const String _channelId = 'todobus_notification_channel';
  static const String _channelName = 'TodoBus Bildirimleri';
  static const String _channelDescription = 'TodoBus bildirim kanalı';

  // Token takibi
  String? _fcmToken;
  bool _isTokenSentToServer = false;

  FirebaseMessagingService._internal();

  /// Firebase mesajlaşma servisini başlat
  Future<void> initialize() async {
    _logger.i('Firebase Messaging servisi başlatılıyor...');
    debugPrint('Firebase Messaging servisi başlatılıyor...');
    
    // Arka plan mesaj işleyicisini ayarla
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    
    // İzinleri iste
    await _requestPermissions();
    
    // Bildirim kanallarını yapılandır
    await _setupNotificationChannels();
    
    // Ön planda mesaj işleyicilerini ayarla
    _setupForegroundHandlers();
    
    // Token alma ve güncelleme işleyicilerini ayarla
    await _setupTokenHandlers();
    
    // FCM durum kontrolü
    await _checkFCMStatus();
    
    _logger.i('Firebase Messaging servisi başarıyla başlatıldı');
    debugPrint('Firebase Messaging servisi başarıyla başlatıldı');
  }

  /// FCM servisinin durumunu kontrol et
  Future<void> _checkFCMStatus() async {
    _logger.i('===== FCM Durum Kontrolü =====');
    debugPrint('===== FCM Durum Kontrolü =====');
    
    try {
      // Bildirimlere izin verilmiş mi kontrolü
      final settings = await _messaging.getNotificationSettings();
      _logger.i('Bildirim İzni: ${settings.authorizationStatus}');
      debugPrint('Bildirim İzni: ${settings.authorizationStatus}');
      
      // FCM token kontrolü
      final fcmToken = await _messaging.getToken();
      _logger.i('FCM Token: $fcmToken');
      debugPrint('FCM Token: $fcmToken');
      
      // iOS'ta APNs token kontrolü
      if (Platform.isIOS) {
        final apnsToken = await _messaging.getAPNSToken();
        _logger.i('APNs Token: $apnsToken');
        debugPrint('APNs Token: $apnsToken');
      }
      
      // Bildirimler için kullanılan izin ve ayarları logla
      if (Platform.isAndroid) {
        final androidPlugin = _localNotifications
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        
        if (androidPlugin != null) {
          final areNotificationsEnabled = await androidPlugin.areNotificationsEnabled();
          _logger.i('Android Bildirimleri Etkin: $areNotificationsEnabled');
          debugPrint('Android Bildirimleri Etkin: $areNotificationsEnabled');
        }
      }
    } catch (e) {
      _logger.e('FCM durum kontrolünde hata: $e');
      debugPrint('FCM durum kontrolünde hata: $e');
    }
    
    _logger.i('=============================');
    debugPrint('=============================');
  }

  /// Bildirim izinlerini iste
  Future<void> _requestPermissions() async {
    _logger.i('Bildirim izinleri isteniyor...');
    debugPrint('Bildirim izinleri isteniyor...');
    
    if (Platform.isIOS) {
      _logger.i('iOS bildirim izinleri isteniyor...');
      debugPrint('iOS bildirim izinleri isteniyor...');
      
      // iOS için önce önceki izin durumunu kontrol et
      final initialSettings = await _messaging.getNotificationSettings();
      _logger.i('Mevcut iOS bildirim izin durumu: ${initialSettings.authorizationStatus}');
      debugPrint('Mevcut iOS bildirim izin durumu: ${initialSettings.authorizationStatus}');
      
      // Yeni izinleri iste
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
        criticalAlert: true,  // Kritik bildirimlere de izin istiyoruz
        announcement: false,
        carPlay: false,
      );
      
      _logger.i('Yeni iOS bildirim izin durumu: ${settings.authorizationStatus}');
      debugPrint('Yeni iOS bildirim izin durumu: ${settings.authorizationStatus}');
      
      // APNs token
      String? apnsToken = await _messaging.getAPNSToken();
      _logger.i('APNs Token: $apnsToken');
      debugPrint('APNs Token: $apnsToken');
      
      // Foreground bildirimleri için ayar
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      _logger.i('iOS foreground bildirimleri ayarlandı');
      debugPrint('iOS foreground bildirimleri ayarlandı');
    } else if (Platform.isAndroid) {
      // Android için yerel bildirim izinleri
      _logger.i('Android bildirim izinleri isteniyor...');
      debugPrint('Android bildirim izinleri isteniyor...');
      
      final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
          _localNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      
      if (androidPlugin != null) {
        // Önce mevcut izin durumunu kontrol et
        bool? currentEnabled = await androidPlugin.areNotificationsEnabled();
        _logger.i('Mevcut Android bildirim durumu: $currentEnabled');
        debugPrint('Mevcut Android bildirim durumu: $currentEnabled');
        
        // Yeni izinleri iste
        if (currentEnabled == false) {
          bool? permissionGranted = await androidPlugin.requestNotificationsPermission();
          _logger.i('Android bildirim izinleri istendi: $permissionGranted');
          debugPrint('Android bildirim izinleri istendi: $permissionGranted');
        }
      }
      
      // FCM hızlı başlatma ayarı
      await _messaging.setAutoInitEnabled(true);
      _logger.i('Android FCM auto-init etkin');
      debugPrint('Android FCM auto-init etkin');
    }
  }

  /// Bildirim kanallarını yapılandır
  Future<void> _setupNotificationChannels() async {
    _logger.i('Yerel bildirim kanalları yapılandırılıyor...');
    debugPrint('Yerel bildirim kanalları yapılandırılıyor...');
    
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
      showBadge: true,
    );

    // Android için bildirim kanalını oluştur
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidPlugin = 
          _localNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      
      if (androidPlugin != null) {
        // Mevcut kanalı sil (yeniden oluşturmak için)
        await androidPlugin.deleteNotificationChannel(_channelId);
        _logger.i('Android eski bildirim kanalı silindi (varsa)');
        debugPrint('Android eski bildirim kanalı silindi (varsa)');
        
        // Yeni kanalı oluştur
        await androidPlugin.createNotificationChannel(channel);
        _logger.i('Android bildirim kanalı oluşturuldu');
        debugPrint('Android bildirim kanalı oluşturuldu');
      }
    }

    // Yerel bildirimleri başlat
    const InitializationSettings initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
        defaultPresentSound: true,
        defaultPresentAlert: true,
        defaultPresentBadge: true,
      ),
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _logger.i('Yerel bildirime tıklandı: ${response.payload}');
        debugPrint('Yerel bildirime tıklandı: ${response.payload}');
        if (response.payload != null) {
          try {
            final Map<String, dynamic> data = json.decode(response.payload!);
            final RemoteMessage message = RemoteMessage(
              data: data,
              notification: RemoteNotification(
                title: data['title'],
                body: data['body'],
              ),
            );
            _onMessageOpenedAppController.add(message);
          } catch (e) {
            _logger.e('Bildirim verisi ayrıştırılamadı: $e');
            debugPrint('Bildirim verisi ayrıştırılamadı: $e');
          }
        }
      },
    );
    
    _logger.i('Yerel bildirim sistemi başlatıldı');
    debugPrint('Yerel bildirim sistemi başlatıldı');
  }

  /// Ön planda mesaj işleyicilerini ayarla
  void _setupForegroundHandlers() {
    _logger.i('Ön plan mesaj işleyicileri ayarlanıyor...');
    debugPrint('Ön plan mesaj işleyicileri ayarlanıyor...');
    
    // Uygulama ön plandayken mesaj alındığında
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _logger.i('Ön planda mesaj alındı: ${message.messageId}');
      _logger.i('Bildirim Başlık: ${message.notification?.title}');
      _logger.i('Bildirim İçerik: ${message.notification?.body}');
      _logger.i('Bildirim Verileri: ${message.data}');
      
      debugPrint('Ön planda mesaj alındı: ${message.messageId}');
      debugPrint('Bildirim Başlık: ${message.notification?.title}');
      debugPrint('Bildirim İçerik: ${message.notification?.body}');
      debugPrint('Bildirim Verileri: ${message.data}');
      
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      // Bildirim varsa yerel bildirim göster
      if (notification != null) {
        _localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId,
              _channelName,
              channelDescription: _channelDescription,
              icon: android?.smallIcon ?? '@mipmap/ic_launcher',
              importance: Importance.high,
              priority: Priority.high,
              enableVibration: true,
              playSound: true,
              visibility: NotificationVisibility.public,
            ),
            iOS: const DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
              sound: 'default',
              badgeNumber: 1,
            ),
          ),
          payload: json.encode(message.data),
        );
        _logger.i('Yerel bildirim gösterildi');
        debugPrint('Yerel bildirim gösterildi');
      } else {
        _logger.w('Bildirimde notification verisi yok, gösterilemedi');
        debugPrint('Bildirimde notification verisi yok, gösterilemedi');
      }
    });

    // Uygulama arka plandayken mesaja tıklandığında
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _logger.i('Arka planda bildirime tıklandı: ${message.messageId}');
      debugPrint('Arka planda bildirime tıklandı: ${message.messageId}');
      _onMessageOpenedAppController.add(message);
    });
    
    // Uygulama kapalıyken mesaja tıklanarak açıldığında
    _messaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        _logger.i('Uygulama, bildirime tıklanarak açıldı: ${message.messageId}');
        debugPrint('Uygulama, bildirime tıklanarak açıldı: ${message.messageId}');
        _onMessageOpenedAppController.add(message);
      }
    });
    
    _logger.i('Ön plan mesaj işleyicileri ayarlandı');
    debugPrint('Ön plan mesaj işleyicileri ayarlandı');
  }

  /// Token alma ve güncelleme işleyicilerini ayarla
  Future<void> _setupTokenHandlers() async {
    _logger.i('Token işleyicileri ayarlanıyor...');
    debugPrint('Token işleyicileri ayarlanıyor...');
    
    // Token alma işlemi - doğrudan await ile bekleyerek token alımını garantiyeliyoruz
    try {
      _fcmToken = await _messaging.getToken();
      
      if (_fcmToken != null) {
        _logger.i('==================== FCM TOKEN ALINDI ====================');
        _logger.i('FCM Token: $_fcmToken');
        _logger.i('===================================================');
        
        debugPrint('==================== FCM TOKEN ALINDI ====================');
        debugPrint('FCM Token: $_fcmToken');
        debugPrint('===================================================');
        
        // Token'ı sunucuya gönder
        await _sendTokenToServer(_fcmToken!);
      } else {
        _logger.w('FCM Token alınamadı! Bildirimleri alamayabilirsiniz.');
        debugPrint('FCM Token alınamadı! Bildirimleri alamayabilirsiniz.');
      }
    } catch (e) {
      _logger.e('FCM Token alınırken hata: $e');
      debugPrint('FCM Token alınırken hata: $e');
    }
    
    // Token güncellendiğinde dinleyici
    _messaging.onTokenRefresh.listen(
      (String token) {
        _fcmToken = token;
        _logger.i('FCM Token güncellendi: $token');
        debugPrint('FCM Token güncellendi: $token');
        _sendTokenToServer(token);
      },
      onError: (error) {
        _logger.e('Token yenileme dinleme hatası: $error');
        debugPrint('Token yenileme dinleme hatası: $error');
      },
    );
    
    _logger.i('Token işleyicileri ayarlandı');
    debugPrint('Token işleyicileri ayarlandı');
  }

  /// FCM token'ını backend'e gönder
  Future<void> _sendTokenToServer(String token) async {
    if (_isTokenSentToServer) {
      _logger.i('Token zaten sunucuya gönderilmiş durumda, tekrar gönderilmiyor');
      debugPrint('Token zaten sunucuya gönderilmiş durumda, tekrar gönderilmiyor');
      return;
    }
    
    _logger.i('FCM token backend\'e gönderiliyor...');
    debugPrint('FCM token backend\'e gönderiliyor...');
    
    // 3 deneme yapacak şekilde ayarlıyoruz
    for (int i = 0; i < 3; i++) {
      try {
        // UserService aracılığıyla token'ı backend'e gönder
        final bool success = await _userService.updateFcmToken(token);
        
        if (success) {
          _logger.i('FCM token başarıyla backend\'e gönderildi (deneme ${i+1})');
          debugPrint('FCM token başarıyla backend\'e gönderildi (deneme ${i+1})');
          _isTokenSentToServer = true;
          return; // Başarılı olduğu için döngüden çık
        } else {
          _logger.w('FCM token backend\'e gönderilemedi (deneme ${i+1})');
          debugPrint('FCM token backend\'e gönderilemedi (deneme ${i+1})');
          
          // Son deneme değilse bekle ve tekrar dene
          if (i < 2) {
            _logger.i('${(i+1)*2} saniye sonra tekrar denenecek...');
            debugPrint('${(i+1)*2} saniye sonra tekrar denenecek...');
            await Future.delayed(Duration(seconds: (i+1)*2));
          }
        }
      } catch (e) {
        _logger.e('FCM token gönderilirken hata (deneme ${i+1}): $e');
        debugPrint('FCM token gönderilirken hata (deneme ${i+1}): $e');
        
        // Son deneme değilse bekle ve tekrar dene
        if (i < 2) {
          _logger.i('${(i+1)*2} saniye sonra tekrar denenecek...');
          debugPrint('${(i+1)*2} saniye sonra tekrar denenecek...');
          await Future.delayed(Duration(seconds: (i+1)*2));
        }
      }
    }
    
    _logger.e('FCM token 3 deneme sonrasında da gönderilemedi! Bildirimler çalışmayabilir.');
    debugPrint('FCM token 3 deneme sonrasında da gönderilemedi! Bildirimler çalışmayabilir.');
  }
  
  /// Abone olunan konuları listele (Debug için)
  Future<void> debugTopics() async {
    _logger.i('Abone olunan konular sorgulanamıyor (Firebase API\'de bu özellik yok).');
    debugPrint('Abone olunan konular sorgulanamıyor (Firebase API\'de bu özellik yok).');
  }
  
  /// Belirli bir konuya abone ol
  Future<bool> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
      _logger.i('$topic konusuna başarıyla abone olundu');
      debugPrint('$topic konusuna başarıyla abone olundu');
      return true;
    } catch (e) {
      _logger.e('$topic konusuna abone olunamadı: $e');
      debugPrint('$topic konusuna abone olunamadı: $e');
      return false;
    }
  }
  
  /// Belirli bir konudan aboneliği kaldır
  Future<bool> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
      _logger.i('$topic konusundan abonelik başarıyla kaldırıldı');
      debugPrint('$topic konusundan abonelik başarıyla kaldırıldı');
      return true;
    } catch (e) {
      _logger.e('$topic konusundan abonelik kaldırılamadı: $e');
      debugPrint('$topic konusundan abonelik kaldırılamadı: $e');
      return false;
    }
  }
  
  /// Mevcut bildirim izinlerini kontrol et
  Future<NotificationSettings> checkPermissions() async {
    final settings = await _messaging.getNotificationSettings();
    _logger.i('Bildirim izin durumu: ${settings.authorizationStatus}');
    debugPrint('Bildirim izin durumu: ${settings.authorizationStatus}');
    return settings;
  }
  
  /// FCM token'ını döndür
  String? getToken() {
    return _fcmToken;
  }
  
  /// Teşhis bilgisi yazdır
  Future<void> printDiagnostics() async {
    _logger.i('===== FCM Teşhis Bilgileri =====');
    _logger.i('FCM Token: $_fcmToken');
    _logger.i('Token sunucuya gönderildi: $_isTokenSentToServer');
    
    debugPrint('===== FCM Teşhis Bilgileri =====');
    debugPrint('FCM Token: $_fcmToken');
    debugPrint('Token sunucuya gönderildi: $_isTokenSentToServer');
    
    final settings = await _messaging.getNotificationSettings();
    _logger.i('Bildirim İzinleri: ${settings.authorizationStatus}');
    debugPrint('Bildirim İzinleri: ${settings.authorizationStatus}');
    
    if (Platform.isIOS) {
      final apnsToken = await _messaging.getAPNSToken();
      _logger.i('APNs Token: $apnsToken');
      debugPrint('APNs Token: $apnsToken');
    }
    
    _logger.i('===============================');
    debugPrint('===============================');
  }
} 