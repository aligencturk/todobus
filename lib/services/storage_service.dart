import 'package:shared_preferences/shared_preferences.dart';
import '../services/logger_service.dart';
import '../models/user_model.dart';
import '../views/dashboard_view.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  final LoggerService _logger = LoggerService();
  late SharedPreferences _prefs;
  bool _initialized = false;

  // Anahtar sabitleri
  static const String keyUserToken = 'user_token';
  static const String keyUserId = 'user_id';
  static const String keyIsLoggedIn = 'is_logged_in';
  static const String keyDashboardWidgetOrder = 'dashboard_widget_order';

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

  // Dashboard widget sırasını kaydetme
  Future<bool> saveDashboardWidgetOrder(List<DashboardWidgetType> order) async {
    await _ensureInitialized();
    
    // Enum değerlerini int listesine dönüştür
    final List<int> orderIndices = order.map((type) => type.index).toList();
    
    // Int listesini kaydet
    final result = await _prefs.setStringList(
      keyDashboardWidgetOrder, 
      orderIndices.map((i) => i.toString()).toList()
    );
    
    _logger.d('Dashboard widget sırası kaydedildi: ${orderIndices.join(", ")}');
    return result;
  }
  
  // Dashboard widget sırasını getirme
  List<DashboardWidgetType> getDashboardWidgetOrder() {
    _ensureInitializedSync();
    
    // Kaydedilen string listesini al
    final List<String>? savedOrder = _prefs.getStringList(keyDashboardWidgetOrder);
    
    if (savedOrder == null || savedOrder.isEmpty) {
      return [];
    }
    
    try {
      // String listesini int listesine dönüştür
      final List<int> orderIndices = savedOrder.map((s) => int.parse(s)).toList();
      
      // Int listesini enum listesine dönüştür
      final List<DashboardWidgetType> result = orderIndices
          .map((i) => DashboardWidgetType.values[i])
          .toList();
      
      _logger.d('Dashboard widget sırası alındı: ${orderIndices.join(", ")}');
      return result;
    } catch (e) {
      _logger.e('Dashboard widget sırası alınırken hata: $e');
      return [];
    }
  }

  // Çıkış işlemi - sadece giriş bilgilerini temizle
  Future<bool> clearUserData() async {
    await _ensureInitialized();
    await _prefs.remove(keyUserToken);
    await _prefs.remove(keyUserId);
    final result = await _prefs.setBool(keyIsLoggedIn, false);
    _logger.i('Kullanıcı giriş verileri temizlendi');
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