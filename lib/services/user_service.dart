import '../models/user_model.dart';
import '../models/group_models.dart';
import '../models/notification_model.dart';
import '../services/logger_service.dart';
import '../services/storage_service.dart';
import 'base_api_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class UserService {
  static final UserService _instance = UserService._internal();
  final BaseApiService _apiService = BaseApiService();
  final StorageService _storageService = StorageService();
  final LoggerService _logger = LoggerService();

  factory UserService() {
    return _instance;
  }

  UserService._internal();

  // Kullanıcı Bilgilerini Getir
  Future<UserResponse> getUser() async {
    final token = _storageService.getToken();
    if (token == null) {
      throw Exception('Token bulunamadı. Lütfen tekrar giriş yapın.');
    }

    final platform = _apiService.getPlatform();
    final version = _apiService.getAppVersion();
    
    final body = {
      'userToken': token,
      'platform': platform,
      'version': version,
    };

    final response = await _apiService.put(
      'service/user/id',
      body: body,
      requiresToken: true,
    );

    final userResponse = UserResponse.fromJson(response);
    
    // Platform ve versiyon kontrolü
    if (userResponse.success == true && userResponse.data != null) {
      final user = userResponse.data!.user;
      
      // Platform'a göre kontroller
      if (platform == 'ios' && user.iosVersion != version) {
        _logger.w('iOS versiyonu güncel değil: ${user.iosVersion} vs $version');
        // Burada güncelleme uyarısı işlenebilir
      } else if (platform == 'android' && user.androidVersion != version) {
        _logger.w('Android versiyonu güncel değil: ${user.androidVersion} vs $version');
        // Burada güncelleme uyarısı işlenebilir
      }
    }
    
    return userResponse;
  }

  // Kullanıcı bilgilerini güncelle
  Future<UserResponse> updateUserProfile({
    required String userFullname,
    required String userEmail,
    required String userBirthday,
    required String userPhone,
    required int userGender,
    required String profilePhoto,
  }) async {
    try {
      final token = await _storageService.getToken();
      if (token == null) {
        throw Exception('Oturum bilgisi bulunamadı');
      }

      final body = {
        'userToken': token,
        'userFullname': userFullname,
        'userEmail': userEmail,
        'userBirthday': userBirthday,
        'userPhone': userPhone,
        'userGender': userGender,
        'profilePhoto': profilePhoto,
      };

      _logger.i('Kullanıcı profili güncelleniyor...');
      final response = await _apiService.put('service/user/update/account', body: body);
      
      final userResponse = UserResponse.fromJson(response);
      if (userResponse.success) {
        _logger.i('Kullanıcı profili başarıyla güncellendi');
      } else {
        _logger.w('Kullanıcı profili güncellenemedi: ${userResponse.errorMessage}');
      }
      
      return userResponse;
    } catch (e) {
      _logger.e('Kullanıcı profili güncellenirken hata: $e');
      throw Exception('Kullanıcı profili güncellenemedi: $e');
    }
  }

  // FCM token'ı sunucuya kaydet
  Future<bool> updateFcmToken(String fcmToken) async {
    try {
      final token = await _storageService.getToken();
      if (token == null) {
        _logger.w('FCM token kaydedilemedi: Oturum bilgisi bulunamadı');
        throw Exception('Oturum bilgisi bulunamadı');
      }

      final platform = _apiService.getPlatform();
      
      _logger.i('-------------------------------------------------------------------------');
      _logger.i('FCM Token Sunucuya Gönderiliyor:');
      _logger.i('Platform: $platform');
      _logger.i('Token: $fcmToken');
      _logger.i('-------------------------------------------------------------------------');
      
      final body = {
        'userToken': token,
        'fcmToken': fcmToken,
        'platform': platform,
      };

      final response = await _apiService.put('service/user/update/fcmtoken', body: body);
      
      final success = response['success'] == true;
      if (success) {
        _logger.i('FCM token başarıyla kaydedildi');
        _logger.i('Sunucu Yanıtı: $response');
      } else {
        _logger.w('FCM token kaydedilemedi: ${response['errorMessage']}');
        _logger.w('Sunucu Yanıtı: $response');
      }
      
      return success;
    } catch (e) {
      _logger.e('FCM token kaydedilirken hata: $e');
      return false;
    }
  }

  // Kullanıcının görevlerini getir
  Future<UserWorksResponse> getUserWorks() async {
    try {
      final token = await _storageService.getToken();
      if (token == null) {
        throw Exception('Oturum bilgisi bulunamadı');
      }

      final body = {
        'userToken': token,
      };

      _logger.i('Kullanıcı görevleri getiriliyor...');
      final response = await _apiService.post('service/user/project/workListUser', body: body);
      
      final worksResponse = UserWorksResponse.fromJson(response);
      _logger.i('Kullanıcı görevleri başarıyla getirildi: ${worksResponse.data?.works.length ?? 0} görev');
      
      return worksResponse;
    } catch (e) {
      _logger.e('Kullanıcı görevleri yüklenirken hata: $e');
      throw Exception('Kullanıcı görevleri yüklenemedi: $e');
    }
  }

  // Kullanıcı bildirimlerini getir
  Future<NotificationResponse> getNotifications() async {
    try {
      final token = await _storageService.getToken();
      if (token == null) {
        throw Exception('Oturum bilgisi bulunamadı');
      }

      // Kullanıcı ID'sini al
      final userResponse = await getUser();
      if (!userResponse.success || userResponse.data == null) {
        throw Exception('Kullanıcı bilgileri alınamadı');
      }

      final userId = userResponse.data!.user.userID;

      final body = {
        'userToken': token,
      };

      _logger.i('Kullanıcı bildirimleri getiriliyor...');
      final response = await _apiService.put('service/user/account/$userId/notifications', body: body);
      
      final notificationResponse = NotificationResponse.fromJson(response);
      if (notificationResponse.success) {
        _logger.i('Kullanıcı bildirimleri başarıyla getirildi: ${notificationResponse.notifications?.length ?? 0} bildirim');
      } else {
        _logger.w('Kullanıcı bildirimleri getirilemedi: ${notificationResponse.errorMessage}');
      }
      
      return notificationResponse;
    } catch (e) {
      _logger.e('Bildirimler yüklenirken hata: $e');
      throw Exception('Bildirimler yüklenemedi: $e');
    }
  }

  // Bildirimi okundu olarak işaretle
  Future<bool> markNotificationAsRead(int notificationId) async {
    try {
      final token = await _storageService.getToken();
      if (token == null) {
        throw Exception('Oturum bilgisi bulunamadı');
      }

      final body = {
        'userToken': token,
        'notificationId': notificationId,
      };

      _logger.i('Bildirim okundu olarak işaretleniyor: $notificationId');
      final response = await _apiService.put('service/user/account/notification/read', body: body);
      
      final success = response['success'] == true;
      if (success) {
        _logger.i('Bildirim başarıyla okundu olarak işaretlendi');
      } else {
        _logger.w('Bildirim okundu olarak işaretlenemedi: ${response['errorMessage']}');
      }
      
      return success;
    } catch (e) {
      _logger.e('Bildirim okundu olarak işaretlenirken hata: $e');
      return false;
    }
  }
} 