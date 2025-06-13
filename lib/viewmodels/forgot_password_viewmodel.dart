import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/logger_service.dart';

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
    print('🔍 VIEWMODEL: forgotPassword başlatıldı - email: $email');
    
    if (email.isEmpty) {
      print('🔍 VIEWMODEL: E-posta boş!');
      _errorMessage = 'E-posta adresi girilmelidir';
      _status = ForgotPasswordStatus.error;
      notifyListeners();
      return false;
    }

    try {
      print('🔍 VIEWMODEL: Loading durumuna geçiliyor');
      _status = ForgotPasswordStatus.loading;
      _errorMessage = '';
      notifyListeners();

      _logger.i('Şifre sıfırlama isteği: $email');
      print('🔍 VIEWMODEL: API çağrısı yapılıyor...');
      final response = await _apiService.auth.forgotPassword(email);
      print('🔍 VIEWMODEL: API yanıtı alındı');
      
      // Raw response'u debug et
      print('🔍 VIEWMODEL: Raw response object type: ${response.runtimeType}');
      print('🔍 VIEWMODEL: Raw response toString: $response');

      // Response'u debug için logla
      _logger.d('ForgotPassword API Response: success=${response.success}, statusCode=${response.statusCode}');
      _logger.d('Response data: ${response.data}');
      _logger.d('Response token: ${response.data?.token}');
      
      print('🔍 VIEWMODEL: API Response - success: ${response.success}');
      print('🔍 VIEWMODEL: API Response - statusCode: ${response.statusCode}');
      print('🔍 VIEWMODEL: API Response - message: ${response.message}');
      print('🔍 VIEWMODEL: API Response - data is null: ${response.data == null}');
      if (response.data != null) {
        print('🔍 VIEWMODEL: API Response - token is null: ${response.data!.token == null}');
        print('🔍 VIEWMODEL: API Response - token: ${response.data!.token}');
        print('🔍 VIEWMODEL: ForgotPasswordData toString: ${response.data.toString()}');
      }

      if (response.success) {
        _logger.i('Şifre sıfırlama isteği başarılı: ${response.message}');
        print('🔍 VIEWMODEL: API başarılı döndü');
        
        if (response.data != null && response.data!.token != null) {
          _verificationToken = response.data!.token!;
          _logger.i('Verification token alındı: ${_verificationToken.length} karakter');
          print('🔍 VIEWMODEL: Token başarıyla alındı: ${_verificationToken.length} karakter');
          _status = ForgotPasswordStatus.codeVerification;
          notifyListeners();
          return true;
        } else {
          _logger.w('API başarılı döndü ama token bilgisi eksik - data: ${response.data}, token: ${response.data?.token}');
          print('🔍 VIEWMODEL: ❌ Token bilgisi eksik!');
          print('🔍 VIEWMODEL: Data: ${response.data}');
          print('🔍 VIEWMODEL: Token: ${response.data?.token}');
          _errorMessage = 'Doğrulama token bilgisi alınamadı';
          _status = ForgotPasswordStatus.error;
          notifyListeners();
          return false;
        }
      } else {
        // Kullanıcı dostu hata mesajını kullan
        print('🔍 VIEWMODEL: ❌ API başarısız döndü');
        _errorMessage = response.userFriendlyMessage ?? response.message ?? 'Şifre sıfırlama isteği başarısız';
        _logger.w('Şifre sıfırlama başarısız: $_errorMessage');
        print('🔍 VIEWMODEL: Hata mesajı: $_errorMessage');
        _status = ForgotPasswordStatus.error;
        notifyListeners();
        return false;
      }
    } catch (e) {
      print('🔍 VIEWMODEL: ❌ Exception yakalandı: $e');
      
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
      
      // Manuel recovery token durumu için özel handling
      if (_verificationToken == 'manual_recovery_token') {
        print('🔍 VIEWMODEL: Manuel recovery token ile doğrulama yapılıyor');
        print('🔍 VIEWMODEL: Manuel recovery - doğrulama kodu API\'si olmadığı için geçici çözüm');
        
        // Geçici çözüm: Manuel recovery durumunda direkt şifre sıfırlama adımına geç
        // Gerçek uygulamada bu durumda özel bir API endpoint kullanılmalı
        _passToken = 'manual_recovery_pass_token';
        _status = ForgotPasswordStatus.resetPassword;
        notifyListeners();
        return true;
      } else {
        // Normal verification token ile doğrulama
        final response = await _apiService.auth.checkVerificationCode(code, _verificationToken);

        if (response.success) {
          _logger.i('Doğrulama kodu kontrolü başarılı');
          if (response.data != null && response.data!.passToken != null) {
            _passToken = response.data!.passToken!;
            _status = ForgotPasswordStatus.resetPassword;
            notifyListeners();
            return true;
          } else {
            _errorMessage = 'Şifre sıfırlama token bilgisi alınamadı';
            _status = ForgotPasswordStatus.error;
            notifyListeners();
            return false;
          }
        } else {
          _errorMessage = response.userFriendlyMessage ?? response.message ?? 'Doğrulama kodu kontrolü başarısız';
          _logger.w('Manuel doğrulama kodu kontrolü başarısız: $_errorMessage');
          
          // 417 hatası için özel mesaj
          if (_errorMessage.contains('417') || _errorMessage.contains('Geçersiz doğrulama kodu')) {
            _errorMessage = 'Doğrulama kodunuz hatalı veya süresi dolmuş. Lütfen "Yeni doğrulama kodu talep et" butonuna basarak yeni kod alın.';
          }
          
          print('🔍 VIEWMODEL: Düzenlenmiş hata mesajı: $_errorMessage');
          _status = ForgotPasswordStatus.error;
          notifyListeners();
          return false;
        }
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
        // Kullanıcı dostu hata mesajını kullan
        _errorMessage = response.userFriendlyMessage ?? response.message ?? 'Şifre sıfırlama başarısız';
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
  
  // Manuel olarak doğrulama kodu ekranına geç (recovery için)
  void manualSwitchToCodeVerification() {
    print('🔍 VIEWMODEL: Manuel doğrulama kodu ekranına geçiliyor');
    _status = ForgotPasswordStatus.codeVerification;
    _errorMessage = '';
    // Geçici bir verification token oluştur (kullanıcı manuel geçiş yaptı)
    _verificationToken = 'manual_recovery_token';
    notifyListeners();
  }
} 