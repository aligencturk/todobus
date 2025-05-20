import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/logger_service.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum LoginStatus { initial, loading, success, error }

class LoginViewModel extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final LoggerService _logger = LoggerService();
  
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
    notifyListeners();
  }
  
  // Şifre görünürlüğünü değiştir
  void togglePasswordVisibility() {
    _obscurePassword = !_obscurePassword;
    notifyListeners();
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
  
  // Giriş işlemi
  Future<bool> login(String email, String password) async {
    if (email.isEmpty || password.isEmpty) {
      _errorMessage = 'E-posta ve şifre alanları boş bırakılamaz';
      _status = LoginStatus.error;
      notifyListeners();
      return false;
    }

    try {
      _status = LoginStatus.loading;
      _errorMessage = '';
      notifyListeners();

      _logger.i('Giriş denemesi: $email');
      final response = await _apiService.auth.login(email, password);

      if (response.success) {
        _logger.i('Giriş başarılı: Kullanıcı ID: ${response.data?.userID}');
        _status = LoginStatus.success;
        
        // "Beni Hatırla" seçili ise e-postayı kaydet, değilse sil
        if (_rememberMe) {
          await _saveEmail(email);
        } else {
          await _clearSavedEmail();
        }
        
        notifyListeners();
        return true;
      } else {
        _errorMessage = response.errorMessage ?? 'Giriş başarısız';
        _logger.w('Giriş başarısız: $_errorMessage');
        _status = LoginStatus.error;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Bir hata oluştu: ${e.toString()}';
      _logger.e('Giriş hatası:', e);
      _status = LoginStatus.error;
      notifyListeners();
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
    notifyListeners();
  }
} 