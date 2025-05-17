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

  // Profil düzenleme ekranını aç
  void _navigateToEditProfile() {
    final user = context.read<ProfileViewModel>().user;
    if (user != null) {
      Navigator.push(
        context,
        platformPageRoute(
          context: context,
          builder: (context) => EditProfileView(user: user),
        ),
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
                  icon: const Icon(Icons.edit),
                  onPressed: viewModel.user != null ? _navigateToEditProfile : null,
                  tooltip: 'Profili Düzenle',
                ),
                IconButton(
                  icon: const Icon(Icons.exit_to_app),
                  onPressed: _logout,
                  tooltip: 'Çıkış Yap',
                ),
              ],
            ),
            cupertino: (_, __) => CupertinoNavigationBarData(
              transitionBetweenRoutes: false,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: const Icon(CupertinoIcons.pencil),
                    onPressed: viewModel.user != null ? _navigateToEditProfile : null,
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: const Icon(CupertinoIcons.square_arrow_right),
                    onPressed: _logout,
                  ),
                ],
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
          
          // Düzenle butonu
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: PlatformElevatedButton(
              onPressed: _navigateToEditProfile,
              child: Text(
                'Profili Düzenle',
                style: TextStyle(
                  color: isCupertino(context) ? CupertinoColors.white : null,
                ),
              ),
              material: (_, __) => MaterialElevatedButtonData(
                icon: const Icon(Icons.edit),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              cupertino: (_, __) => CupertinoElevatedButtonData(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          
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
              _buildListItem(context, 'Cinsiyet', _getGenderText(user?.userGender ?? "")),
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
  
  // Cinsiyet değerini metne çevir
  String _getGenderText(String genderValue) {
    switch(genderValue) {
      case "1": return "Erkek";
      case "2": return "Kadın";
      default: return "Belirtilmemiş";
    }
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

// Profil Düzenleme Ekranı
class EditProfileView extends StatefulWidget {
  final User user;
  
  const EditProfileView({Key? key, required this.user}) : super(key: key);

  @override
  _EditProfileViewState createState() => _EditProfileViewState();
}

class _EditProfileViewState extends State<EditProfileView> {
  final LoggerService _logger = LoggerService();
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _fullNameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _birthdayController;
  
  int _selectedGender = 0;
  bool _isLoading = false;
  String _errorMessage = '';
  
  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(text: widget.user.userFullname);
    _emailController = TextEditingController(text: widget.user.userEmail);
    _phoneController = TextEditingController(text: widget.user.userPhone);
    _birthdayController = TextEditingController(text: widget.user.userBirthday);
    
    try {
      _selectedGender = int.parse(widget.user.userGender);
    } catch (e) {
      _selectedGender = 0;
    }
  }
  
  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _birthdayController.dispose();
    super.dispose();
  }
  
  // Profil güncelleme işlemi
  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      await context.read<ProfileViewModel>().updateUserProfile(
        userFullname: _fullNameController.text,
        userEmail: _emailController.text,
        userBirthday: _birthdayController.text,
        userPhone: _phoneController.text,
        userGender: _selectedGender,
        profilePhoto: widget.user.profilePhoto,
      );
      
      if (mounted) {
        if (context.read<ProfileViewModel>().status == ProfileStatus.updateSuccess) {
          Navigator.pop(context);
          _showSuccessMessage('Profil başarıyla güncellendi');
        } else {
          setState(() {
            _errorMessage = context.read<ProfileViewModel>().errorMessage;
          });
        }
      }
    } catch (e) {
      _logger.e('Profil güncellenirken hata: $e');
      setState(() {
        _errorMessage = 'Bir hata oluştu: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  // Başarı mesajı göster
  void _showSuccessMessage(String message) {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: const Text('Profili Düzenle'),
        material: (_, __) => MaterialAppBarData(
          actions: <Widget>[
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _isLoading ? null : _updateProfile,
              tooltip: 'Kaydet',
            ),
          ],
        ),
        cupertino: (_, __) => CupertinoNavigationBarData(
          transitionBetweenRoutes: false,
          trailing: _isLoading 
          ? const CupertinoActivityIndicator()
          : CupertinoButton(
              padding: EdgeInsets.zero,
              child: const Text('Kaydet'),
              onPressed: _updateProfile,
            ),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              if (_errorMessage.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: platformThemeData(
                      context,
                      material: (data) => Colors.red.shade100,
                      cupertino: (data) => CupertinoColors.systemRed.withOpacity(0.2),
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorMessage,
                    style: TextStyle(
                      color: platformThemeData(
                        context,
                        material: (data) => Colors.red,
                        cupertino: (data) => CupertinoColors.systemRed,
                      ),
                    ),
                  ),
                ),
              
              _buildTextFormField(
                context: context,
                controller: _fullNameController,
                label: 'Ad Soyad',
                keyboardType: TextInputType.name,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Ad Soyad boş olamaz';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              _buildTextFormField(
                context: context,
                controller: _emailController,
                label: 'E-posta',
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'E-posta boş olamaz';
                  }
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                    return 'Geçerli bir e-posta adresi giriniz';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              _buildTextFormField(
                context: context,
                controller: _birthdayController,
                label: 'Doğum Tarihi (GG.AA.YYYY)',
                keyboardType: TextInputType.datetime,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return null; // İsteğe bağlı
                  }
                  // Tarih formatı kontrolü
                  if (!RegExp(r'^\d{2}\.\d{2}\.\d{4}$').hasMatch(value)) {
                    return 'Geçerli bir tarih formatı giriniz (GG.AA.YYYY)';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              _buildTextFormField(
                context: context,
                controller: _phoneController,
                label: 'Telefon',
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return null; // İsteğe bağlı
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 24),
              
              _buildGenderSelection(context),
              
              const SizedBox(height: 32),
              
              if (_isLoading)
                Center(child: PlatformCircularProgressIndicator())
              else
                PlatformElevatedButton(
                  onPressed: _updateProfile,
                  child: const Text('Profili Güncelle'),
                  material: (_, __) => MaterialElevatedButtonData(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                  cupertino: (_, __) => CupertinoElevatedButtonData(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Form alanı widget'ı
  Widget _buildTextFormField({
    required BuildContext context,
    required TextEditingController controller,
    required String label,
    required TextInputType keyboardType,
    String? Function(String?)? validator,
  }) {
    return isCupertino(context)
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              CupertinoTextFormFieldRow(
                controller: controller,
                keyboardType: keyboardType,
                validator: validator,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: CupertinoColors.systemGrey4),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          )
        : TextFormField(
            controller: controller,
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            ),
            keyboardType: keyboardType,
            validator: validator,
          );
  }
  
  // Cinsiyet seçim widget'ı
  Widget _buildGenderSelection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Cinsiyet',
            style: platformThemeData(
              context,
              material: (data) => data.textTheme.titleMedium,
              cupertino: (data) => data.textTheme.textStyle.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            border: isCupertino(context) 
              ? Border.all(color: CupertinoColors.systemGrey4) 
              : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              _buildGenderOption(context, 'Belirtilmemiş', 0),
              const Divider(height: 1),
              _buildGenderOption(context, 'Erkek', 1),
              const Divider(height: 1),
              _buildGenderOption(context, 'Kadın', 2),
            ],
          ),
        ),
      ],
    );
  }
  
  // Cinsiyet seçim opsiyonu
  Widget _buildGenderOption(BuildContext context, String label, int value) {
    return InkWell(
      onTap: () {
        setState(() {
          _selectedGender = value;
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: Text(label),
            ),
            if (isCupertino(context))
              _selectedGender == value
                  ? const Icon(CupertinoIcons.check_mark, color: CupertinoColors.activeBlue)
                  : const SizedBox(width: 24)
            else
              Radio<int>(
                value: value,
                groupValue: _selectedGender,
                onChanged: (int? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedGender = newValue;
                    });
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
} 