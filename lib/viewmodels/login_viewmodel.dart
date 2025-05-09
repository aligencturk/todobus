import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/logger_service.dart';

enum LoginStatus { initial, loading, success, error }

class LoginViewModel with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final LoggerService _logger = LoggerService();
  
  LoginStatus _status = LoginStatus.initial;
  String _errorMessage = '';
  bool _obscurePassword = true;

  // Getters
  LoginStatus get status => _status;
  String get errorMessage => _errorMessage;
  bool get obscurePassword => _obscurePassword;

  // Şifre görünürlüğünü değiştir
  void togglePasswordVisibility() {
    _obscurePassword = !_obscurePassword;
    notifyListeners();
  }

  // Giriş yap
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
      final response = await _apiService.login(email, password);

      if (response.success) {
        _logger.i('Giriş başarılı: Kullanıcı ID: ${response.data?.userID}');
        _status = LoginStatus.success;
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

  // Durumu sıfırla
  void reset() {
    _status = LoginStatus.initial;
    _errorMessage = '';
    notifyListeners();
  }
} 