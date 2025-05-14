import 'package:shared_preferences/shared_preferences.dart';
import '../services/logger_service.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  final LoggerService _logger = LoggerService();
  late SharedPreferences _prefs;
  bool _initialized = false;

  // Anahtar sabitleri
  static const String keyUserToken = 'user_token';
  static const String keyUserId = 'user_id';
  static const String keyIsLoggedIn = 'is_logged_in';

  factory StorageService() {
    return _instance;
  }

  StorageService._internal();

  Future<void> init() async {
    if (!_initialized) {
      _prefs = await SharedPreferences.getInstance();
      _initialized = true;
      _logger.i('StorageService başlatıldı');
    }
  }

  // Token işlemleri
  Future<bool> saveToken(String token) async {
    await _ensureInitialized();
    final result = await _prefs.setString(keyUserToken, token);
    _logger.d('Token kaydedildi: $token');
    return result;
  }

  String? getToken() {
    _ensureInitializedSync();
    return _prefs.getString(keyUserToken);
  }

  // Kullanıcı ID işlemleri
  Future<bool> saveUserId(int userId) async {
    await _ensureInitialized();
    final result = await _prefs.setInt(keyUserId, userId);
    _logger.d('Kullanıcı ID kaydedildi: $userId');
    return result;
  }

  int? getUserId() {
    _ensureInitializedSync();
    return _prefs.getInt(keyUserId);
  }

  // Giriş durumu işlemleri
  Future<bool> setLoggedIn(bool value) async {
    await _ensureInitialized();
    final result = await _prefs.setBool(keyIsLoggedIn, value);
    _logger.d('Giriş durumu kaydedildi: $value');
    return result;
  }

  bool isLoggedIn() {
    _ensureInitializedSync();
    return _prefs.getBool(keyIsLoggedIn) ?? false;
  }

  // Çıkış işlemi
  Future<bool> clearUserData() async {
    await _ensureInitialized();
    await _prefs.remove(keyUserToken);
    await _prefs.remove(keyUserId);
    final result = await _prefs.setBool(keyIsLoggedIn, false);
    _logger.i('Kullanıcı verileri temizlendi');
    return result;
  }

  // Kullanıcı bilgilerini kaydetme
  Future<void> saveUserFirstname(String userFirstname) async {
    await _ensureInitialized();
    await _prefs.setString('user_firstname', userFirstname);
    _logger.d('Kullanıcı adı kaydedildi: $userFirstname');
  }

  // Kullanıcı adını getirme
  String? getUserFirstname() {
    _ensureInitializedSync();
    return _prefs.getString('user_firstname');
  }

  // Kullanıcı e-postasını kaydetme
  Future<void> saveUserEmail(String userEmail) async {
    await _ensureInitialized();
    await _prefs.setString('user_email', userEmail);
    _logger.d('Kullanıcı e-postası kaydedildi: $userEmail');
  }

  // Kullanıcı e-postasını getirme
  String? getUserEmail() {
    _ensureInitializedSync();
    return _prefs.getString('user_email');
  }

  // Kullanıcı oturumunu kapattığında tüm önbelleği temizler
  Future<void> clearAllCache() async {
    try {
      // Tüm önbellek verilerini temizleme işlemleri burada gerçekleştirilebilir
      // Örneğin, SharedPreferences'teki önbellek anahtarlarını temizlemek
      final prefs = await SharedPreferences.getInstance();
      
      // Kullanıcı verileri dışındaki tüm önbelleğin tutulduğu anahtar değerlerini temizlemek için
      // Not: userToken gibi oturum bilgileri clearUserData ile temizlenir, burada sadece önbellek
      await prefs.remove('dashboard_cache');
      await prefs.remove('tasks_cache');
      await prefs.remove('groups_cache');
      await prefs.remove('events_cache');
      
      _logger.i('Tüm önbellek başarıyla temizlendi');
    } catch (e) {
      _logger.e('Önbellek temizleme hatası: $e');
    }
  }

  // Servisin başlatıldığından emin olma
  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await init();
    }
  }

  void _ensureInitializedSync() {
    if (!_initialized) {
      _logger.w('StorageService henüz başlatılmadı');
    }
  }
} 