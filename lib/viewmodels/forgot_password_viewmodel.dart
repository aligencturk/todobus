import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/logger_service.dart';
import '../services/snackbar_service.dart';

enum ForgotPasswordStatus { initial, loading, success, error, codeVerification, resetPassword }

class ForgotPasswordViewModel with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final LoggerService _logger = LoggerService();
  
  ForgotPasswordStatus _status = ForgotPasswordStatus.initial;
  String _errorMessage = '';
  String _verificationToken = '';
  String _passToken = '';
  bool _obscurePassword = true;
  bool _obscurePasswordConfirm = true;

  // Getters
  ForgotPasswordStatus get status => _status;
  String get errorMessage => _errorMessage;
  String get verificationToken => _verificationToken;
  String get passToken => _passToken;
  bool get obscurePassword => _obscurePassword;
  bool get obscurePasswordConfirm => _obscurePasswordConfirm;

  // Şifre görünürlüğünü değiştir
  void togglePasswordVisibility() {
    _obscurePassword = !_obscurePassword;
    notifyListeners();
  }
  
  // Şifre tekrar görünürlüğünü değiştir
  void togglePasswordConfirmVisibility() {
    _obscurePasswordConfirm = !_obscurePasswordConfirm;
    notifyListeners();
  }

  // Şifremi unuttum
  Future<bool> forgotPassword(String email) async {
    if (email.isEmpty) {
      _errorMessage = 'E-posta adresi girilmelidir';
      _status = ForgotPasswordStatus.error;
      notifyListeners();
      return false;
    }

    try {
      _status = ForgotPasswordStatus.loading;
      _errorMessage = '';
      notifyListeners();

      _logger.i('Şifre sıfırlama isteği: $email');
      final response = await _apiService.auth.forgotPassword(email);

      if (response.success) {
        _logger.i('Şifre sıfırlama isteği başarılı: ${response.message}');
        if (response.data != null) {
          _verificationToken = response.data!.token;
        }
        _status = ForgotPasswordStatus.codeVerification;
        notifyListeners();
        return true;
      } else {
        _errorMessage = response.message ?? 'Şifre sıfırlama isteği başarısız';
        _logger.w('Şifre sıfırlama başarısız: $_errorMessage');
        _status = ForgotPasswordStatus.error;
        notifyListeners();
        return false;
      }
    } catch (e) {
      // Hata mesajını temizle - Exception: prefix'i kaldır
      String cleanErrorMessage = e.toString();
      if (cleanErrorMessage.startsWith('Exception: ')) {
        cleanErrorMessage = cleanErrorMessage.substring('Exception: '.length);
      }
      
      _errorMessage = 'Bir hata oluştu: $cleanErrorMessage';
      _logger.e('Şifre sıfırlama hatası:', e);
      _status = ForgotPasswordStatus.error;
      notifyListeners();
      return false;
    }
  }
  
  // Doğrulama kodu kontrolü
  Future<bool> verifyCode(String code) async {
    if (code.isEmpty) {
      _errorMessage = 'Doğrulama kodu girilmelidir';
      _status = ForgotPasswordStatus.error;
      notifyListeners();
      return false;
    }
    
    if (_verificationToken.isEmpty) {
      _errorMessage = 'Doğrulama token bilgisi eksik';
      _status = ForgotPasswordStatus.error;
      notifyListeners();
      return false;
    }

    try {
      _status = ForgotPasswordStatus.loading;
      _errorMessage = '';
      notifyListeners();

      _logger.i('Doğrulama kodu kontrolü: $code');
      final response = await _apiService.auth.checkVerificationCode(code, _verificationToken);

      if (response.success) {
        _logger.i('Doğrulama kodu kontrolü başarılı');
        if (response.data != null) {
          _passToken = response.data!.passToken;
        }
        _status = ForgotPasswordStatus.resetPassword;
        notifyListeners();
        return true;
      } else {
        _errorMessage = response.message ?? 'Doğrulama kodu kontrolü başarısız';
        _logger.w('Doğrulama kodu kontrolü başarısız: $_errorMessage');
        _status = ForgotPasswordStatus.error;
        notifyListeners();
        return false;
      }
    } catch (e) {
      // Hata mesajını temizle
      String cleanErrorMessage = e.toString();
      if (cleanErrorMessage.startsWith('Exception: ')) {
        cleanErrorMessage = cleanErrorMessage.substring('Exception: '.length);
      }
      
      _errorMessage = 'Bir hata oluştu: $cleanErrorMessage';
      _logger.e('Doğrulama kodu kontrolü hatası:', e);
      _status = ForgotPasswordStatus.error;
      notifyListeners();
      return false;
    }
  }
  
  // Şifre sıfırlama
  Future<bool> resetPassword(String password, String passwordConfirm) async {
    if (password.isEmpty || passwordConfirm.isEmpty) {
      _errorMessage = 'Şifre alanları boş bırakılamaz';
      _status = ForgotPasswordStatus.error;
      notifyListeners();
      return false;
    }
    
    if (password != passwordConfirm) {
      _errorMessage = 'Girilen şifreler eşleşmiyor';
      _status = ForgotPasswordStatus.error;
      notifyListeners();
      return false;
    }
    
    if (_passToken.isEmpty) {
      _errorMessage = 'Şifre sıfırlama token bilgisi eksik';
      _status = ForgotPasswordStatus.error;
      notifyListeners();
      return false;
    }

    try {
      _status = ForgotPasswordStatus.loading;
      _errorMessage = '';
      notifyListeners();

      _logger.i('Şifre sıfırlama işlemi yapılıyor');
      final response = await _apiService.auth.updatePassword(_passToken, password, passwordConfirm);

      if (response.success) {
        _logger.i('Şifre sıfırlama başarılı');
        _status = ForgotPasswordStatus.success;
        notifyListeners();
        return true;
      } else {
        _errorMessage = response.message ?? 'Şifre sıfırlama başarısız';
        _logger.w('Şifre sıfırlama başarısız: $_errorMessage');
        _status = ForgotPasswordStatus.error;
        notifyListeners();
        return false;
      }
    } catch (e) {
      // Hata mesajını temizle
      String cleanErrorMessage = e.toString();
      if (cleanErrorMessage.startsWith('Exception: ')) {
        cleanErrorMessage = cleanErrorMessage.substring('Exception: '.length);
      }
      
      _errorMessage = 'Bir hata oluştu: $cleanErrorMessage';
      _logger.e('Şifre sıfırlama hatası:', e);
      _status = ForgotPasswordStatus.error;
      notifyListeners();
      return false;
    }
  }

  // Durumu sıfırla
  void reset() {
    _status = ForgotPasswordStatus.initial;
    _errorMessage = '';
    _verificationToken = '';
    _passToken = '';
    notifyListeners();
  }
  
  // Kod doğrulama ekranına dön
  void backToCodeVerification() {
    _status = ForgotPasswordStatus.codeVerification;
    _errorMessage = '';
    notifyListeners();
  }
  
  // E-posta giriş ekranına dön
  void backToInitial() {
    _status = ForgotPasswordStatus.initial;
    _errorMessage = '';
    notifyListeners();
  }
} 