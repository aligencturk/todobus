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
    if (userResponse.success == true && userResponse.data != null && userResponse.code != 410) {
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
    required int userGender,
    required String profilePhoto,
  }) async {
    try {
      _logger.i('Kullanıcı profili güncelleme başlatılıyor...');
      _logger.i('userFullname: $userFullname');
      _logger.i('userEmail: $userEmail');
      _logger.i('userBirthday: $userBirthday');

      _logger.i('userGender: $userGender');
      
      // Veri kontrolü
      if (userFullname.isEmpty) {
        return UserResponse(
          error: true,
          success: false,
          errorMessage: 'Ad Soyad alanı boş olamaz',
        );
      }
      
      if (userEmail.isEmpty || !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(userEmail)) {
        return UserResponse(
          error: true,
          success: false,
          errorMessage: 'Geçerli bir e-posta adresi giriniz',
        );
      }
      
      // Doğum tarihi formatını kontrol et (eğer varsa)
      if (userBirthday.isNotEmpty && !RegExp(r'^\d{2}\.\d{2}\.\d{4}$').hasMatch(userBirthday)) {
        return UserResponse(
          error: true,
          success: false,
          errorMessage: 'Doğum tarihi GG.AA.YYYY formatında olmalıdır',
        );
      }
      
      // UserGender değerini kontrol et ve sınırla
      final validatedGender = userGender >= 0 && userGender <= 2 ? userGender : 0;
      
      final token = await _storageService.getToken();
      if (token == null) {
        _logger.w('Profil güncellenirken token bulunamadı');
        return UserResponse(
          error: true,
          success: false,
          errorMessage: 'Oturum bilgisi bulunamadı. Lütfen tekrar giriş yapınız.',
        );
      }

      final body = {
        'userToken': token,
        'userFullname': userFullname.trim(),
        'userEmail': userEmail.trim(),
        'userBirthday': userBirthday.trim(),

        'userGender': validatedGender,
        'profilePhoto': profilePhoto,
      };

      _logger.i('Kullanıcı profili güncelleniyor...');
      
      try {
        final response = await _apiService.put('service/user/update/account', body: body);
        
        if (response == null) {
          _logger.w('API yanıtı boş döndü');
          return UserResponse(
            error: true,
            success: false,
            errorMessage: 'Sunucudan yanıt alınamadı. Lütfen internet bağlantınızı kontrol ediniz.',
          );
        }
        
        final userResponse = UserResponse.fromJson(response);
        if (userResponse.success) {
          _logger.i('Kullanıcı profili başarıyla güncellendi');
        } else {
          _logger.w('Kullanıcı profili güncellenemedi: ${userResponse.errorMessage}');
        }
        
        return userResponse;
      } catch (apiError) {
        _logger.e('API isteği sırasında hata: $apiError');
        return UserResponse(
          error: true,
          success: false,
          errorMessage: 'Sunucu iletişiminde bir hata oluştu: ${apiError.toString()}',
        );
      }
    } catch (e) {
      _logger.e('Kullanıcı profili güncellenirken hata: $e');
      return UserResponse(
        error: true,
        success: false,
        errorMessage: 'Profil güncellenirken bir sorun oluştu. Lütfen daha sonra tekrar deneyiniz.',
      );
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
        'deviceId': await _apiService.getDeviceId(), // Cihaz kimliği eklendi
      };

      try {
        final response = await _apiService.put('service/user/update/fcmtoken', body: body);
        
        // API yanıtı kontrol et - loglardan görüldüğü gibi error: false, code: 200 geliyor
        final success = response['error'] == false || response['success'] == true || response['code'] == 200;
        
        if (success) {
          _logger.i('✅ FCM token başarıyla kaydedildi');
          _logger.i('Sunucu Yanıtı: $response');
        } else {
          _logger.w('⚠️ FCM token kaydedilemedi: ${response['errorMessage'] ?? response['message'] ?? 'Bilinmeyen hata'}');
          _logger.w('Sunucu Yanıtı: $response');
        }
        
        return success;
      } catch (apiError) {
        _logger.e('❌ FCM token API isteği başarısız: $apiError');
        
        // 3 saniye bekleyip tekrar dene
        await Future.delayed(const Duration(seconds: 3));
        try {
          _logger.i('🔄 FCM token kaydı tekrar deneniyor...');
          final response = await _apiService.put('service/user/update/fcmtoken', body: body);
          final success = response['error'] == false || response['success'] == true || response['code'] == 200;
          
          if (success) {
            _logger.i('✅ FCM token başarıyla kaydedildi (tekrar deneme)');
          } else {
            _logger.w('⚠️ FCM token tekrar deneme başarısız: ${response['errorMessage'] ?? response['message'] ?? 'Bilinmeyen hata'}');
          }
          
          return success;
        } catch (retryError) {
          _logger.e('❌ FCM token tekrar deneme başarısız: $retryError');
          return false;
        }
      }
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

  Future<NotificationResponse> getNotifications() async {
    try {
      final token = await _storageService.getToken();
      if (token == null) {
        throw Exception('Oturum bilgisi bulunamadı');
      }

      // Kullanıcı ID'sini al
      final userResponse = await getUser();

      // Backend 410 dönerse veya kullanıcı yoksa logout et
      if (!userResponse.success || userResponse.data == null) {
        _logger.w('Kullanıcı bilgileri alınamadı, oturum sonlandırılıyor...');
        return NotificationResponse(
          success: false,
          errorMessage: 'Kullanıcı oturumu sonlandı (410)',
          notifications: [],
        );
      }

      final userId = userResponse.data!.user.userID;

      final body = {
        'userToken': token,
      };

      _logger.i('Kullanıcı bildirimleri getiriliyor...');
      final response = await _apiService.put(
        'service/user/account/$userId/notifications',
        body: body,
      );

      final notificationResponse = NotificationResponse.fromJson(response);

      if (notificationResponse.success) {
        _logger.i('Kullanıcı bildirimleri başarıyla getirildi: ${notificationResponse.notifications?.length ?? 0} bildirim');
      } else {
        _logger.w('Kullanıcı bildirimleri getirilemedi: ${notificationResponse.errorMessage}');
      }

      return notificationResponse;
    } catch (e) {
      _logger.e('Bildirimler yüklenirken hata: $e');
      return NotificationResponse(
        success: false,
        errorMessage: 'Bildirimler yüklenemedi: ${e.toString()}',
        notifications: [],
      );
    }
  }

  // Kullanıcı şifresini güncelle
  Future<UserResponse> updatePassword({
    required String currentPassword,
    required String password,
    required String passwordAgain,
  }) async {
    try {
      final token = await _storageService.getToken();
      if (token == null) {
        throw Exception('Oturum bilgisi bulunamadı');
      }

      final body = {
        'userToken': token,
        'currentPassword': currentPassword,
        'password': password,
        'passwordAgain': passwordAgain,
      };

      _logger.i('Kullanıcı şifresi güncelleniyor...');
      
      try {
        final response = await _apiService.put('service/user/update/password', body: body);
        
        final userResponse = UserResponse.fromJson(response);
        if (userResponse.success) {
          _logger.i('Kullanıcı şifresi başarıyla güncellendi');
        } else {
          // API tarafından döndürülen hata mesajlarını kontrol et
          if (response.containsKey('errorMessage')) {
            final errorMsg = response['errorMessage'];
            _logger.w('Şifre güncellenirken API hatası: $errorMsg');
          } else {
            _logger.w('Şifre güncellenirken bilinmeyen bir hata oldu');
          }
        }
        
        return userResponse;
      } catch (apiError) {
        _logger.e('Şifre güncellenirken API hatası: $apiError');
        
        // Error mapping
        String errorMessage = 'Şifre güncellenirken bir hata oluştu';
        if (apiError.toString().contains('417')) {
          errorMessage = 'Şifreniz en az 8 karakter, en az 1 sayı ve harf içermelidir.';
        }
        
        return UserResponse(
          error: true,
          success: false, 
          errorMessage: errorMessage
        );
      }
    } catch (e) {
      _logger.e('Kullanıcı şifresi güncellenirken hata: $e');
      throw Exception('Kullanıcı şifresi güncellenemedi: $e');
    }
  }
}