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
            // Önceki bildirimleri kullan (varsa) - çevrimdışı erişimi desteklemek için
            if (_notifications != null && _notifications!.isNotEmpty) {
              _logger.i('Önbellekteki bildirimler kullanılıyor (${_notifications!.length} bildirim)');
              return _notifications;
            }
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
      
      // API için payload oluştur
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
        payload['message']['data'] = data;
      }
      
      _logger.i('============= FCM GÖNDERİLEN BİLDİRİM PAYLOAD =============');
      _logger.i(jsonEncode(payload));
      _logger.i('=============================================================');
      
      // FCM API'ye POST isteği gönder
      final response = await http.post(
        Uri.parse(_fcmApiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_fcmServerKey',
        },
        body: jsonEncode(payload),
      );
      
      _logger.i('FCM API Yanıt Kodu: ${response.statusCode}');
      _logger.i('FCM API Yanıt: ${response.body}');
      
      if (response.statusCode == 200) {
        _logger.i('Bildirim başarıyla gönderildi');
        return true;
      } else {
        _logger.e('Bildirim gönderilemedi: ${response.statusCode} - ${response.body}');
        
        // HTTP v1 API'de 401 genellikle yetkilendirme hatasıdır, legacy API'yi deneyelim
        if (response.statusCode == 401 || response.statusCode == 403) {
          _logger.i('Legacy API ile bildirim gönderme deneniyor...');
          return sendPushNotificationLegacy(
            topic: topic,
            title: title,
            body: body,
            data: data
          );
        }
        
        return false;
      }
    } catch (e) {
      _logger.e('Bildirim gönderilirken hata: $e');
      
      // Hata alındığında legacy API'yi dene
      try {
        _logger.i('Hata nedeniyle Legacy API ile bildirim gönderme deneniyor...');
        return sendPushNotificationLegacy(
          topic: topic,
          title: title,
          body: body,
          data: data
        );
      } catch (legacyError) {
        _logger.e('Legacy API ile bildirim gönderme de başarısız oldu: $legacyError');
        return false;
      }
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
      
      // Topic formatını kontrol et
      String formattedTopic = topic;
      if (!topic.startsWith('/topics/')) {
        formattedTopic = '/topics/$topic';
      }
      
      // Legacy API için daha basit payload
      final Map<String, dynamic> payload = {
        'to': formattedTopic,
        'notification': {
          'title': title,
          'body': body,
          'sound': 'default'
        },
        'priority': 'high'
      };
      
      // Eğer data varsa ekle
      if (data != null && data.isNotEmpty) {
        payload['data'] = data;
      }
      
      _logger.i('============= LEGACY FCM GÖNDERİLEN BİLDİRİM PAYLOAD =============');
      _logger.i(jsonEncode(payload));
      _logger.i('====================================================================');
      
      // FCM Legacy API'ye POST isteği
      final response = await http.post(
        Uri.parse(_fcmLegacyApiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=$_fcmServerKey',
        },
        body: jsonEncode(payload),
      );
      
      _logger.i('Legacy FCM API Yanıt Kodu: ${response.statusCode}');
      _logger.i('Legacy FCM API Yanıt: ${response.body}');
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == 1) {
          _logger.i('Bildirim başarıyla gönderildi (Legacy API)');
          return true;
        } else {
          _logger.w('Bildirim gönderildi ama başarısız olabilir: ${responseData['results'] ?? response.body}');
          _logger.w('Hata Nedeni: ${responseData['failure'] ?? "Bilinmiyor"}');
          return false;
        }
      } else {
        _logger.e('Bildirim gönderilemedi: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      _logger.e('Bildirim gönderilirken hata (Legacy API): $e');
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
    
    // FCM token bilgilerini logla (debug için)
    printFcmTokenInfo();
    
    // Ayarlanan FCM Server Key'in bilgilerini göster
    _logger.i('================ FCM SERVER KEY BİLGİLERİ ================');
    _logger.i('Server Key: ${_fcmServerKey?.substring(0, 15)}...[gizlendi]');
    _logger.i('=======================================================');
  }
  
  // OAuth Bearer Token veya Server Key'i formatına göre otomatik ayarla
  bool setFcmCredential(String credential) {
    try {
      // Geçersiz kimlik bilgisi kontrolü
      if (credential.isEmpty || credential == 'YOUR_FCM_CREDENTIAL' || credential == 'AAAA-XXXXXX-XXXXXX') {
        _logger.e('❌ Geçersiz FCM kimlik bilgisi! Firebase Console\'dan gerçek bir Server Key almalısınız.');
        _logger.i('📋 FCM Server Key alım adımları:');
        _logger.i('  1. Firebase Console\'a giriş yapın');
        _logger.i('  2. Projenizi seçin');
        _logger.i('  3. Proje Ayarları > Cloud Messaging');
        _logger.i('  4. Server Key\'i kopyalayın (AAAA ile başlar)');
        return false;
      }
      
      if (credential.startsWith('AAAA') || credential.startsWith('AIza')) {
        // Legacy API için server key formatı
        _fcmServerKey = credential;
        _logger.i('✅ FCM Legacy Server Key başarıyla ayarlandı');
        
        // Server key örnek test edin
        _logger.i('🔍 FCM Server Key formatı doğru görünüyor, ancak geçerliliğini test etmelisiniz.');
        _logger.i('📱 Postman veya cURL ile test mesajı göndererek doğrulayın.');
        return true;
      } else if (credential.contains('.') && credential.contains('_')) {
        // OAuth Bearer Token formatı
        _fcmServerKey = credential;
        _logger.i('✅ FCM HTTP v1 API Bearer Token başarıyla ayarlandı');
        return true;
      } else {
        _logger.e('❌ Geçersiz FCM kimlik bilgisi formatı!');
        _logger.e('FCM Server Key "AAAA" ile başlamalıdır.');
        _logger.i('Firebase Console > Project Settings > Cloud Messaging > Server Key');
        return false;
      }
    } catch (e) {
      _logger.e('❌ FCM kimlik bilgisi ayarlanırken hata: $e');
      return false;
    }
  }
  
  // Kullanıcıyı kendi ID'sine göre FCM topic'ine abone et
  Future<bool> subscribeToUserTopic(int userId) async {
    try {
      final userIdStr = userId.toString();
      // FCM topic isimlendirme kurallarına uygun topic oluştur
      // Firebase sadece [a-zA-Z0-9-_.~%] karakterlerine izin verir
      final topicName = "user_$userIdStr";
      
      _logger.i('Kullanıcı ID topic\'ine abone olunuyor: $topicName');
      await _firebaseMessaging.subscribeToTopic(topicName);
      _logger.i('Kullanıcı topic\'ine başarıyla abone edildi: $topicName');
      return true;
    } catch (e) {
      _logger.e('Kullanıcı topic aboneliği başarısız: $e');
      return false;
    }
  }
  
  // Kullanıcıyı hızlıca gerekli tüm topic'lere abone et
  Future<void> subscribeUserToRequiredTopics(int userId, List<int> groupIds) async {
    try {
      // Sadece kullanıcı ID'sine abone et
      final userIdStr = userId.toString();
      // FCM topic isimlendirme kurallarına uygun topic oluştur
      final topicName = "user_$userIdStr";
      
      _logger.i('Kullanıcı topic\'ine abone olunuyor: $topicName');
      await _firebaseMessaging.subscribeToTopic(topicName);
      _logger.i('✅ Kullanıcı topic\'ine başarıyla abone edildi: $topicName');
      
      // Gruplar için topic aboneliği yapılmıyor - kullanıcı istemiyor
      _logger.i('ℹ️ Grup topic abonelikleri yapılandırma nedeniyle atlandı');
    } catch (e) {
      _logger.e('❌ Kullanıcı topic aboneliği başarısız: $e');
    }
  }
  
  // Topic aboneliği debug kodu
  Future<void> debugTopics() async {
    try {
      // Mevcut token'ı log'la
      final token = await _firebaseMessaging.getToken();
      _logger.i('Mevcut FCM Token: $token');
      
      // Kullanıcı ID'sini UserService'ten al
      try {
        final userResponse = await _userService.getUser();
        if (userResponse.success && userResponse.data != null) {
          final userId = userResponse.data!.user.userID.toString();
          
          // Kullanıcının kendi ID'sine göre topic'e abone ol
          // FCM topic isimlendirme kurallarına uygun topic oluştur
          final topicName = "user_$userId";
          await _firebaseMessaging.subscribeToTopic(topicName);
          _logger.i('Topic "$topicName" aboneliği yapıldı');
          
          // Normal ID'ye de abone ol (eski format için)
          await _firebaseMessaging.subscribeToTopic(userId);
          _logger.i('Eski format topic "$userId" aboneliği yapıldı');
          
          // APNs token bilgisini log'la (iOS için)
          if (Platform.isIOS) {
            final apnsToken = await _firebaseMessaging.getAPNSToken();
            _logger.i('APNs Token: $apnsToken');
          }
          
          // Örnek Postman JSON formatını yazdır
          _printSamplePostmanJson(topicName);
        } else {
          _logger.w('Kullanıcı bilgileri alınamadı, otomatik topic aboneliği yapılamadı');
        }
      } catch (e) {
        _logger.e('Kullanıcı bilgileri alınırken hata: $e');
      }
    } catch (e) {
      _logger.e('Topic debug hatası: $e');
    }
  }
  
  // Postman için örnek JSON formatı
  void _printSamplePostmanJson(String topic) {
    final fcmSample = {
      "to": "/topics/$topic",
      "notification": {
        "title": "Test Bildirimi",
        "body": "FCM topic test mesajı"
      },
      "data": {
        "type": "test",
        "id": "1234"
      }
    };
    
    _logger.i('======== FCM POSTMAN TEST JSON ========');
    _logger.i(jsonEncode(fcmSample));
    _logger.i('=======================================');
    
    final httpHeaders = {
      'Content-Type': 'application/json',
      'Authorization': 'key=YOUR_FCM_SERVER_KEY_HERE'
    };
    
    _logger.i('======== FCM HTTP HEADERS ========');
    _logger.i(jsonEncode(httpHeaders));
    _logger.i('==================================');
    
    _logger.i('POST isteğini https://fcm.googleapis.com/fcm/send adresine yapabilirsiniz');
  }
  
  // FCM bildirim sorunlarını teşhis et
  Future<void> diagnosticFCM() async {
    _logger.i('========== FCM TEŞHIS BAŞLIYOR ==========');
    
    try {
      // 1. FCM token kontrolü
      final token = await _firebaseMessaging.getToken();
      if (token == null || token.isEmpty) {
        _logger.e('❌ FCM Token alınamadı! Firebase yapılandırmanızı kontrol edin.');
      } else {
        _logger.i('✅ FCM Token mevcut: ${token.substring(0, 15)}...');
      }
      
      // 2. Bildirim izinleri kontrolü
      final settings = await _firebaseMessaging.getNotificationSettings();
      _logger.i('📱 Bildirim izin durumu: ${settings.authorizationStatus}');
      
      if (settings.authorizationStatus != AuthorizationStatus.authorized) {
        _logger.e('❌ Bildirim izni verilmemiş! Kullanıcı bildirimlere izin vermeli.');
      } else {
        _logger.i('✅ Bildirim izinleri onaylanmış.');
      }
      
      // 3. Platform özel kontroller
      if (Platform.isIOS) {
        final apnsToken = await _firebaseMessaging.getAPNSToken();
        if (apnsToken == null || apnsToken.isEmpty) {
          _logger.e('❌ APNs token alınamadı! iOS bildirim sorunları olabilir.');
        } else {
          _logger.i('✅ APNs token mevcut: $apnsToken');
        }
        
        _logger.i('📋 iOS bildirim kontrol listesi:');
        _logger.i('  1. Xcode\'da Push Notifications capability eklenmiş mi?');
        _logger.i('  2. APN sertifikaları Firebase konsoluna yüklenmiş mi?');
        _logger.i('  3. Gerçek cihaz kullanıyor musunuz? (Simulator\'da bildirimler çalışmaz)');
      }
      
      // 4. Topic aboneliklerini kontrol et
      try {
        final userResponse = await _userService.getUser();
        if (userResponse.success && userResponse.data != null) {
          final userId = userResponse.data!.user.userID.toString();
          _logger.i('✅ Kullanıcı ID: $userId');
          
          // Topic isimlerini yazdır
          final userTopic = "user_$userId";
          _logger.i('📌 Kullanıcı topic: $userTopic');
          
          // Topic abonelikleri (bunları kontrol edemeyiz ama log'layabiliriz)
          _logger.i('📋 Topic abonelik kontrol listesi:');
          _logger.i('  - Kullanıcı topic\'e abone olundu mu?');
          _logger.i('  - Topic bildirim gönderirken tam olarak bu format kullanılıyor mu?');
        } else {
          _logger.e('❌ Kullanıcı bilgileri alınamadı!');
        }
      } catch (e) {
        _logger.e('❌ Topic kontrolü sırasında hata: $e');
      }
      
      // 5. Firebase Yapılandırma Kontrolü
      _logger.i('📋 Firebase yapılandırma kontrol listesi:');
      _logger.i('  1. google-services.json ve GoogleService-Info.plist dosyaları doğru mu?');
      _logger.i('  2. Firebase Console\'da Cloud Messaging API etkin mi?');
      _logger.i('  3. FCM server key güncel mi?');
      
      // 6. Öneri ve hata giderme adımları
      _logger.i('🔍 Hata ayıklama adımları:');
      _logger.i('  1. Uygulamayı kapatıp yeniden açmayı deneyin');
      _logger.i('  2. FCM server key\'in doğru olduğundan emin olun');
      _logger.i('  3. Bildirim payload formatını kontrol edin');
      _logger.i('  4. iOS için arka plan bildirimleri etkinleştirin');
      
      // 7. Firebase token'ı yazdır (sunucuya gönderilmiş mi?)
      try {
        await sendTokenToServer();
        _logger.i('✅ FCM token sunucuya gönderildi');
      } catch (e) {
        _logger.e('❌ FCM token sunucuya gönderilemedi: $e');
      }
      
      // 8. Test bildirim JSON örneği
      _printSamplePushMessage(token!);
      
      // 9. Backend/API durumu kontrolü
      _logger.i('📋 Backend bildirim kontrolü:');
      _logger.i('  1. Backend\'in FCM bildirim gönderme yetkisi var mı?');
      _logger.i('  2. Backend log\'larında bildirim hataları var mı?');
      _logger.i('  3. Backend\'de kullanıcı FCM token\'ı güncel mi?');
    } catch (e) {
      _logger.e('❌ FCM teşhis sırasında hata: $e');
    }
    
    _logger.i('========== FCM TEŞHIS TAMAMLANDI ==========');
  }
  
  // Test bildirimi için örnek
  void _printSamplePushMessage(String token) {
    // Doğrudan cihaza bildirim formatı
    final directMessage = {
      "message": {
        "token": token,
        "notification": {
          "title": "Doğrudan Test",
          "body": "Bu doğrudan cihaza gönderilen test bildirimidir"
        },
        "data": {
          "type": "direct_test",
          "click_action": "FLUTTER_NOTIFICATION_CLICK"
        }
      }
    };
    
    // Topic'e bildirim formatı
    final topicMessage = {
      "message": {
        "topic": "user_[KULLANICI_ID]",
        "notification": {
          "title": "Topic Test",
          "body": "Bu topic üzerinden gönderilen test bildirimidir"
        },
        "data": {
          "type": "topic_test",
          "click_action": "FLUTTER_NOTIFICATION_CLICK"
        }
      }
    };
    
    _logger.i('======== DOĞRUDAN FCM TEST MESAJI ========');
    _logger.i(jsonEncode(directMessage));
    _logger.i('==========================================');
    
    _logger.i('======== TOPIC FCM TEST MESAJI ========');
    _logger.i(jsonEncode(topicMessage));
    _logger.i('=======================================');
    
    _logger.i('Firebase Admin SDK veya FCM HTTP v1 API kullanarak bu mesajları gönderebilirsiniz.');
    _logger.i('https://firebase.google.com/docs/cloud-messaging/send-message adresini ziyaret edin.');
  }
} 