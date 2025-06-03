import 'logger_service.dart';

/// Uygulama verilerini yönetmek için kullanılan servis
class DataService {
  final LoggerService _logger = LoggerService();
  
  bool _isInitialized = false;
  bool _isProfileLoaded = false;
  bool _areTasksLoaded = false;
  bool _areNotificationsLoaded = false;
  bool _areSettingsLoaded = false;
  bool _areCategoriesLoaded = false;
  
  // Getters
  bool get isInitialized => _isInitialized;
  bool get isProfileLoaded => _isProfileLoaded;
  bool get areTasksLoaded => _areTasksLoaded;
  bool get areNotificationsLoaded => _areNotificationsLoaded;
  bool get areSettingsLoaded => _areSettingsLoaded;
  bool get areCategoriesLoaded => _areCategoriesLoaded;
  
  /// Kullanıcı profilini yükler
  Future<void> loadUserProfile(String userID) async {
    try {
      _logger.i('Kullanıcı profili yükleniyor: $userID');
      // API çağrısı burada yapılacak
      await Future.delayed(const Duration(milliseconds: 300));
      
      _isProfileLoaded = true;
      _logger.i('Kullanıcı profili başarıyla yüklendi');
    } catch (e) {
      _logger.e('Kullanıcı profili yükleme hatası: ${e.toString()}');
      rethrow;
    }
  }
  
  /// Kullanıcının görevlerini yükler
  Future<void> loadUserTasks(String userID) async {
    try {
      _logger.i('Kullanıcı görevleri yükleniyor: $userID');
      // API çağrısı burada yapılacak
      await Future.delayed(const Duration(milliseconds: 500));
      
      _areTasksLoaded = true;
      _logger.i('Kullanıcı görevleri başarıyla yüklendi');
    } catch (e) {
      _logger.e('Kullanıcı görevleri yükleme hatası: ${e.toString()}');
      rethrow;
    }
  }
  
  /// Kullanıcının bildirimlerini yükler
  Future<void> loadNotifications(String userID) async {
    try {
      _logger.i('Kullanıcı bildirimleri yükleniyor: $userID');
      // API çağrısı burada yapılacak
      await Future.delayed(const Duration(milliseconds: 200));
      
      _areNotificationsLoaded = true;
      _logger.i('Kullanıcı bildirimleri başarıyla yüklendi');
    } catch (e) {
      _logger.e('Kullanıcı bildirimleri yükleme hatası: ${e.toString()}');
      rethrow;
    }
  }
  
  /// Kullanıcı ayarlarını yükler
  Future<void> loadSettings(String userID) async {
    try {
      _logger.i('Kullanıcı ayarları yükleniyor: $userID');
      // API çağrısı burada yapılacak
      await Future.delayed(const Duration(milliseconds: 150));
      
      _areSettingsLoaded = true;
      _logger.i('Kullanıcı ayarları başarıyla yüklendi');
    } catch (e) {
      _logger.e('Kullanıcı ayarları yükleme hatası: ${e.toString()}');
      rethrow;
    }
  }
  
  /// Kategori listesini yükler
  Future<void> loadCategories() async {
    try {
      _logger.i('Kategoriler yükleniyor');
      // API çağrısı burada yapılacak
      await Future.delayed(const Duration(milliseconds: 250));
      
      _areCategoriesLoaded = true;
      _logger.i('Kategoriler başarıyla yüklendi');
    } catch (e) {
      _logger.e('Kategoriler yükleme hatası: ${e.toString()}');
      rethrow;
    }
  }
  
  /// Tüm verileri tek seferde yükler
  Future<void> loadAllData(String userID) async {
    try {
      _logger.i('Tüm veriler yükleniyor...');
      
      await Future.wait([
        loadUserProfile(userID),
        loadUserTasks(userID),
        loadNotifications(userID),
        loadSettings(userID),
        loadCategories(),
      ]);
      
      _isInitialized = true;
      _logger.i('Tüm veriler başarıyla yüklendi');
    } catch (e) {
      _logger.e('Veri yükleme hatası: ${e.toString()}');
      rethrow;
    }
  }
  
  /// Tüm verileri temizler
  void clearAllData() {
    _isInitialized = false;
    _isProfileLoaded = false;
    _areTasksLoaded = false;
    _areNotificationsLoaded = false;
    _areSettingsLoaded = false;
    _areCategoriesLoaded = false;
    _logger.i('Tüm veriler temizlendi');
  }
} 