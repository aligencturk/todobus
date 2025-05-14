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
  
  // Genişletilebilir panellerin durumlarını takip etmek için
  bool _isAccountSectionExpanded = false;
  bool _isHelpSectionExpanded = false;
  bool _isAppInfoSectionExpanded = false;
  
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

  void _launchWebsite() {
    // Web sitesi bağlantısı açılacak
    // URL launcher kullanılabilir
    _logger.i('Todobus web sitesi açılıyor');
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
          
          // Hesap Bilgileri bölümü - genişletilebilir panel
          _buildExpandableSection(
            context,
            title: 'Hesap Bilgileri',
            isExpanded: _isAccountSectionExpanded,
            onTap: () {
              setState(() {
                _isAccountSectionExpanded = !_isAccountSectionExpanded;
              });
            },
            children: [
              _buildListItem(context, 'Ad Soyad', user?.userFullname ?? ""),
              _buildListItem(context, 'E-posta', user?.userEmail ?? ""),
              _buildListItem(context, 'Doğum Tarihi', user?.userBirthday ?? ""),
              _buildListItem(context, 'Telefon', user?.userPhone ?? ""),
              _buildListItem(context, 'Cinsiyet', user?.userGender ?? ""),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Yardım bölümü - genişletilebilir panel
          _buildExpandableSection(
            context,
            title: 'Yardım',
            isExpanded: _isHelpSectionExpanded,
            onTap: () {
              setState(() {
                _isHelpSectionExpanded = !_isHelpSectionExpanded;
              });
            },
            children: [
              _buildListItem(context, 'SSS', 'Sıkça Sorulan Sorular'),
              _buildListItem(context, 'İletişim', 'Bize Ulaşın'),
              _buildListItem(context, 'Kullanım Şartları', 'Uygulama Koşulları'),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Uygulama Bilgileri bölümü - genişletilebilir panel
          _buildExpandableSection(
            context,
            title: 'Uygulama Bilgileri',
            isExpanded: _isAppInfoSectionExpanded,
            onTap: () {
              setState(() {
                _isAppInfoSectionExpanded = !_isAppInfoSectionExpanded;
              });
            },
            children: [
              _buildListItem(context, 'Uygulama Adı', viewModel.appName),
              _buildListItem(context, 'Versiyon', '${viewModel.appVersion} (${viewModel.buildNumber})'),
              _buildListItem(context, 'Web Sitesi', 'todobus.tr', 
                onTap: _launchWebsite,
                isLink: true
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Web sitesi linki
          GestureDetector(
            onTap: _launchWebsite,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: Text(
                  'todobus.tr',
                  style: TextStyle(
                    color: platformThemeData(
                      context,
                      material: (data) => Colors.blue,
                      cupertino: (data) => CupertinoColors.activeBlue,
                    ),
                    decoration: TextDecoration.underline,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Powered by Rivorya Yazılım
          Center(
            child: Text(
              'Powered by Rivorya Yazılım',
              style: platformThemeData(
                context,
                material: (data) => data.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
                cupertino: (data) => data.textTheme.textStyle.copyWith(
                  fontSize: 14,
                  color: CupertinoColors.secondaryLabel,
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
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
          
          const SizedBox(height: 16),
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
  
  Widget _buildExpandableSection(
    BuildContext context, {
    required String title,
    required bool isExpanded,
    required VoidCallback onTap,
    required List<Widget> children,
  }) {
    return Container(
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
      child: Column(
        children: [
          // Başlık ve genişletme iconu
          InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: platformThemeData(
                      context,
                      material: (data) => data.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      cupertino: (data) => data.textTheme.navTitleTextStyle.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                  ),
                ],
              ),
            ),
          ),
          // Genişletildiğinde gösterilecek içerik
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(children: children),
            ),
        ],
      ),
    );
  }
  
  Widget _buildListItem(
    BuildContext context, 
    String title, 
    String value, {
    VoidCallback? onTap, 
    bool isLink = false
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        margin: const EdgeInsets.only(bottom: 8, right: 16, left: 16),
        decoration: BoxDecoration(
          color: platformThemeData(
            context,
            material: (data) => data.cardColor.withOpacity(0.7),
            cupertino: (data) => CupertinoColors.systemBackground,
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: platformThemeData(
              context,
              material: (data) => Colors.grey.shade200,
              cupertino: (data) => CupertinoColors.systemGrey5,
            ),
          ),
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
                style: TextStyle(
                  fontWeight: isLink ? FontWeight.w500 : FontWeight.normal,
                  color: isLink
                      ? platformThemeData(
                          context,
                          material: (data) => Colors.blue,
                          cupertino: (data) => CupertinoColors.activeBlue,
                        )
                      : platformThemeData(
                          context,
                          material: (data) => data.textTheme.bodyMedium?.color,
                          cupertino: (data) => CupertinoColors.secondaryLabel,
                        ),
                  decoration: isLink ? TextDecoration.underline : null,
                ),
                textAlign: TextAlign.right,
              ),
            ),
            if (onTap != null && !isLink)
              Icon(
                context.platformIcons.rightChevron,
                size: 16,
                color: platformThemeData(
                  context,
                  material: (data) => Colors.grey,
                  cupertino: (data) => CupertinoColors.systemGrey,
                ),
              ),
          ],
        ),
      ),
    );
  }
} 