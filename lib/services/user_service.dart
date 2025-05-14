import '../models/user_model.dart';
import '../models/group_models.dart';
import '../services/logger_service.dart';
import '../services/storage_service.dart';
import 'base_api_service.dart';

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
} 