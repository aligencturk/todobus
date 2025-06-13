import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/logger_service.dart';
import '../services/device_info_service.dart';
import '../services/storage_service.dart';
import '../models/auth_models.dart';

enum RegisterStatus { initial, loading, success, error }

class RegisterViewModel with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final LoggerService _logger = LoggerService();
  final DeviceInfoService _deviceInfoService = DeviceInfoService();
  final StorageService _storageService = StorageService();
  
  RegisterStatus _status = RegisterStatus.initial;
  String _errorMessage = '';
  bool _obscurePassword = true;
  bool _acceptPolicy = false;
  bool _acceptKvkk = false;
  bool _isDisposed = false;
  RegisterData? _registerData;

  // Getters
  RegisterStatus get status => _status;
  String get errorMessage => _errorMessage;
  bool get obscurePassword => _obscurePassword;
  bool get acceptPolicy => _acceptPolicy;
  bool get acceptKvkk => _acceptKvkk;
  RegisterData? get registerData => _registerData;

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

  // Şifre görünürlüğünü değiştir
  void togglePasswordVisibility() {
    _obscurePassword = !_obscurePassword;
    _safeNotifyListeners();
  }
  
  // Politika kabul durumunu değiştir
  void togglePolicy() {
    _acceptPolicy = !_acceptPolicy;
    _safeNotifyListeners();
  }
  
  // KVKK kabul durumunu değiştir
  void toggleKvkk() {
    _acceptKvkk = !_acceptKvkk;
    _safeNotifyListeners();
  }

  // Kayıt ol
  Future<bool> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    if (firstName.isEmpty || lastName.isEmpty || email.isEmpty || password.isEmpty) {
      _errorMessage = 'Tüm alanlar doldurulmalıdır';
      _status = RegisterStatus.error;
      _safeNotifyListeners();
      return false;
    }
    
    if (!_acceptPolicy || !_acceptKvkk) {
      _errorMessage = 'Kullanım koşulları ve KVKK metinlerini kabul etmelisiniz';
      _status = RegisterStatus.error;
      _safeNotifyListeners();
      return false;
    }

    try {
      _status = RegisterStatus.loading;
      _errorMessage = '';
      _safeNotifyListeners();

      _logger.i('Kayıt denemesi: $email');
      final response = await _apiService.auth.register(
        firstName: firstName,
        lastName: lastName,
        email: email,
        password: password,
        policy: _acceptPolicy,
        kvkk: _acceptKvkk,
      );

      if (response.success) {
        _logger.i('Kayıt başarılı');
        
        // Token bilgilerini kaydet
        if (response.data != null) {
          _registerData = response.data;
          await _storageService.saveToken(response.data!.userToken);
          await _storageService.saveUserId(response.data!.userID);
          _logger.i('Kayıt token bilgileri kaydedildi: userID=${response.data!.userID}');
        }
        
        _status = RegisterStatus.success;
        _safeNotifyListeners();
        return true;
      } else {
        // Kullanıcı dostu hata mesajını kullan
        _errorMessage = response.userFriendlyMessage ?? response.message ?? 'Kayıt işlemi başarısız';
        _logger.w('Kayıt başarısız: $_errorMessage');
        _status = RegisterStatus.error;
        _safeNotifyListeners();
        return false;
      }
    } catch (e) {
      // Network hataları vs. için
      _errorMessage = 'Bağlantı hatası: ${e.toString()}';
      _logger.e('Kayıt hatası:', e);
      _status = RegisterStatus.error;
      _safeNotifyListeners();
      return false;
    }
  }

  // Durumu sıfırla
  void reset() {
    _status = RegisterStatus.initial;
    _errorMessage = '';
    _safeNotifyListeners();
  }
} 