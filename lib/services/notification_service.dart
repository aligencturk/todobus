import 'dart:io';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;
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
  
  // FCM API için gerekli bilgiler
  static const String _fcmApiUrl = 'https://fcm.googleapis.com/v1/projects/todobus-3fc9b/messages:send';
  static const String _fcmLegacyApiUrl = 'https://fcm.googleapis.com/fcm/send';
  String? _fcmServerKey; // FCM server key
  
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
      try {
        bool tokenSent = await _userService.updateFcmToken(_fcmToken!);
        if (tokenSent) {
          _logger.i('FCM Token sunucuya başarıyla gönderildi: $_fcmToken');
        } else {
          _logger.w('FCM Token sunucuya gönderilemedi! 5 saniye sonra tekrar denenecek.');
          // Bir süre bekledikten sonra tekrar deneyelim
          await Future.delayed(const Duration(seconds: 5));
          tokenSent = await _userService.updateFcmToken(_fcmToken!);
          
          if (tokenSent) {
            _logger.i('FCM Token sunucuya başarıyla gönderildi (ikinci deneme): $_fcmToken');
          } else {
            _logger.w('FCM Token sunucuya ikinci denemede de gönderilemedi!');
          }
        }
      } catch (e) {
        _logger.e('FCM Token gönderilirken beklenmeyen hata: $e');
      }
    } else {
      _logger.w('FCM Token alınamadı, sunucuya gönderilemiyor!');
    }
    
    // Token yenilendiğinde olayı dinle
    _firebaseMessaging.onTokenRefresh.listen((newToken) async {
      _fcmToken = newToken;
      _logger.i('-------------------  FCM TOKEN YENİLENDİ  -------------------');
      _logger.i('Yeni FCM Token: $_fcmToken');
      _logger.i('---------------------------------------------------------------');
      
      // Yeni token'ı sunucuya gönder
      if (_fcmToken != null) {
        try {
          bool tokenSent = await _userService.updateFcmToken(_fcmToken!);
          if (tokenSent) {
            _logger.i('Yenilenen FCM Token sunucuya gönderildi.');
          } else {
            _logger.w('Yenilenen FCM Token sunucuya gönderilemedi! 5 saniye sonra tekrar denenecek.');
            // Bir süre bekledikten sonra tekrar deneyelim
            await Future.delayed(const Duration(seconds: 5));
            tokenSent = await _userService.updateFcmToken(_fcmToken!);
            
            if (tokenSent) {
              _logger.i('Yenilenen FCM Token sunucuya başarıyla gönderildi (ikinci deneme).');
            } else {
              _logger.w('Yenilenen FCM Token sunucuya ikinci denemede de gönderilemedi!');
            }
          }
        } catch (e) {
          _logger.e('Yenilenen FCM Token gönderilirken beklenmeyen hata: $e');
        }
      } else {
        _logger.w('Yenilenen FCM Token alınamadı, sunucuya gönderilemiyor!');
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
        
        // 3 saniye bekleyip tekrar deneyelim
        await Future.delayed(const Duration(seconds: 3));
        try {
          _logger.i('Bildirimler tekrar yükleniyor...');
          final retryResponse = await _userService.getNotifications();
          
          if (retryResponse.success && retryResponse.notifications != null) {
            _notifications = retryResponse.notifications;
            _unreadCount = retryResponse.unreadCount ?? 0;
            _logger.i('Bildirimler ikinci denemede başarıyla alındı: ${_notifications?.length} bildirim');
            return _notifications;
          } else {
            _logger.w('Bildirimler ikinci denemede de alınamadı: ${retryResponse.errorMessage}');
            return null;
          }
        } catch (retryError) {
          _logger.e('Bildirimleri tekrar yüklerken hata: $retryError');
          return null;
        }
      }
    } catch (e) {
      _logger.e('Bildirimler yüklenirken hata: $e');
      
      // Önceki bildirimleri kullan (varsa) - çevrimdışı erişimi desteklemek için
      if (_notifications != null && _notifications!.isNotEmpty) {
        _logger.i('Önbellekteki bildirimler kullanılıyor (${_notifications!.length} bildirim)');
        return _notifications;
      }
      
      return null;
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
  
  // FCM kullanarak konuya bildirim gönder
  Future<bool> sendPushNotification({
    required String topic, 
    required String title, 
    required String body,
    Map<String, dynamic>? data
  }) async {
    try {
      _logger.i('FCM Bildirimi gönderiliyor - Topic: $topic, Başlık: $title');
      
      // FCM HTTP v1 API için server key gerekli (Firebase Console'dan alınabilir)
      if (_fcmServerKey == null || _fcmServerKey!.isEmpty) {
        _logger.e('FCM Server key bulunamadı');
        return false;
      }
      
      // API için payload oluştur - kullanıcı örneğindeki JSON formatına benzer
      final Map<String, dynamic> payload = {
        'message': {
          'topic': topic,
          'notification': {
            'title': title,
            'body': body
          }
        }
      };
      
      // Eğer data kısmı varsa ekle
      if (data != null && data.isNotEmpty) {
        // String formatında JSON olarak gönderilmesi gerekiyor
        payload['message']['data'] = {
          'keysandvalues': jsonEncode(data)
        };
      }
      
      // FCM API'ye POST isteği gönder
      final response = await http.post(
        Uri.parse(_fcmApiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_fcmServerKey',
        },
        body: jsonEncode(payload),
      );
      
      if (response.statusCode == 200) {
        _logger.i('Bildirim başarıyla gönderildi: ${response.body}');
        return true;
      } else {
        _logger.e('Bildirim gönderilemedi: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      _logger.e('Bildirim gönderilirken hata: $e');
      return false;
    }
  }
  
  // Kullanıcıları bir konuya abone et
  Future<bool> subscribeUserToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      _logger.i('Kullanıcı "$topic" konusuna abone edildi');
      return true;
    } catch (e) {
      _logger.e('Konuya abone olunurken hata: $e');
      return false;
    }
  }
  
  // Legacy FCM API kullanarak bildirim gönderme (daha basit)
  Future<bool> sendPushNotificationLegacy({
    required String topic, 
    required String title, 
    required String body,
    Map<String, dynamic>? data
  }) async {
    try {
      _logger.i('FCM Bildirimi gönderiliyor (Legacy API) - Topic: $topic, Başlık: $title');
      
      if (_fcmServerKey == null || _fcmServerKey!.isEmpty) {
        _logger.e('FCM Server key bulunamadı');
        return false;
      }
      
      // Legacy API için daha basit payload
      final Map<String, dynamic> payload = {
        'to': '/topics/$topic',
        'notification': {
          'title': title,
          'body': body,
          'sound': 'default'
        },
      };
      
      // Eğer data varsa ekle
      if (data != null && data.isNotEmpty) {
        payload['data'] = data;
      }
      
      // FCM Legacy API'ye POST isteği
      final response = await http.post(
        Uri.parse(_fcmLegacyApiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=$_fcmServerKey',
        },
        body: jsonEncode(payload),
      );
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == 1) {
          _logger.i('Bildirim başarıyla gönderildi: ${response.body}');
          return true;
        } else {
          _logger.w('Bildirim gönderildi ama başarısız olabilir: ${response.body}');
          return false;
        }
      } else {
        _logger.e('Bildirim gönderilemedi: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      _logger.e('Bildirim gönderilirken hata: $e');
      return false;
    }
  }
  
  // Yardımcı metodları Legacy API'ye güncelle
  
  // Proje atama bildirimi
  Future<bool> sendProjectAssignedNotification({
    required String topic, 
    required String userName,
    required String projectName,
    required int projectId
  }) async {
    return sendPushNotificationLegacy(
      topic: topic,
      title: 'Yeni Proje!',
      body: '$userName sizi $projectName isimli projeye ekledi.',
      data: {
        'type': 'project_assigned',
        'id': projectId.toString() // FCM data sadece string değerlerini destekler
      }
    );
  }
  
  // Görev atama bildirimi
  Future<bool> sendTaskAssignedNotification({
    required String topic, 
    required String userName,
    required String taskName,
    required int taskId,
    required int projectId
  }) async {
    return sendPushNotificationLegacy(
      topic: topic,
      title: 'Yeni Görev!',
      body: '$userName size "$taskName" görevini atadı.',
      data: {
        'type': 'task_assigned',
        'task_id': taskId.toString(),
        'project_id': projectId.toString()
      }
    );
  }
  
  // FCM server key ayarla
  void setFcmServerKey(String key) {
    _fcmServerKey = key;
    _logger.i('FCM Server key ayarlandı');
  }
  
  // Kullanıcıyı kendi ID'sine göre FCM topic'ine abone et
  Future<bool> subscribeToUserTopic(int userId) async {
    try {
      final userIdStr = userId.toString();
      await _firebaseMessaging.subscribeToTopic(userIdStr);
      _logger.i('Kullanıcı kendi ID\'sine ($userIdStr) abone edildi');
      return true;
    } catch (e) {
      _logger.e('Kullanıcı topic aboneliği başarısız: $e');
      return false;
    }
  }
  
  // Kullanıcıyı hızlıca gerekli tüm topic'lere abone et
  Future<void> subscribeUserToRequiredTopics(int userId, List<int> groupIds) async {
    // Kullanıcı ID'sine abone et
    await subscribeToUserTopic(userId);
    _logger.i('Kullanıcı kendi ID\'sine abone edildi: $userId');
    
    // Kullanıcının gruplarına abone et
    for (final groupId in groupIds) {
      await subscribeUserToTopic(groupId.toString());
      _logger.i('Kullanıcı grup ID\'sine abone edildi: $groupId');
    }
  }
} 