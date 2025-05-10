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
  Future<void> saveUserName(String userName) async {
    await _ensureInitialized();
    await _prefs.setString('user_name', userName);
    _logger.d('Kullanıcı adı kaydedildi: $userName');
  }

  // Kullanıcı adını getirme
  String? getUserName() {
    _ensureInitializedSync();
    return _prefs.getString('user_name');
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