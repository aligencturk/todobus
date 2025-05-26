import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../viewmodels/profile_viewmodel.dart';
import '../models/user_model.dart';
import '../services/storage_service.dart';
import '../services/logger_service.dart';
import '../services/auth_service.dart';
import 'login_view.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({Key? key}) : super(key: key);

  @override
  _ProfileViewState createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final StorageService _storageService = StorageService();
  final LoggerService _logger = LoggerService();
  final ImagePicker _imagePicker = ImagePicker();
  final AuthService _authService = AuthService();
  final TextEditingController _activationCodeController = TextEditingController();
  
  // Genişletilebilir panellerin durumlarını takip etmek için
  bool _isAccountSectionExpanded = false;
  bool _isHelpSectionExpanded = false;
  bool _isAppInfoSectionExpanded = false;
  bool _isLoadingImage = false;
  bool _isVerifyingCode = false;
  
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

  void _launchWebsite() async {
    const websiteUrl = 'https://todobus.tr';
    final Uri uri = Uri.parse(websiteUrl);
    
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        _logger.e('Web sitesi açılamadı: $websiteUrl');
        if (mounted) {
          showPlatformDialog(
            context: context,
            builder: (context) => PlatformAlertDialog(
              title: const Text('Hata'),
              content: const Text('Web sitesi açılamadı. Lütfen daha sonra tekrar deneyin.'),
              actions: <Widget>[
                PlatformDialogAction(
                  child: const Text('Tamam'),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          );
        }
      } else {
        _logger.i('Todobus web sitesi açıldı: $websiteUrl');
      }
    } catch (e) {
      _logger.e('Web sitesi açılırken hata oluştu: $e');
      if (mounted) {
        showPlatformDialog(
          context: context,
          builder: (context) => PlatformAlertDialog(
            title: const Text('Hata'),
            content: Text('Web sitesi açılırken bir hata oluştu: ${e.toString()}'),
            actions: <Widget>[
              PlatformDialogAction(
                child: const Text('Tamam'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      }
    }
  }

  void _launchUrl(String url, String pageName) async {
    final Uri uri = Uri.parse(url);
    
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        _logger.e('$pageName açılamadı: $url');
        if (mounted) {
          showPlatformDialog(
            context: context,
            builder: (context) => PlatformAlertDialog(
              title: const Text('Hata'),
              content: Text('$pageName açılamadı. Lütfen daha sonra tekrar deneyin.'),
              actions: <Widget>[
                PlatformDialogAction(
                  child: const Text('Tamam'),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          );
        }
      } else {
        _logger.i('$pageName açıldı: $url');
      }
    } catch (e) {
      _logger.e('$pageName açılırken hata oluştu: $e');
      if (mounted) {
        showPlatformDialog(
          context: context,
          builder: (context) => PlatformAlertDialog(
            title: const Text('Hata'),
            content: Text('$pageName açılırken bir hata oluştu: ${e.toString()}'),
            actions: <Widget>[
              PlatformDialogAction(
                child: const Text('Tamam'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      }
    }
  }

  void _openMembershipAgreement() {
    _launchUrl('https://www.todobus.tr/uyelik-sozlesmesi', 'Üyelik Sözleşmesi');
  }

  void _openPrivacyPolicy() {
    _launchUrl('https://www.todobus.tr/gizlilik-politikasi', 'Gizlilik Politikası');
  }

  void _openKVKKTerms() {
    _launchUrl('https://www.todobus.tr/kvkk-aydinlatma-metni', 'KVKK Aydınlatma Metni');
  }
  
  void _openFAQ() {
    _launchUrl('https://www.todobus.tr/sss', 'SSS');
  }
  
  void _openContact() {
    _launchUrl('https://www.todobus.tr/iletisim', 'İletişim');
  }
  
  void _openTermsOfUse() {
    _launchUrl('https://www.todobus.tr/kullanim-sartlari', 'Kullanım Şartları');
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

  // Şifre değiştirme ekranını aç
  void _navigateToChangePasswordView() {
    Navigator.push(
      context,
      platformPageRoute(
        context: context,
        builder: (context) => const ChangePasswordView(),
      ),
    );
  }

  // Profil fotoğrafı seçme
  Future<void> _pickProfileImage() async {
    try {
      final XFile? pickedImage = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      
      if (pickedImage == null) return;
      
      setState(() {
        _isLoadingImage = true;
      });
      
      // Resmi kırp
      final croppedFile = await _cropImage(File(pickedImage.path));
      if (croppedFile == null) {
        setState(() {
          _isLoadingImage = false;
        });
        return;
      }
      
      // Dosyayı base64'e dönüştür
      final bytes = await croppedFile.readAsBytes();
      final base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      
      // Profil fotoğrafını güncelle
      final viewModel = context.read<ProfileViewModel>();
      await viewModel.updateProfilePhoto(base64Image);
      
      setState(() {
        _isLoadingImage = false;
      });
      
      if (viewModel.status == ProfileStatus.updateError) {
        _showErrorMessage(viewModel.errorMessage);
      }
    } catch (e) {
      _logger.e('Profil fotoğrafı seçilirken hata: $e');
      setState(() {
        _isLoadingImage = false;
      });
      _showErrorMessage('Görsel seçilirken bir hata oluştu: ${e.toString()}');
    }
  }
  
  // Resmi kırpma
  Future<File?> _cropImage(File imageFile) async {
    try {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: imageFile.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        compressQuality: 70,
        compressFormat: ImageCompressFormat.jpg,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Profil Fotoğrafını Düzenle',
            toolbarColor: Colors.blue,
            toolbarWidgetColor: Colors.white,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: 'Profil Fotoğrafını Düzenle',
            aspectRatioLockEnabled: true,
          ),
        ],
      );
      
      return croppedFile != null ? File(croppedFile.path) : null;
    } catch (e) {
      _logger.e('Resim kırpılırken hata: $e');
      return null;
    }
  }
  
  // Hata mesajı göster
  void _showErrorMessage(String message) {
    showPlatformDialog(
      context: context,
      builder: (context) => PlatformAlertDialog(
        title: const Text('Hata'),
        content: Text(message),
        actions: <Widget>[
          PlatformDialogAction(
            child: const Text('Tamam'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  // Hesap aktivasyon diyaloğunu göster
  void _showActivationDialog(BuildContext context) {
    String dialogErrorMessage = '';  // Diyalog için yerel hata mesajı
    bool isVerifyingCodeLocal = false; // Diyalog için yerel yükleme durumu
    final activationCodeController = TextEditingController(); // Yerel controller
    
    showPlatformDialog(
      context: context,
      barrierDismissible: false, // Dışarı tıklayarak kapatılamaz
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => PlatformAlertDialog(
          title: const Text('Hesap Aktivasyonu'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'E-postanıza gönderilen doğrulama kodunu girerek hesabınızı aktifleştirebilirsiniz.',
                style: TextStyle(
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              isCupertino(context)
                  ? CupertinoTextField(
                      controller: activationCodeController,
                      placeholder: 'Doğrulama kodu',
                      keyboardType: TextInputType.number,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                      decoration: BoxDecoration(
                        color: CupertinoColors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: CupertinoColors.systemGrey4),
                      ),
                    )
                  : TextField(
                      controller: activationCodeController,
                      decoration: const InputDecoration(
                        labelText: 'Doğrulama kodu',
                        border: OutlineInputBorder(),
                        filled: true,
                      ),
                      keyboardType: TextInputType.number,
                    ),
              if (dialogErrorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    dialogErrorMessage,
                    style: TextStyle(
                      color: platformThemeData(
                        context,
                        material: (data) => Colors.red,
                        cupertino: (data) => CupertinoColors.systemRed,
                      ),
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          actions: <Widget>[
            PlatformDialogAction(
              child: const Text('İptal'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                activationCodeController.clear();
              },
            ),
            PlatformDialogAction(
              child: isVerifyingCodeLocal 
                  ? PlatformCircularProgressIndicator()
                  : const Text('Doğrula'),
              onPressed: isVerifyingCodeLocal 
                  ? null 
                  : () async {
                      // Aktivasyon kodunu doğrula
                      final code = activationCodeController.text.trim();
                      
                      if (code.isEmpty) {
                        setDialogState(() {
                          dialogErrorMessage = 'Lütfen doğrulama kodunu giriniz.';
                        });
                        return;
                      }
                      
                      // Sadece sayısal değer mi kontrol et
                      if (!RegExp(r'^\d+$').hasMatch(code)) {
                        setDialogState(() {
                          dialogErrorMessage = 'Doğrulama kodu sadece rakamlardan oluşmalıdır.';
                        });
                        return;
                      }
                      
                      setDialogState(() {
                        isVerifyingCodeLocal = true;
                        dialogErrorMessage = '';
                      });
                      
                      try {
                        // StorageService'den user_id'yi alıyoruz token olarak kullanmak için
                        final userId = await _storageService.getUserId();
                        
                        if (userId == null) {
                          setDialogState(() {
                            dialogErrorMessage = 'Kullanıcı bilgisi bulunamadı. Lütfen tekrar giriş yapınız.';
                            isVerifyingCodeLocal = false;
                          });
                          return;
                        }
                        
                        _logger.i('Aktivasyon kodu doğrulanıyor: $code, userId: $userId');
                        
                        final response = await _authService.checkVerificationCode(
                          code,
                          userId.toString(),
                        );
                        
                        if (response.success) {
                          // Doğrulama başarılı, profil bilgilerini güncelle
                          context.read<ProfileViewModel>().loadUserProfile();
                          
                          Navigator.of(dialogContext).pop();
                          activationCodeController.clear();
                          
                          _showSuccessDialog('Hesabınız başarıyla doğrulandı! Artık tüm özellikleri kullanabilirsiniz.');
                        } else {
                          _logger.w('Aktivasyon kodu doğrulama başarısız: ${response.message}');
                          setDialogState(() {
                            dialogErrorMessage = response.userFriendlyMessage ?? 
                                response.message ?? 
                                'Doğrulama kodu geçersiz veya süresi dolmuş. Lütfen tekrar deneyiniz.';
                            isVerifyingCodeLocal = false;
                          });
                        }
                      } catch (e) {
                        _logger.e('Hesap doğrulama sırasında hata: $e');
                        setDialogState(() {
                          dialogErrorMessage = 'Doğrulama sırasında bir hata oluştu. Lütfen daha sonra tekrar deneyiniz.';
                          isVerifyingCodeLocal = false;
                        });
                      }
                    },
            ),
          ],
        ),
      ),
    ).then((_) {
      // Dialog kapandığında kaynakları temizle
      activationCodeController.dispose();
    });
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
          
          // Hesap aktivasyon uyarısı ve doğrulama kodu girişi için modal dialog kullanılacak
          // Artık buraya bir bölüm eklemiyoruz, bunun yerine profil başlığında göstereceğiz
          
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
              _buildListItem(
                context, 
                'Şifre', 
                '********', 
                onTap: () => _navigateToChangePasswordView(),
                isLink: false
              ),
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
              _buildListItem(
                context, 
                'SSS', 
                'İncele',
                onTap: _openFAQ,
                isLink: true
              ),
              _buildListItem(
                context, 
                'İletişim', 
                'İncele',
                onTap: _openContact,
                isLink: true
              ),
              _buildListItem(
                context, 
                'Üyelik Sözleşmesi', 
                'İncele',
                onTap: _openMembershipAgreement,
                isLink: true
              ),
              _buildListItem(
                context, 
                'Gizlilik Politikası', 
                'İncele',
                onTap: _openPrivacyPolicy,
                isLink: true
              ),
              _buildListItem(
                context, 
                'KVKK Aydınlatma', 
                'İncele',
                onTap: _openKVKKTerms,
                isLink: true
              ),
              _buildListItem(
                context, 
                'Kullanım Şartları', 
                'İncele',
                onTap: _openTermsOfUse,
                isLink: true
              ),
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
      case "Erkek": return "Erkek";
      case "Kadın": return "Kadın";
      default: return "Belirtilmemiş";
    }
  }
  
  Widget _buildProfileHeader(BuildContext context, User? user) {
    String profileImageUrl = user?.profilePhoto ?? '';
    bool hasProfileImage = profileImageUrl.isNotEmpty && profileImageUrl != 'null';
    bool isNotActivated = user != null && user.userStatus == 'not_activated';
    
    return Column(
      children: [
        // Profil fotoğrafı ve kullanıcı adı
        Center(
          child: Column(
            children: [
              // Profil fotoğrafı
              Stack(
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
                  
                  // Aktivasyon durumu rozeti
                  if (isNotActivated)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: GestureDetector(
                        onTap: () => _showActivationDialog(context),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: platformThemeData(
                              context,
                              material: (data) => Colors.orange,
                              cupertino: (data) => CupertinoColors.systemOrange,
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: platformThemeData(
                                context,
                                material: (data) => Colors.white,
                                cupertino: (data) => CupertinoColors.white,
                              ),
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            isCupertino(context) 
                                ? CupertinoIcons.exclamationmark 
                                : Icons.priority_high,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              
              // Kullanıcı adı
              const SizedBox(height: 12),
              Text(
                user?.userFullname ?? 'Yükleniyor...',
                style: platformThemeData(
                  context,
                  material: (data) => data.textTheme.headlineSmall,
                  cupertino: (data) => data.textTheme.navLargeTitleTextStyle.copyWith(fontSize: 24),
                ),
              ),
              
              // Aktivasyon durumu mesajı
              if (isNotActivated)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: GestureDetector(
                    onTap: () => _showActivationDialog(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: platformThemeData(
                          context,
                          material: (data) => Colors.orange.shade100,
                          cupertino: (data) => CupertinoColors.systemOrange.withOpacity(0.2),
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isCupertino(context) 
                                ? CupertinoIcons.exclamationmark_triangle 
                                : Icons.warning_amber_rounded,
                            color: platformThemeData(
                              context,
                              material: (data) => Colors.orange.shade800,
                              cupertino: (data) => CupertinoColors.systemOrange,
                            ),
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Hesabı Doğrula',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: platformThemeData(
                                context,
                                material: (data) => Colors.orange.shade800,
                                cupertino: (data) => CupertinoColors.systemOrange,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
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

  // Başarı mesajı diyalog olarak göster
  void _showSuccessDialog(String message) {
    showPlatformDialog(
      context: context,
      builder: (dialogContext) => PlatformAlertDialog(
        title: const Text('Başarılı'),
        content: Text(message),
        actions: <Widget>[
          PlatformDialogAction(
            child: const Text('Tamam'),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.of(context).pop(); // Ana sayfaya dön
            },
          ),
        ],
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
  final ImagePicker _imagePicker = ImagePicker();
  
  late TextEditingController _fullNameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _birthdayController;
  
  String _selectedGender = "0"; // String tipine değiştirildi
  bool _isLoading = false;
  bool _isLoadingImage = false;
  String _errorMessage = '';
  String? _profileImageBase64;
  
  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(text: widget.user.userFullname);
    _emailController = TextEditingController(text: widget.user.userEmail);
    _phoneController = TextEditingController(text: widget.user.userPhone);
    _birthdayController = TextEditingController(text: widget.user.userBirthday);
    
    // Cinsiyet değerini String olarak ayarla
    // Eğer userGender sayı değilse veya boşsa "0" olarak ayarla
    try {
      _selectedGender = widget.user.userGender.isNotEmpty ? widget.user.userGender : "0";
      // Geçerli bir sayı olup olmadığını kontrol et
      int.parse(_selectedGender);
    } catch (e) {
      _logger.e('Cinsiyet verisi geçersiz: ${widget.user.userGender}', e);
      _selectedGender = "0";
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
  
  // Profil fotoğrafı seçme
  Future<void> _pickProfileImage() async {
    try {
      final XFile? pickedImage = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      
      if (pickedImage == null) return;
      
      setState(() {
        _isLoadingImage = true;
      });
      
      // Resmi kırp
      final croppedFile = await _cropImage(File(pickedImage.path));
      if (croppedFile == null) {
        setState(() {
          _isLoadingImage = false;
        });
        return;
      }
      
      // Dosyayı base64'e dönüştür
      final bytes = await croppedFile.readAsBytes();
      final base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      
      setState(() {
        _profileImageBase64 = base64Image;
        _isLoadingImage = false;
      });
      
    } catch (e) {
      _logger.e('Profil fotoğrafı seçilirken hata: $e');
      setState(() {
        _isLoadingImage = false;
      });
      _showErrorMessage('Görsel seçilirken bir hata oluştu: ${e.toString()}');
    }
  }
  
  // Resmi kırpma
  Future<File?> _cropImage(File imageFile) async {
    try {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: imageFile.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        compressQuality: 70,
        compressFormat: ImageCompressFormat.jpg,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Profil Fotoğrafını Düzenle',
            toolbarColor: Colors.blue,
            toolbarWidgetColor: Colors.white,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: 'Profil Fotoğrafını Düzenle',
            aspectRatioLockEnabled: true,
          ),
        ],
      );
      
      return croppedFile != null ? File(croppedFile.path) : null;
    } catch (e) {
      _logger.e('Resim kırpılırken hata: $e');
      return null;
    }
  }
  
  // Hata mesajı göster
  void _showErrorMessage(String message) {
    showPlatformDialog(
      context: context,
      builder: (context) => PlatformAlertDialog(
        title: const Text('Hata'),
        content: Text(message),
        actions: <Widget>[
          PlatformDialogAction(
            child: const Text('Tamam'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
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
      // Gender değerini güvenli bir şekilde dönüştür
      int userGender;
      try {
        userGender = int.parse(_selectedGender);
      } catch (e) {
        _logger.e('Gender dönüştürme hatası: $_selectedGender', e);
        userGender = 0; // Varsayılan değer
      }
      
      // Tarih formatını kontrol et
      String birthday = _birthdayController.text.trim();
      if (birthday.isNotEmpty && !RegExp(r'^\d{2}\.\d{2}\.\d{4}$').hasMatch(birthday)) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Doğum tarihi GG.AA.YYYY formatında olmalıdır';
        });
        return;
      }
      
      // Profil güncelleme işlemini çağır
      await context.read<ProfileViewModel>().updateUserProfile(
        userFullname: _fullNameController.text.trim(),
        userEmail: _emailController.text.trim(),
        userBirthday: birthday,
        userPhone: _phoneController.text.trim(),
        userGender: userGender,
        profilePhoto: _profileImageBase64 ?? widget.user.profilePhoto,
      );
      
      if (mounted) {
        final viewModel = context.read<ProfileViewModel>();
        if (viewModel.status == ProfileStatus.updateSuccess) {
          // Başarı mesajını göster
        } else {
          setState(() {
            _errorMessage = viewModel.errorMessage.isNotEmpty 
                ? viewModel.errorMessage 
                : 'Profil güncellenirken bir hata oluştu. Lütfen tekrar deneyiniz.';
          });
        }
      }
    } catch (e, stackTrace) {
      _logger.e('Profil güncellenirken hata: $e', null, stackTrace);
      setState(() {
        _errorMessage = 'Profil güncellenirken bir hata oluştu: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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
              // Profil fotoğrafı seçme alanı
              _buildProfilePhotoSelector(),
              
              const SizedBox(height: 24),
              
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
  
  // Profil fotoğrafı seçme alanı
  Widget _buildProfilePhotoSelector() {
    String profileImageUrl = widget.user.profilePhoto;
    bool hasImage = (profileImageUrl.isNotEmpty && profileImageUrl != 'null') || _profileImageBase64 != null;
    
    return Center(
      child: GestureDetector(
        onTap: _isLoadingImage ? null : _pickProfileImage,
        child: Stack(
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: !hasImage
                  ? platformThemeData(
                      context,
                      material: (data) => Colors.blue.shade100,
                      cupertino: (data) => CupertinoColors.activeBlue.withOpacity(0.2),
                    )
                  : null,
                shape: BoxShape.circle,
                image: hasImage
                  ? _profileImageBase64 != null
                    ? DecorationImage(
                        image: MemoryImage(
                          base64Decode(_profileImageBase64!.replaceFirst('data:image/jpeg;base64,', '')),
                        ),
                        fit: BoxFit.cover,
                      )
                    : DecorationImage(
                        image: NetworkImage(profileImageUrl),
                        fit: BoxFit.cover,
                      )
                  : null,
              ),
              child: _isLoadingImage
                ? Center(child: PlatformCircularProgressIndicator())
                : (!hasImage
                  ? Center(
                      child: Icon(
                        context.platformIcons.person,
                        size: 60,
                        color: platformThemeData(
                          context,
                          material: (data) => Colors.blue,
                          cupertino: (data) => CupertinoColors.activeBlue,
                        ),
                      ),
                    )
                  : null),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: platformThemeData(
                    context,
                    material: (data) => Colors.blue,
                    cupertino: (data) => CupertinoColors.activeBlue,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: platformThemeData(
                      context,
                      material: (data) => Colors.white,
                      cupertino: (data) => CupertinoColors.white,
                    ),
                    width: 2,
                  ),
                ),
                child: Icon(
                  isCupertino(context) ? CupertinoIcons.camera : Icons.camera_alt,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ],
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
              _buildGenderOption(context, 'Belirtilmemiş', '0'),
              const Divider(height: 1),
              _buildGenderOption(context, 'Erkek', '1'),
              const Divider(height: 1),
              _buildGenderOption(context, 'Kadın', '2'),
            ],
          ),
        ),
      ],
    );
  }
  
  // Cinsiyet seçim opsiyonu
  Widget _buildGenderOption(BuildContext context, String label, String value) { // value parametresi String tipine değiştirildi
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
              Radio<String>( // Radio tipi String olarak değiştirildi
                value: value,
                groupValue: _selectedGender,
                onChanged: (String? newValue) {
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

// Şifre Değiştirme Ekranı
class ChangePasswordView extends StatefulWidget {
  const ChangePasswordView({Key? key}) : super(key: key);

  @override
  _ChangePasswordViewState createState() => _ChangePasswordViewState();
}

class _ChangePasswordViewState extends State<ChangePasswordView> {
  final LoggerService _logger = LoggerService();
  final _formKey = GlobalKey<FormState>();
  
  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  
  bool _isLoading = false;
  String _errorMessage = '';
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  
  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
  
  // Şifre değiştirme işlemi
  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      await context.read<ProfileViewModel>().updatePassword(
        currentPassword: _currentPasswordController.text,
        password: _newPasswordController.text,
        passwordAgain: _confirmPasswordController.text,
      );
      
      if (mounted) {
        final viewModel = context.read<ProfileViewModel>();
        if (viewModel.status == ProfileStatus.passwordChanged) {
          // Başarı mesajını göster
          _showSuccessDialog('Şifreniz başarıyla güncellendi');
        } else {
          setState(() {
            _errorMessage = _formatErrorMessage(viewModel.errorMessage);
          });
        }
      }
    } catch (e) {
      _logger.e('Şifre güncellenirken hata: $e');
      setState(() {
        _errorMessage = _formatErrorMessage(e.toString());
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  // Başarı mesajı diyalog olarak göster
  void _showSuccessDialog(String message) {
    showPlatformDialog(
      context: context,
      builder: (dialogContext) => PlatformAlertDialog(
        title: const Text('Başarılı'),
        content: Text(message),
        actions: <Widget>[
          PlatformDialogAction(
            child: const Text('Tamam'),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.of(context).pop(); // Ana sayfaya dön
            },
          ),
        ],
      ),
    );
  }
  
  // API hata mesajını formatla ve kullanıcı dostu hale getir
  String _formatErrorMessage(String error) {
    // API'nin döndürdüğü özel hata mesajlarını kontrol et
    if (error.contains('en az 8 karakter') || 
        error.contains('en az 1 sayı') || 
        error.contains('en az 1 harf')) {
      return error;
    }
    
    // Mevcut şifre hatası
    if (error.contains('Mevcut şifreniz hatalı') || 
        error.contains('current password') || 
        error.contains('incorrect password')) {
      return 'Mevcut şifreniz hatalı. Lütfen kontrol ediniz.';
    }
    
    // Şifre eşleşmeme hatası
    if (error.contains('Şifreler eşleşmiyor') || 
        error.contains('passwordAgain') || 
        error.contains('passwords do not match')) {
      return 'Girdiğiniz yeni şifreler birbiriyle eşleşmiyor.';
    }
    
    // Genel hata
    return 'Şifre değiştirme işlemi sırasında bir hata oluştu. Lütfen tekrar deneyiniz.';
  }
  
  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: const Text('Şifre Değiştir'),
        material: (_, __) => MaterialAppBarData(
          actions: <Widget>[
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _isLoading ? null : _updatePassword,
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
              onPressed: _updatePassword,
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
              
              _buildPasswordField(
                context: context,
                controller: _currentPasswordController,
                label: 'Mevcut Şifre',
                obscureText: _obscureCurrentPassword,
                onToggleVisibility: () {
                  setState(() {
                    _obscureCurrentPassword = !_obscureCurrentPassword;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Mevcut şifrenizi girmelisiniz';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              _buildPasswordField(
                context: context,
                controller: _newPasswordController,
                label: 'Yeni Şifre',
                obscureText: _obscureNewPassword,
                onToggleVisibility: () {
                  setState(() {
                    _obscureNewPassword = !_obscureNewPassword;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Yeni şifrenizi girmelisiniz';
                  }
                  if (value.length < 8) {
                    return 'Şifre en az 8 karakter olmalıdır';
                  }
                  if (!RegExp(r'[0-9]').hasMatch(value)) {
                    return 'Şifre en az 1 rakam içermelidir';
                  }
                  if (!RegExp(r'[a-zA-Z]').hasMatch(value)) {
                    return 'Şifre en az 1 harf içermelidir';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              _buildPasswordField(
                context: context,
                controller: _confirmPasswordController,
                label: 'Yeni Şifre (Tekrar)',
                obscureText: _obscureConfirmPassword,
                onToggleVisibility: () {
                  setState(() {
                    _obscureConfirmPassword = !_obscureConfirmPassword;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Şifrenizi tekrar girmelisiniz';
                  }
                  if (value != _newPasswordController.text) {
                    return 'Şifreler eşleşmiyor';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 32),
              
              if (_isLoading)
                Center(child: PlatformCircularProgressIndicator())
              else
                PlatformElevatedButton(
                  onPressed: _updatePassword,
                  child: const Text('Şifreyi Güncelle'),
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
  
  // Şifre alanı widget'ı
  Widget _buildPasswordField({
    required BuildContext context,
    required TextEditingController controller,
    required String label,
    required bool obscureText,
    required VoidCallback onToggleVisibility,
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
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: CupertinoColors.systemGrey4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: CupertinoTextField(
                        controller: controller,
                        obscureText: obscureText,
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: const BoxDecoration(
                          border: null,
                        ),
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: onToggleVisibility,
                      child: Icon(
                        obscureText ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
                        color: CupertinoColors.systemGrey,
                      ),
                    ),
                  ],
                ),
              ),
              if (validator != null)
                Builder(
                  builder: (context) {
                    final error = validator(controller.text);
                    return error != null
                        ? Padding(
                            padding: const EdgeInsets.only(left: 4, top: 4),
                            child: Text(
                              error,
                              style: const TextStyle(
                                color: CupertinoColors.systemRed,
                                fontSize: 12,
                              ),
                            ),
                          )
                        : const SizedBox.shrink();
                  },
                ),
            ],
          )
        : TextFormField(
            controller: controller,
            obscureText: obscureText,
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              suffixIcon: IconButton(
                icon: Icon(
                  obscureText ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: onToggleVisibility,
              ),
            ),
            validator: validator,
          );
  }
} 