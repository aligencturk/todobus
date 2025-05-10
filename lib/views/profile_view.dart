import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import '../viewmodels/profile_viewmodel.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../services/storage_service.dart';
import '../services/logger_service.dart';
import 'login_view.dart';
import 'dart:io' show Platform;

class ProfileView extends StatefulWidget {
  const ProfileView({Key? key}) : super(key: key);

  @override
  _ProfileViewState createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final StorageService _storageService = StorageService();
  final LoggerService _logger = LoggerService();
  
  PackageInfo _packageInfo = PackageInfo(
    appName: 'TodoBus',
    packageName: 'com.example.todobus',
    version: 'Bilinmiyor',
    buildNumber: 'Bilinmiyor',
  );
  
  String _deviceInfo = 'Cihaz bilgisi yükleniyor...';
  String _userName = "Kullanıcı";
  
  @override
  void initState() {
    super.initState();
    _initPackageInfo();
    _initDeviceInfo();
    _getUserInfo();
  }
  
  Future<void> _getUserInfo() async {
    final userName = await _storageService.getUserName();
    if (userName != null && userName.isNotEmpty) {
      setState(() {
        _userName = userName;
      });
    }
  }

  Future<void> _initPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _packageInfo = info;
    });
  }

  Future<void> _initDeviceInfo() async {
    final deviceInfoPlugin = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfoPlugin.androidInfo;
        setState(() {
          _deviceInfo = '${androidInfo.brand} ${androidInfo.model} - Android ${androidInfo.version.release} (SDK ${androidInfo.version.sdkInt})';
        });
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfoPlugin.iosInfo;
        setState(() {
          _deviceInfo = '${iosInfo.name} - iOS ${iosInfo.systemVersion}';
        });
      } else {
        setState(() {
          _deviceInfo = 'Desteklenmeyen platform';
        });
      }
    } catch (e) {
      _logger.e('Cihaz bilgisi alınamadı:', e);
      setState(() {
        _deviceInfo = 'Cihaz bilgisi alınamadı';
      });
    }
  }
  
  Future<void> _logout() async {
    await _storageService.clearUserData();
    _logger.i('Kullanıcı çıkış yaptı');
    
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        platformPageRoute(
          context: context,
          builder: (context) => const LoginView(),
        ),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: const Text('Profil'),
        material: (_, __) => MaterialAppBarData(
          actions: <Widget>[
            IconButton(
              icon: Icon(context.platformIcons.share),
              onPressed: _logout,
              tooltip: 'Çıkış Yap',
            ),
          ],
        ),
        cupertino: (_, __) => CupertinoNavigationBarData(
          transitionBetweenRoutes: false,
          trailing: CupertinoButton(
            padding: EdgeInsets.zero,
            child: Icon(context.platformIcons.share),
            onPressed: _logout,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildProfileHeader(),
            const SizedBox(height: 24),
            _buildSectionHeader(context, 'Hesap Bilgileri'),
            _buildListItem(context, 'Kullanıcı Adı', _userName),
            _buildListItem(context, 'E-posta', 'kullanici@todobus.com'),
            const SizedBox(height: 24),
            _buildSectionHeader(context, 'Uygulama Bilgileri'),
            _buildListItem(context, 'Versiyon', '${_packageInfo.version} (${_packageInfo.buildNumber})'),
            _buildListItem(context, 'Paket Adı', _packageInfo.packageName),
            const SizedBox(height: 24),
            _buildSectionHeader(context, 'Cihaz Bilgileri'),
            _buildListItem(context, 'Cihaz', _deviceInfo),
            const SizedBox(height: 32),
            PlatformElevatedButton(
              onPressed: _logout,
              child: Text(
                'Çıkış Yap',
                style: TextStyle(
                  color: isCupertino(context) ? CupertinoColors.white : null,
                ),
              ),
              material: (_, __) => MaterialElevatedButtonData(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              cupertino: (_, __) => CupertinoElevatedButtonData(
                color: CupertinoColors.destructiveRed,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildProfileHeader() {
    return Center(
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: platformThemeData(
                context,
                material: (data) => Colors.blue.shade100,
                cupertino: (data) => CupertinoColors.activeBlue.withOpacity(0.2),
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                context.platformIcons.person,
                size: 50,
                color: platformThemeData(
                  context,
                  material: (data) => Colors.blue,
                  cupertino: (data) => CupertinoColors.activeBlue,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _userName,
            style: platformThemeData(
              context,
              material: (data) => data.textTheme.headlineSmall,
              cupertino: (data) => data.textTheme.navLargeTitleTextStyle.copyWith(fontSize: 24),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'TodoBus Kullanıcısı',
            style: platformThemeData(
              context,
              material: (data) => data.textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
              cupertino: (data) => data.textTheme.textStyle.copyWith(color: CupertinoColors.secondaryLabel),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSectionHeader(BuildContext context, String title) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: platformThemeData(
          context,
          material: (data) => data.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          cupertino: (data) => data.textTheme.navTitleTextStyle.copyWith(
            fontWeight: FontWeight.bold,
            color: CupertinoColors.activeBlue,
          ),
        ),
      ),
    );
  }
  
  Widget _buildListItem(BuildContext context, String title, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: platformThemeData(
          context,
          material: (data) => data.cardColor,
          cupertino: (data) => CupertinoColors.systemBackground,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: isCupertino(context)
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              title,
              style: platformThemeData(
                context,
                material: (data) => data.textTheme.titleSmall,
                cupertino: (data) => data.textTheme.textStyle.copyWith(fontWeight: FontWeight.w500),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: platformThemeData(
                context,
                material: (data) => data.textTheme.bodyMedium,
                cupertino: (data) => data.textTheme.textStyle.copyWith(color: CupertinoColors.secondaryLabel),
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
} 