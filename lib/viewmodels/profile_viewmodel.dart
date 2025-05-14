import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/logger_service.dart';
import '../services/device_info_service.dart';

enum ProfileStatus { initial, loading, loaded, error }

class ProfileViewModel with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final LoggerService _logger = LoggerService();
  final DeviceInfoService _deviceInfoService = DeviceInfoService();
  
  ProfileStatus _status = ProfileStatus.initial;
  String _errorMessage = '';
  User? _user;
  bool _isDisposed = false;
  
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
} 