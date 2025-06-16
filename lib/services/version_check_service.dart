import 'dart:io';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/logger_service.dart';
import '../services/storage_service.dart';

class VersionCheckService {
  static final VersionCheckService _instance = VersionCheckService._internal();
  final LoggerService _logger = LoggerService();
  final StorageService _storageService = StorageService();
  late FirebaseRemoteConfig _remoteConfig;
  
  factory VersionCheckService() => _instance;
  VersionCheckService._internal();

  /// Remote Config'i başlat
  Future<void> initialize() async {
    try {
      _remoteConfig = FirebaseRemoteConfig.instance;
      
      // Remote Config ayarları
      await _remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(hours: 1),
      ));

      // Varsayılan değerler
      await _remoteConfig.setDefaults({
        'min_ios_version': '1.0.1',
        'min_android_version': '1.0.1',
        'current_ios_version': '1.0.1',
        'current_android_version': '1.0.1',
        'force_update_ios': false,
        'force_update_android': false,
        'update_message_ios': 'Yeni bir sürüm mevcut! Güncellemek için App Store\'a gidin.',
        'update_message_android': 'Yeni bir sürüm mevcut! Güncellemek için Play Store\'a gidin.',
        'force_update_message': 'Bu sürüm artık desteklenmiyor. Uygulamayı güncellemeden devam edemezsiniz.',
        'ios_store_url': 'https://apps.apple.com/app/todobus/id6738289053',
        'android_store_url': 'https://play.google.com/store/apps/details?id=com.rivorya.todobus',
      });

      // Remote Config verilerini getir
      await _remoteConfig.fetchAndActivate();
      
      _logger.i('✅ Version Check Service başlatıldı');
    } catch (e) {
      _logger.e('❌ Version Check Service başlatılamadı: $e');
    }
  }

  /// Remote Config cache'ini temizle ve varsayılan değerleri yeniden yükle
  Future<void> resetToDefaults() async {
    try {
      _logger.i('🔄 Remote Config sıfırlanıyor...');
      
      // Cache'i temizle
      await _remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(minutes: 1),
        minimumFetchInterval: Duration.zero, // Hemen fetch etmek için
      ));
      
      // Varsayılan değerleri tekrar ayarla
      await _remoteConfig.setDefaults({
        'min_ios_version': '1.0.1',
        'min_android_version': '1.0.1',
        'current_ios_version': '1.0.1',
        'current_android_version': '1.0.1',
        'force_update_ios': false,
        'force_update_android': false,
        'update_message_ios': 'Yeni bir sürüm mevcut! Güncellemek için App Store\'a gidin.',
        'update_message_android': 'Yeni bir sürüm mevcut! Güncellemek için Play Store\'a gidin.',
        'force_update_message': 'Bu sürüm artık desteklenmiyor. Uygulamayı güncellemeden devam edemezsiniz.',
        'ios_store_url': 'https://apps.apple.com/app/todobus/id6738289053',
        'android_store_url': 'https://play.google.com/store/apps/details?id=com.rivorya.todobus',
      });
      
      // Yeni verilerle fetch et
      await _remoteConfig.fetchAndActivate();
      
      _logger.i('✅ Remote Config başarıyla sıfırlandı');
      
    } catch (e) {
      _logger.e('❌ Remote Config sıfırlanırken hata: $e');
    }
  }

  /// Sürüm kontrolü yap ve gerekirse güncelleme bildirimi göster
  Future<void> checkForUpdates(BuildContext context) async {
    try {
      // Güncel uygulama bilgilerini al
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final platform = Platform.isIOS ? 'ios' : 'android';
      
      _logger.i('🔍 Sürüm kontrolü: $platform v$currentVersion');
      
      // Remote Config'den minimum ve güncel sürümleri al
      final minVersion = _remoteConfig.getString('min_${platform}_version');
      final currentRemoteVersion = _remoteConfig.getString('current_${platform}_version');
      final forceUpdate = _remoteConfig.getBool('force_update_$platform');
      
      _logger.i('📊 Minimum sürüm: $minVersion');
      _logger.i('📊 Güncel uzak sürüm: $currentRemoteVersion');
      _logger.i('📊 Zorla güncelleme: $forceUpdate');
      
      // Tüm Remote Config değerlerini debug için göster
      _logger.i('🔧 Debug - Tüm Remote Config değerleri:');
      _logger.i('  min_ios_version: ${_remoteConfig.getString('min_ios_version')}');
      _logger.i('  min_android_version: ${_remoteConfig.getString('min_android_version')}');
      _logger.i('  current_ios_version: ${_remoteConfig.getString('current_ios_version')}');
      _logger.i('  current_android_version: ${_remoteConfig.getString('current_android_version')}');
      _logger.i('  force_update_ios: ${_remoteConfig.getBool('force_update_ios')}');
      _logger.i('  force_update_android: ${_remoteConfig.getBool('force_update_android')}');
      
      // Sürüm karşılaştırması
      final needsUpdate = _isVersionLower(currentVersion, currentRemoteVersion);
      final isBelowMinimum = _isVersionLower(currentVersion, minVersion);
      
      _logger.i('🔍 Sürüm karşılaştırması:');
      _logger.i('  Mevcut sürüm: $currentVersion');
      _logger.i('  Minimum sürüm: $minVersion');
      _logger.i('  Uzak sürüm: $currentRemoteVersion');
      _logger.i('  Güncelleme gerekiyor: $needsUpdate');
      _logger.i('  Minimum altında: $isBelowMinimum');
      _logger.i('  Zorla güncelleme aktif: $forceUpdate');
      
      // UYARI: Eğer force update aktifse nedenini belirt
      if (forceUpdate) {
        _logger.w('⚠️ ZORLA GÜNCELLEME AKTİF! Firebase Remote Config\'de force_update_$platform = true olarak ayarlanmış!');
      }
      
      // UYARI: Eğer minimum sürümün altındaysa detay ver
      if (isBelowMinimum) {
        _logger.w('⚠️ MEVCUT SÜRÜM MİNİMUMUN ALTINDA!');
        _logger.w('  Mevcut: $currentVersion');
        _logger.w('  Minimum: $minVersion');
        final currentParts = currentVersion.split('.').map(int.parse).toList();
        final minParts = minVersion.split('.').map(int.parse).toList();
        for (int i = 0; i < 3; i++) {
          final current = i < currentParts.length ? currentParts[i] : 0;
          final minimum = i < minParts.length ? minParts[i] : 0;
          _logger.w('  Kısım $i: $current vs $minimum');
        }
      }
      
      if (isBelowMinimum || forceUpdate) {
        // Zorla güncelleme
        _logger.w('⚠️ ZORLA GÜNCELLEME GEREKİYOR!');
        _logger.w('  Sebep - Minimum altında: $isBelowMinimum');
        _logger.w('  Sebep - Zorla güncelleme: $forceUpdate');
        if (context.mounted) {
          await _showForceUpdateDialog(context, platform);
        }
      } else if (needsUpdate) {
        // Opsiyonel güncelleme
        _logger.i('📱 Opsiyonel güncelleme mevcut');
        if (context.mounted) {
          await _showOptionalUpdateDialog(context, platform);
        }
      } else {
        _logger.i('✅ Uygulama güncel');
      }
      
    } catch (e) {
      _logger.e('❌ Sürüm kontrolünde hata: $e');
    }
  }

  /// Manuel debug kontrolü (geliştirme amaçlı)
  Future<void> debugVersionCheck() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final platform = Platform.isIOS ? 'ios' : 'android';
      
      print('=== VERSION DEBUG INFO ===');
      print('Platform: $platform');
      print('Current App Version: $currentVersion');
      print('');
      print('Remote Config Values:');
      print('  min_ios_version: ${_remoteConfig.getString('min_ios_version')}');
      print('  min_android_version: ${_remoteConfig.getString('min_android_version')}');
      print('  current_ios_version: ${_remoteConfig.getString('current_ios_version')}');
      print('  current_android_version: ${_remoteConfig.getString('current_android_version')}');
      print('  force_update_ios: ${_remoteConfig.getBool('force_update_ios')}');
      print('  force_update_android: ${_remoteConfig.getBool('force_update_android')}');
      print('');
      
      final minVersion = _remoteConfig.getString('min_${platform}_version');
      final forceUpdate = _remoteConfig.getBool('force_update_$platform');
      final isBelowMinimum = _isVersionLower(currentVersion, minVersion);
      
      print('For Current Platform ($platform):');
      print('  Minimum Version: $minVersion');
      print('  Force Update: $forceUpdate');
      print('  Is Below Minimum: $isBelowMinimum');
      print('');
      print('CONCLUSION:');
      if (isBelowMinimum) {
        print('❌ PROBLEM: Your app version ($currentVersion) is below minimum ($minVersion)');
      }
      if (forceUpdate) {
        print('❌ PROBLEM: Force update is enabled in Firebase Remote Config');
      }
      if (!isBelowMinimum && !forceUpdate) {
        print('✅ No issues found - app should not show force update');
      }
      print('========================');
      
    } catch (e) {
      print('Error in debug check: $e');
    }
  }

  /// Zorla güncelleme dialogu
  Future<void> _showForceUpdateDialog(BuildContext context, String platform) async {
    final message = _remoteConfig.getString('force_update_message');
    
    if (context.mounted) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.system_update, color: Colors.red),
              SizedBox(width: 8),
              Text('Zorunlu Güncelleme'),
            ],
          ),
          content: Text(message),
          actions: [
            ElevatedButton.icon(
              onPressed: () => _openStore(platform),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Güncelle'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }
  }

  /// Opsiyonel güncelleme dialogu
  Future<void> _showOptionalUpdateDialog(BuildContext context, String platform) async {
    // Kullanıcı daha önce bu sürüm için "Sonra hatırlat" demiş mi kontrol et
    final skipVersion = _storageService.getData('skip_update_version');
    final remoteVersion = _remoteConfig.getString('current_${platform}_version');
    
    if (skipVersion == remoteVersion) {
      _logger.i('📱 Kullanıcı bu sürüm için güncelleme bildirimi atlamış');
      return;
    }
    
    final message = _remoteConfig.getString('update_message_$platform');
    
    if (context.mounted) {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.update, color: Colors.blue),
              SizedBox(width: 8),
              Text('Güncelleme Mevcut'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message),
              const SizedBox(height: 16),
              Text(
                'Yeni sürüm: $remoteVersion',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Bu sürüm için bir süre hatırlatma
                _storageService.saveData('skip_update_version', remoteVersion);
              },
              child: const Text('Sonra Hatırlat'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _openStore(platform);
              },
              icon: const Icon(Icons.open_in_new),
              label: const Text('Güncelle'),
            ),
          ],
        ),
      );
    }
  }

  /// Store'u aç
  Future<void> _openStore(String platform) async {
    try {
      final storeUrl = _remoteConfig.getString('${platform}_store_url');
      final uri = Uri.parse(storeUrl);
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        _logger.i('📱 Store açıldı: $storeUrl');
      } else {
        _logger.e('❌ Store URL açılamadı: $storeUrl');
      }
    } catch (e) {
      _logger.e('❌ Store açılırken hata: $e');
    }
  }

  /// Sürüm karşılaştırması (semantic versioning)
  bool _isVersionLower(String current, String remote) {
    final currentParts = current.split('.').map(int.parse).toList();
    final remoteParts = remote.split('.').map(int.parse).toList();
    
    // Eksik kısımları 0 ile doldur
    while (currentParts.length < 3) {
      currentParts.add(0);
    }
    while (remoteParts.length < 3) {
      remoteParts.add(0);
    }
    
    for (int i = 0; i < 3; i++) {
      if (currentParts[i] < remoteParts[i]) return true;
      if (currentParts[i] > remoteParts[i]) return false;
    }
    
    return false; // Eşitse güncelleme gerekmez
  }

  /// Otomatik sürüm kontrolü (arka planda)
  Future<void> checkForUpdatesInBackground() async {
    try {
      await _remoteConfig.fetchAndActivate();
      _logger.i('🔄 Arka plan sürüm kontrolü tamamlandı');
    } catch (e) {
      _logger.e('❌ Arka plan sürüm kontrolünde hata: $e');
    }
  }

  /// Manuel sürüm bilgilerini güncelle (Admin paneli için)
  Future<void> updateRemoteVersions({
    required String iosVersion,
    required String androidVersion,
    bool forceIosUpdate = false,
    bool forceAndroidUpdate = false,
  }) async {
    // Bu Firebase Console'dan yapılır, burada sadece log
    _logger.i('📝 Manuel sürüm güncelleme:');
    _logger.i('  iOS: $iosVersion (Force: $forceIosUpdate)');
    _logger.i('  Android: $androidVersion (Force: $forceAndroidUpdate)');
  }
} 