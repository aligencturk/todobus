import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'logger_service.dart';

class DeviceInfoService {
  static final DeviceInfoService _instance = DeviceInfoService._internal();
  final LoggerService _logger = LoggerService();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  PackageInfo? _packageInfo;
  bool _initialized = false;

  factory DeviceInfoService() {
    return _instance;
  }

  DeviceInfoService._internal();

  Future<void> init() async {
    if (!_initialized) {
      try {
        _packageInfo = await PackageInfo.fromPlatform();
        _initialized = true;
        _logger.i('DeviceInfoService başlatıldı');
      } catch (e) {
        _logger.e('DeviceInfoService başlatma hatası:', e);
      }
    }
  }

  // Uygulama adını döndürür
  String getAppName() {
    _ensureInitialized();
    return _packageInfo?.appName ?? 'TodoBus';
  }

  // Uygulama paket adını döndürür
  String getPackageName() {
    _ensureInitialized();
    return _packageInfo?.packageName ?? '';
  }

  // Uygulama versiyonunu döndürür
  String getAppVersion() {
    _ensureInitialized();
    return _packageInfo?.version ?? '1.0.1';
  }

  // Uygulama build numarasını döndürür
  String getBuildNumber() {
    _ensureInitialized();
    return _packageInfo?.buildNumber ?? '';
  }

  // Platform bilgisini döndürür
  String getPlatformName() {
    if (kIsWeb) return 'web';
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isLinux) return 'linux';
    if (Platform.isFuchsia) return 'fuchsia';
    return 'unknown';
  }

  // Cihaz modelini döndürür
  Future<String> getDeviceModel() async {
    try {
      if (kIsWeb) {
        return 'Web Browser';
      } else if (Platform.isAndroid) {
        final info = await _deviceInfo.androidInfo;
        return '${info.brand} ${info.model}';
      } else if (Platform.isIOS) {
        final info = await _deviceInfo.iosInfo;
        return '${info.name} ${info.model}';
      } else if (Platform.isWindows) {
        final info = await _deviceInfo.windowsInfo;
        return 'Windows ${info.computerName}';
      } else if (Platform.isMacOS) {
        final info = await _deviceInfo.macOsInfo;
        return 'MacOS ${info.computerName}';
      } else if (Platform.isLinux) {
        final info = await _deviceInfo.linuxInfo;
        return 'Linux ${info.name}';
      }
      return 'Unknown Device';
    } catch (e) {
      _logger.e('Cihaz modeli alınırken hata oluştu:', e);
      return 'Unknown Device';
    }
  }

  // İşletim sistemi versiyonunu döndürür
  Future<String> getOSVersion() async {
    try {
      if (kIsWeb) {
        return 'Web';
      } else if (Platform.isAndroid) {
        final info = await _deviceInfo.androidInfo;
        return 'Android ${info.version.release} (SDK ${info.version.sdkInt})';
      } else if (Platform.isIOS) {
        final info = await _deviceInfo.iosInfo;
        return 'iOS ${info.systemVersion}';
      } else if (Platform.isWindows) {
        final info = await _deviceInfo.windowsInfo;
        return 'Windows ${info.majorVersion}.${info.minorVersion}.${info.buildNumber}';
      } else if (Platform.isMacOS) {
        final info = await _deviceInfo.macOsInfo;
        return 'MacOS ${info.osRelease}';
      } else if (Platform.isLinux) {
        final info = await _deviceInfo.linuxInfo;
        return 'Linux ${info.version}';
      }
      return 'Unknown OS';
    } catch (e) {
      _logger.e('İşletim sistemi versiyonu alınırken hata oluştu:', e);
      return 'Unknown OS';
    }
  }

  // Cihaz ID'sini döndürür (dikkat: tüm platformlarda desteklenmeyebilir)
  Future<String> getDeviceId() async {
    try {
      if (Platform.isAndroid) {
        final info = await _deviceInfo.androidInfo;
        return info.id;
      } else if (Platform.isIOS) {
        final info = await _deviceInfo.iosInfo;
        return info.identifierForVendor ?? '';
      }
      return '';
    } catch (e) {
      _logger.e('Cihaz ID alınırken hata oluştu:', e);
      return '';
    }
  }
  
  // API için platform tipini döndürür
  String getApiPlatformType() {
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android'; 
    return 'other';
  }

  void _ensureInitialized() {
    if (!_initialized) {
      _logger.w('DeviceInfoService henüz başlatılmadı!');
    }
  }
} 