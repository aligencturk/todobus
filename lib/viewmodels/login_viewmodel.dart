import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/logger_service.dart';
import '../services/data_service.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum LoginStatus { initial, loading, success, error, dataLoading }

class LoginViewModel extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final LoggerService _logger = LoggerService();
  final DataService _dataService = DataService();
  
  LoginStatus _status = LoginStatus.initial;
  String _errorMessage = '';
  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _isDisposed = false;
  
  static const String _emailKey = 'saved_email';

  // Getters
  LoginStatus get status => _status;
  String get errorMessage => _errorMessage;
  bool get obscurePassword => _obscurePassword;
  bool get rememberMe => _rememberMe;

  LoginViewModel() {
    _loadSavedEmail();
  }

  // Güvenli notifyListeners
  void _safeNotifyListeners() {
    if (!_isDisposed) {
      Future.microtask(() => notifyListeners());
    }
  }
  
  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  // E-posta adresini yükle
  Future<String?> _loadSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString(_emailKey);
    return savedEmail;
  }
  
  // "Beni Hatırla" değerini değiştir
  void toggleRememberMe(bool value) {
    _rememberMe = value;
    _safeNotifyListeners();
  }
  
  // Şifre görünürlüğünü değiştir
  void togglePasswordVisibility() {
    _obscurePassword = !_obscurePassword;
    _safeNotifyListeners();
  }
  
  // E-posta adresini kaydet
  Future<void> _saveEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_emailKey, email);
  }
  
  // E-posta adresini sil
  Future<void> _clearSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_emailKey);
  }
  
  // Tüm uygulama verilerini yükle
  Future<void> _loadAllData(String userID) async {
    _status = LoginStatus.dataLoading;
    _safeNotifyListeners();
    
    _logger.i('Tüm veriler yükleniyor...');
    
    try {
      // Tüm verileri tek seferde yükle
      await _dataService.loadAllData(userID);
      
      _logger.i('Tüm veriler başarıyla yüklendi');
      _status = LoginStatus.success;
      _safeNotifyListeners();
    } catch (e) {
      _logger.e('Veri yükleme hatası', e);
      // Veri yükleme hatası olsa bile kullanıcı girişi kabul edilir
      _status = LoginStatus.success;
      _safeNotifyListeners();
    }
  }

  // Giriş işlemi
  Future<bool> login(String email, String password) async {
    if (email.isEmpty || password.isEmpty) {
      _errorMessage = 'E-posta ve şifre alanları boş bırakılamaz';
      _status = LoginStatus.error;
      _safeNotifyListeners();
      return false;
    }

    try {
      _status = LoginStatus.loading;
      _errorMessage = '';
      _safeNotifyListeners();

      _logger.i('Giriş denemesi: $email');
      final response = await _apiService.auth.login(email, password);

      if (response.success) {
        _logger.i('Giriş başarılı: Kullanıcı ID: ${response.data?.userID}');
        
        // "Beni Hatırla" seçili ise e-postayı kaydet, değilse sil
        if (_rememberMe) {
          await _saveEmail(email);
        } else {
          await _clearSavedEmail();
        }
        
        // Tüm verileri yükle
        await _loadAllData(response.data?.userID?.toString() ?? '');
        
        return true;
      } else {
        // Kullanıcı dostu hata mesajını kullan
        _errorMessage = response.userFriendlyMessage ?? response.errorMessage ?? 'Giriş başarısız';
        _logger.w('Giriş başarısız: $_errorMessage');
        _status = LoginStatus.error;
        _safeNotifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Bir hata oluştu: ${e.toString()}';
      _logger.e('Giriş hatası', e);
      _status = LoginStatus.error;
      _safeNotifyListeners();
      return false;
    }
  }

  // Kaydedilmiş e-posta varsa getir
  Future<String?> getSavedEmail() async {
    return await _loadSavedEmail();
  }

  // Durumu sıfırla
  void reset() {
    _status = LoginStatus.initial;
    _errorMessage = '';
    _safeNotifyListeners();
  }
} 