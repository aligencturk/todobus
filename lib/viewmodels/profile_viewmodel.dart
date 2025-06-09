import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/logger_service.dart';
import '../services/device_info_service.dart';
import '../services/refresh_service.dart';

enum ProfileStatus { initial, loading, loaded, error, updating, updateSuccess, updateError, changingPassword, passwordChanged, passwordError }

class ProfileViewModel with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final LoggerService _logger = LoggerService();
  final DeviceInfoService _deviceInfoService = DeviceInfoService();
  final RefreshService _refreshService = RefreshService();
  
  ProfileStatus _status = ProfileStatus.initial;
  String _errorMessage = '';
  User? _user;
  bool _isDisposed = false;
  StreamSubscription? _refreshSubscription;
  
  // Cihaz bilgileri
  String _deviceModel = 'Yükleniyor...';
  String _osVersion = 'Yükleniyor...';
  bool _deviceInfoLoaded = false;
  
  // Getters
  ProfileStatus get status => _status;
  String get errorMessage => _errorMessage;
  User? get user => _user;
  String get deviceModel => _deviceModel;
  String get osVersion => _osVersion;
  
  ProfileViewModel() {
    _initRefreshListener();
  }
  
  void _initRefreshListener() {
    _refreshSubscription = _refreshService.refreshStream.listen((refreshType) {
      if (refreshType == 'profile' || refreshType == 'all') {
        loadUserProfile();
      }
    });
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
    _refreshSubscription?.cancel();
    super.dispose();
  }
  
  // Kullanıcı bilgisini doğrudan ayarla
  void setUser(User user) {
    _user = user;
    _status = ProfileStatus.loaded;
    _safeNotifyListeners();
    _logger.i('Kullanıcı bilgileri ayarlandı: ${user.userFullname}');
  }
  
  // Kullanıcı bilgilerini getir
  Future<void> loadUserProfile() async {
    if (_status == ProfileStatus.loading) return;
    
    try {
      _status = ProfileStatus.loading;
      _errorMessage = '';
      _safeNotifyListeners();
      
      // Cihaz bilgilerini yükle
      if (!_deviceInfoLoaded) {
        await _loadDeviceInfo();
      }
      
      _logger.i('Kullanıcı profili yükleniyor');
      final response = await _apiService.user.getUser();
      
      if (response.success && response.data != null) {
        _user = response.data!.user;
        _status = ProfileStatus.loaded;
        _logger.i('Kullanıcı profili yüklendi: ${_user!.userFullname}');
      } else {
        _errorMessage = response.errorMessage ?? 'Kullanıcı bilgileri alınamadı';
        _status = ProfileStatus.error;
        _logger.w('Profil yükleme başarısız: $_errorMessage');
      }
    } catch (e) {
      _errorMessage = 'Bir hata oluştu: ${e.toString()}';
      _status = ProfileStatus.error;
      _logger.e('Profil yükleme hatası:', e);
    } finally {
      _safeNotifyListeners();
    }
  }

  // Kullanıcı profilini güncelle
  Future<void> updateUserProfile({
    required String userFullname,
    required String userEmail,
    required String userBirthday,
    required int userGender,
    String profilePhoto = '',
  }) async {
    if (_status == ProfileStatus.updating) return;
    
    try {
      _status = ProfileStatus.updating;
      _errorMessage = '';
      _safeNotifyListeners();
      
      _logger.i('Kullanıcı profili güncelleniyor');
      final response = await _apiService.user.updateUserProfile(
        userFullname: userFullname,
        userEmail: userEmail,
        userBirthday: userBirthday,
        userGender: userGender,
        profilePhoto: profilePhoto,
      );
      
      if (response.success) {
        // Kullanıcı bilgilerini tekrar yükle
        await loadUserProfile();
        _status = ProfileStatus.updateSuccess;
        // Tüm uygulamaya profil güncelleme bildirimi gönder
        _refreshService.refreshProfile();
        _refreshService.refreshAll();
        _logger.i('Kullanıcı profili başarıyla güncellendi');
      } else {
        _errorMessage = response.errorMessage ?? 'Profil güncellenirken bir hata oluştu';
        _status = ProfileStatus.updateError;
        _logger.w('Profil güncelleme başarısız: $_errorMessage');
      }
    } catch (e) {
      _errorMessage = 'Güncelleme hatası: ${e.toString()}';
      _status = ProfileStatus.updateError;
      _logger.e('Profil güncelleme hatası:', e);
    } finally {
      _safeNotifyListeners();
    }
  }
  
  // Cihaz bilgilerini yükle
  Future<void> _loadDeviceInfo() async {
    try {
      await _deviceInfoService.init();
      _deviceModel = await _deviceInfoService.getDeviceModel();
      _osVersion = await _deviceInfoService.getOSVersion();
      _deviceInfoLoaded = true;
    } catch (e) {
      _logger.e('Cihaz bilgileri yüklenirken hata oluştu:', e);
      _deviceModel = 'Bilinmiyor';
      _osVersion = 'Bilinmiyor';
    }
  }
  
  // Platform bilgisi
  String get platformInfo {
    final platform = _deviceInfoService.getPlatformName();
    final version = _deviceInfoService.getAppVersion();
    return '$platform $version';
  }
  
  // Uygulama bilgileri
  String get appName => _deviceInfoService.getAppName();
  String get appVersion => _deviceInfoService.getAppVersion();
  String get buildNumber => _deviceInfoService.getBuildNumber();
  String get packageName => _deviceInfoService.getPackageName();
  
  // Durumu sıfırla
  void reset() {
    _status = ProfileStatus.initial;
    _errorMessage = '';
    _safeNotifyListeners();
  }

  // Kullanıcı aktivasyon durumunu kontrol et
  bool get isUserActivated => _user?.userStatus != 'not_activated';
  
  // Profil fotoğrafı güncelleme
  Future<void> updateProfilePhoto(String base64Image) async {
    if (_status == ProfileStatus.updating) return;
    
    try {
      _status = ProfileStatus.updating;
      _errorMessage = '';
      _safeNotifyListeners();
      
      _logger.i('Profil fotoğrafı güncelleniyor');
      
      // Eğer kullanıcı bilgileri yoksa, önce yükle
      if (_user == null) {
        await loadUserProfile();
        if (_user == null) {
          throw Exception('Kullanıcı bilgileri yüklenemedi');
        }
      }
      
      // Mevcut kullanıcı bilgilerini kullan ve profil fotoğrafını güncelle
      final response = await _apiService.user.updateUserProfile(
        userFullname: _user!.userFullname,
        userEmail: _user!.userEmail,
        userBirthday: _user!.userBirthday,
        userGender: int.tryParse(_user!.userGender) ?? 0,
        profilePhoto: base64Image,
      );
      
      if (response.success) {
        // Kullanıcı bilgilerini tekrar yükle
        await loadUserProfile();
        _status = ProfileStatus.updateSuccess;
        // Tüm uygulamaya profil güncelleme bildirimi gönder
        _refreshService.refreshProfile();
        _refreshService.refreshAll();
        _logger.i('Profil fotoğrafı başarıyla güncellendi');
      } else {
        _errorMessage = response.errorMessage ?? 'Profil fotoğrafı güncellenirken bir hata oluştu';
        _status = ProfileStatus.updateError;
        _logger.w('Profil fotoğrafı güncelleme başarısız: $_errorMessage');
      }
    } catch (e) {
      _errorMessage = 'Güncelleme hatası: ${e.toString()}';
      _status = ProfileStatus.updateError;
      _logger.e('Profil fotoğrafı güncelleme hatası:', e);
    } finally {
      _safeNotifyListeners();
    }
  }

  // Şifre değiştirme
  Future<void> updatePassword({
    required String currentPassword,
    required String password,
    required String passwordAgain,
  }) async {
    if (_status == ProfileStatus.changingPassword) return;

    try {
      _status = ProfileStatus.changingPassword;
      _errorMessage = '';
      _safeNotifyListeners();

      _logger.i('Kullanıcı şifresi değiştiriliyor');
      final response = await _apiService.user.updatePassword(
        currentPassword: currentPassword,
        password: password,
        passwordAgain: passwordAgain,
      );

      if (response.success) {
        _status = ProfileStatus.passwordChanged;
        _logger.i('Kullanıcı şifresi başarıyla değiştirildi');
      } else {
        // API'den gelen hata mesajlarını daha anlaşılır hale getir
        String errorMsg = response.errorMessage ?? 'Şifre değiştirirken bir hata oluştu';
        
        // API'den gelen hataları kullanıcı dostu mesajlara çevir
        if (errorMsg.contains('417')) {
          errorMsg = errorMsg.replaceFirst('417 - ', '');
        } else if (errorMsg.contains('current password') || 
                  errorMsg.contains('incorrect password')) {
          errorMsg = 'Mevcut şifreniz hatalı. Lütfen kontrol ediniz.';
        } else if (errorMsg.contains('passwordAgain') || 
                  errorMsg.contains('password match')) {
          errorMsg = 'Girdiğiniz yeni şifreler birbiriyle eşleşmiyor.';
        }
        
        _errorMessage = errorMsg;
        _status = ProfileStatus.passwordError;
        _logger.w('Şifre değiştirme başarısız: $_errorMessage');
      }
    } catch (e) {
      // Genel hata durumunu işle
      _errorMessage = _formatErrorMessage(e.toString());
      _status = ProfileStatus.passwordError;
      _logger.e('Şifre değiştirme hatası:', e);
    } finally {
      _safeNotifyListeners();
    }
  }
  
  // Hata mesajını formatla
  String _formatErrorMessage(String error) {
    if (error.contains('SocketException') || 
        error.contains('Connection refused') || 
        error.contains('Network is unreachable')) {
      return 'İnternet bağlantınızı kontrol ediniz ve tekrar deneyiniz.';
    }
    
    if (error.contains('timed out')) {
      return 'Sunucu yanıt vermedi. Lütfen daha sonra tekrar deneyiniz.';
    }
    
    return 'Şifre değiştirme işlemi sırasında bir hata oluştu. Lütfen tekrar deneyiniz.';
  }
} 