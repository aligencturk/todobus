import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import '../viewmodels/profile_viewmodel.dart';
import '../models/user_model.dart';
import '../services/storage_service.dart';
import '../services/logger_service.dart';
import 'login_view.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({Key? key}) : super(key: key);

  @override
  _ProfileViewState createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final StorageService _storageService = StorageService();
  final LoggerService _logger = LoggerService();
  
  @override
  void initState() {
    super.initState();
    // Sayfa açıldığında profil verilerini yükle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProfileViewModel>().loadUserProfile();
    });
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
    return Consumer<ProfileViewModel>(
      builder: (context, viewModel, _) {
        return PlatformScaffold(
          appBar: PlatformAppBar(
            title: const Text('Profil'),
            material: (_, __) => MaterialAppBarData(
              actions: <Widget>[
                IconButton(
                  icon: const Icon(Icons.exit_to_app),
                  onPressed: _logout,
                  tooltip: 'Çıkış Yap',
                ),
              ],
            ),
            cupertino: (_, __) => CupertinoNavigationBarData(
              transitionBetweenRoutes: false,
              trailing: CupertinoButton(
                padding: EdgeInsets.zero,
                child: const Icon(CupertinoIcons.square_arrow_right),
                onPressed: _logout,
              ),
            ),
          ),
          body: _buildBody(context, viewModel),
        );
      },
    );
  }
  
  Widget _buildBody(BuildContext context, ProfileViewModel viewModel) {
    if (viewModel.status == ProfileStatus.loading) {
      return Center(
        child: PlatformCircularProgressIndicator(),
      );
    } else if (viewModel.status == ProfileStatus.error) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Bir hata oluştu',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: platformThemeData(
                  context,
                  material: (data) => Colors.red,
                  cupertino: (data) => CupertinoColors.systemRed,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(viewModel.errorMessage),
            const SizedBox(height: 16),
            PlatformElevatedButton(
              onPressed: () => viewModel.loadUserProfile(),
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      );
    }
    
    final user = viewModel.user;
    
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildProfileHeader(context, user),
          const SizedBox(height: 24),
          
          _buildSectionHeader(context, 'Hesap Bilgileri'),
          _buildListItem(context, 'Kullanıcı ID', '${user?.userID ?? ""}'),
          _buildListItem(context, 'Kullanıcı Adı', user?.username ?? ""),
          _buildListItem(context, 'Ad', user?.userFirstname ?? ""),
          _buildListItem(context, 'Soyad', user?.userLastname ?? ""),
          _buildListItem(context, 'Tam Ad', user?.userFullname ?? ""),
          _buildListItem(context, 'E-posta', user?.userEmail ?? ""),
          _buildListItem(context, 'Doğum Tarihi', user?.userBirthday ?? ""),
          _buildListItem(context, 'Telefon', user?.userPhone ?? ""),
          _buildListItem(context, 'Cinsiyet', user?.userGender ?? ""),
          _buildListItem(context, 'Durum', user?.userStatus ?? ""),
          _buildListItem(context, 'Rütbe', user?.userRank ?? ""),
          
          const SizedBox(height: 24),
          _buildSectionHeader(context, 'Cihaz Bilgileri'),
          _buildListItem(context, 'Platform', viewModel.platformInfo),
          _buildListItem(context, 'Cihaz Modeli', viewModel.deviceModel),
          _buildListItem(context, 'İşletim Sistemi', viewModel.osVersion),
          _buildListItem(context, 'Platform Türü', user?.userPlatform ?? ""),
          _buildListItem(context, 'Versiyon', user?.userVersion ?? ""),
          _buildListItem(context, 'iOS Versiyonu', user?.iosVersion ?? ""),
          _buildListItem(context, 'Android Versiyonu', user?.androidVersion ?? ""),
          
          const SizedBox(height: 24),
          _buildSectionHeader(context, 'Uygulama Bilgileri'),
          _buildListItem(context, 'Uygulama Adı', viewModel.appName),
          _buildListItem(context, 'Versiyon', '${viewModel.appVersion} (${viewModel.buildNumber})'),
          _buildListItem(context, 'Paket Adı', viewModel.packageName),
          
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
    );
  }
  
  Widget _buildProfileHeader(BuildContext context, User? user) {
    String profileImageUrl = user?.profilePhoto ?? '';
    bool hasProfileImage = profileImageUrl.isNotEmpty && profileImageUrl != 'null';
    
    return Center(
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: hasProfileImage 
                  ? null 
                  : platformThemeData(
                      context,
                      material: (data) => Colors.blue.shade100,
                      cupertino: (data) => CupertinoColors.activeBlue.withOpacity(0.2),
                    ),
              shape: BoxShape.circle,
              image: hasProfileImage
                  ? DecorationImage(
                      image: NetworkImage(profileImageUrl),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: !hasProfileImage 
                ? Center(
                    child: Icon(
                      context.platformIcons.person,
                      size: 50,
                      color: platformThemeData(
                        context,
                        material: (data) => Colors.blue,
                        cupertino: (data) => CupertinoColors.activeBlue,
                      ),
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 16),
          Text(
            user?.userFullname ?? 'Yükleniyor...',
            style: platformThemeData(
              context,
              material: (data) => data.textTheme.headlineSmall,
              cupertino: (data) => data.textTheme.navLargeTitleTextStyle.copyWith(fontSize: 24),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            user?.userRank ?? 'TodoBus Kullanıcısı',
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