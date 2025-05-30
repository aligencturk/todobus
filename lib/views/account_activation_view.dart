import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'dart:async';
import 'dart:math' as math;
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../services/logger_service.dart';

class AccountActivationView extends StatefulWidget {
  const AccountActivationView({Key? key}) : super(key: key);

  @override
  _AccountActivationViewState createState() => _AccountActivationViewState();
}

class _AccountActivationViewState extends State<AccountActivationView> 
    with TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final StorageService _storageService = StorageService();
  final LoggerService _logger = LoggerService();
  final TextEditingController _activationCodeController = TextEditingController();
  
  bool _isVerifyingCode = false;
  bool _isSendingCodeAgain = false;
  String _errorMessage = '';
  
  // Kod gönderme zamanlayıcısı için değişkenler
  Timer? _resendTimer;
  int _resendCountdown = 0;
  int _totalResendTime = 180; // Toplam süre
  bool _canResendCode = true;
  
  // Animation controller for timer
  late AnimationController _timerAnimationController;
  late Animation<double> _timerAnimation;
  
  @override
  void initState() {
    super.initState();
    _timerAnimationController = AnimationController(
      duration: const Duration(seconds: 180), // Varsayılan süre
      vsync: this,
    );
    _timerAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _timerAnimationController,
      curve: Curves.linear, // Linear curve, düzgün ilerleme için
    ));
  }
  
  @override
  void dispose() {
    _resendTimer?.cancel();
    _timerAnimationController.dispose();
    _activationCodeController.dispose();
    super.dispose();
  }
  
  // Hesap aktivasyon kodu doğrulama
  Future<void> _verifyActivationCode() async {
    final code = _activationCodeController.text.trim();
    
    if (code.isEmpty) {
      setState(() {
        _errorMessage = 'Lütfen doğrulama kodunu giriniz.';
      });
      return;
    }
    
    // Sadece sayısal değer mi kontrol et
    if (!RegExp(r'^\d+$').hasMatch(code)) {
      setState(() {
        _errorMessage = 'Doğrulama kodu sadece rakamlardan oluşmalıdır.';
      });
      return;
    }
    
    setState(() {
      _isVerifyingCode = true;
      _errorMessage = '';
    });
    
    try {
      // StorageService'den gerçek user token'ı alıyoruz
      final userToken = _storageService.getToken();
      
      if (userToken == null || userToken.isEmpty) {
        setState(() {
          _errorMessage = 'Kullanıcı token bilgisi bulunamadı. Lütfen tekrar giriş yapınız.';
          _isVerifyingCode = false;
        });
        return;
      }
      
      _logger.i('Aktivasyon kodu doğrulanıyor: $code');
      
      final response = await _authService.checkVerificationCode(
        code,
        userToken,
      );
      
      if (response.success) {
        _logger.i('Hesap aktivasyonu başarılı');
        _showSuccessDialog('Hesabınız başarıyla doğrulandı! Artık tüm özellikleri kullanabilirsiniz.');
      } else {
        _logger.w('Aktivasyon kodu doğrulama başarısız: ${response.message}');
        setState(() {
          _errorMessage = response.userFriendlyMessage ?? 
              response.message ?? 
              'Doğrulama kodu geçersiz veya süresi dolmuş. Lütfen tekrar deneyiniz.';
        });
      }
    } catch (e) {
      _logger.e('Hesap doğrulama sırasında hata: $e');
      setState(() {
        _errorMessage = 'Doğrulama sırasında bir hata oluştu. Lütfen daha sonra tekrar deneyiniz.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isVerifyingCode = false;
        });
      }
    }
  }
  
  // Yeni doğrulama kodu gönder
  Future<void> _resendActivationCode() async {
    setState(() {
      _isSendingCodeAgain = true;
      _errorMessage = '';
    });
    
    try {
      // StorageService'den gerçek user token'ı alıyoruz
      final userToken = _storageService.getToken();
      
      if (userToken == null || userToken.isEmpty) {
        setState(() {
          _errorMessage = 'Kullanıcı token bilgisi bulunamadı. Lütfen tekrar giriş yapınız.';
          _isSendingCodeAgain = false;
        });
        return;
      }
      
      _logger.i('Yeni aktivasyon kodu isteniyor');
      
      final response = await _authService.againSendCode(
        userToken,
      );
      
      if (response.success) {
        _logger.i('Yeni aktivasyon kodu başarıyla gönderildi');
        setState(() {
          _errorMessage = '';
          _isSendingCodeAgain = false;
        });
        
        // Kod gönderme başarılı olduğunda timer başlat
        _startResendCountdown(180);
        
        // Başarı mesajını göster (sadece Scaffold mevcutsa)
        if (mounted && context.findAncestorWidgetOfExactType<Scaffold>() != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Yeni doğrulama kodu e-posta adresinize gönderildi.'),
              backgroundColor: platformThemeData(
                context,
                material: (data) => Colors.green,
                cupertino: (data) => CupertinoColors.activeGreen,
              ),
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        _logger.w('Yeni aktivasyon kodu gönderme başarısız: ${response.message}');
        
        // API'dan dönen asıl mesajı kullan (message field'ı)
        final apiMessage = response.message ?? '';
        _logger.d('Original API error message: $apiMessage');
        
        // API mesajından wait time'ı direkt çıkarmayı dene
        final waitTime = _extractWaitTimeFromError(apiMessage);
        
        // API'den gelen wait time'ı kullan, yoksa default 180 saniye
        final timerDuration = waitTime > 0 ? waitTime : 180;
        _logger.d('Starting timer with duration: $timerDuration seconds');
        _startResendCountdown(timerDuration);
        
        // Kullanıcıya gösterilecek mesaj, API'nın orijinal mesajını kullan
        setState(() {
          _errorMessage = apiMessage.isNotEmpty 
              ? apiMessage 
              : 'Yeni doğrulama kodu gönderilirken bir hata oluştu. Lütfen daha sonra tekrar deneyiniz.';
          _isSendingCodeAgain = false;
        });
      }
    } catch (e) {
      _logger.e('Yeni kod gönderme sırasında hata: $e');
      
      // Eğer exception mesajında saniye bilgisi varsa (API hatası wrapper olmuş)
      final errorString = e.toString();
      int waitTime = _extractWaitTimeFromError(errorString);
      
      // Wait time bulunamadı ise 180 saniye default değeri kullan
      if (waitTime <= 0) {
        waitTime = 180;
      }
      
      _logger.d('Exception içinden çıkarılan wait time: $waitTime saniye');
      _startResendCountdown(waitTime);
      
      setState(() {
        // Exception içinde API mesajı varsa kullan, yoksa generic mesaj göster
        _errorMessage = (errorString.contains('lütfen') && errorString.contains('saniye')) 
            ? errorString.replaceAll('Exception: ', '') 
            : 'Lütfen daha sonra tekrar deneyiniz.';
        _isSendingCodeAgain = false;
      });
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
              Navigator.of(context).pop(true); // true döndürerek başarılı olduğunu belirt
            },
          ),
        ],
      ),
    );
  }
  
  // Hata mesajından bekleme süresini çıkaran fonksiyon
  int _extractWaitTimeFromError(String errorMessage) {
    // "X saniye bekleyin" formatındaki mesajdan süreyi çıkar
    _logger.d('Parsing error message: $errorMessage');
    
    // Farklı formatları dene
    final patterns = [
      r'(\d+)\s*saniye\s*bekleyin',           // "151 saniye bekleyin"
      r'(\d+)\s*saniye\s*bekle',              // "151 saniye bekle"
      r'lütfen\s*(\d+)\s*saniye\s*bekleyin',  // "lütfen 151 saniye bekleyin"
      r'lütfen\s*(\d+)\s*saniye\s*bekle',     // "lütfen 151 saniye bekle"
      r'(\d+)\s*saniye\s*sonra',              // "151 saniye sonra"
      r'(\d+)\s*sn\s*bekleyin',               // "151 sn bekleyin"
      r'(\d+)\s*sn\s*bekle',                  // "151 sn bekle"
      r'(\d+)\s*sn\s*sonra',                  // "151 sn sonra"
      r'(\d+)\s*saniye',                      // Sadece "151 saniye"
      r'(\d+)\s*sn',                          // Sadece "151 sn"
    ];
    
    for (final pattern in patterns) {
      final regex = RegExp(pattern, caseSensitive: false);
      final match = regex.firstMatch(errorMessage);
      if (match != null) {
        final waitTime = int.tryParse(match.group(1) ?? '0') ?? 0;
        _logger.d('Extracted wait time: $waitTime seconds using pattern: $pattern');
        return waitTime;
      }
    }
    
    _logger.d('No wait time found in error message');
    return 0;
  }
  
  // Geri sayım zamanlayıcısını başlatan fonksiyon
  void _startResendCountdown(int seconds) {
    _logger.d('Geri sayım başlatılıyor: $seconds saniye');
    
    setState(() {
      _resendCountdown = seconds;
      _totalResendTime = seconds;
      _canResendCode = false;
    });
    
    // Animasyon kontrolörünü ayarla
    _timerAnimationController.reset();
    
    // Animasyonu başlat (repeat yerine forward kullanarak tek döngüde çalıştır)
    if (seconds > 0) {
      _timerAnimationController.duration = Duration(seconds: seconds);
      _timerAnimationController.forward(from: 0);
    }
    
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      setState(() {
        if (_resendCountdown > 0) {
          _resendCountdown--;
        } else {
          _canResendCode = true;
          _timerAnimationController.stop();
          timer.cancel();
        }
      });
    });
  }
  
  // Zamanlayıcı iptal fonksiyonu
  void _cancelResendTimer() {
    _resendTimer?.cancel();
    _timerAnimationController.stop();
    setState(() {
      _resendCountdown = 0;
      _canResendCode = true;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: const Text('Hesap Aktivasyonu'),
        material: (_, __) => MaterialAppBarData(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        cupertino: (_, __) => CupertinoNavigationBarData(
          transitionBetweenRoutes: false,
          leading: CupertinoButton(
            padding: EdgeInsets.zero,
            child: const Icon(CupertinoIcons.back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Premium Timer Widget - Apple Style (En Üstte)
                if (!_canResendCode || _isSendingCodeAgain)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 32),
                      child: _AppleStyleTimerWidget(
                        currentTime: _resendCountdown,
                        totalTime: _totalResendTime,
                        animation: _timerAnimation,
                        isActive: !_canResendCode,
                        isSending: _isSendingCodeAgain,
                      ),
                    ),
                  ),
                
                // Başlık ve açıklama
                Icon(
                  isCupertino(context) 
                      ? CupertinoIcons.mail 
                      : Icons.email_outlined,
                  size: 64,
                  color: platformThemeData(
                    context,
                    material: (data) => Colors.blue,
                    cupertino: (data) => CupertinoColors.activeBlue,
                  ),
                ),
                
                const SizedBox(height: 24),
                
                Text(
                  'E-postanızı Doğrulayın',
                  style: platformThemeData(
                    context,
                    material: (data) => data.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    cupertino: (data) => data.textTheme.navLargeTitleTextStyle.copyWith(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 16),
                
                Text(
                  'E-posta adresinize gönderilen 6 haneli doğrulama kodunu girerek hesabınızı aktifleştirebilirsiniz.',
                  style: platformThemeData(
                    context,
                    material: (data) => data.textTheme.bodyLarge?.copyWith(
                      color: Colors.grey[600],
                    ),
                    cupertino: (data) => data.textTheme.textStyle.copyWith(
                      color: CupertinoColors.secondaryLabel,
                    ),
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 32),
                
                // Doğrulama kodu giriş alanı
                isCupertino(context)
                    ? CupertinoTextField(
                        controller: _activationCodeController,
                        placeholder: 'Doğrulama kodu',
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                        decoration: BoxDecoration(
                          color: CupertinoColors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: CupertinoColors.systemGrey4),
                        ),
                      )
                    : TextField(
                        controller: _activationCodeController,
                        decoration: InputDecoration(
                          labelText: 'Doğrulama kodu',
                          hintText: '123456',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                        ),
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4,
                        ),
                      ),
                
                if (_errorMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
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
                            material: (data) => Colors.red.shade700,
                            cupertino: (data) => CupertinoColors.systemRed,
                          ),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                
                const SizedBox(height: 32),
                
                // Doğrula butonu
                PlatformElevatedButton(
                  onPressed: _isVerifyingCode ? null : _verifyActivationCode,
                  child: _isVerifyingCode
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: PlatformCircularProgressIndicator(),
                            ),
                            const SizedBox(width: 12),
                            const Text('Doğrulanıyor...'),
                          ],
                        )
                      : const Text('Hesabı Doğrula'),
                  material: (_, __) => MaterialElevatedButtonData(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  cupertino: (_, __) => CupertinoElevatedButtonData(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Apple Style Tekrar Kod Gönder Butonu (Sadece timer bittiğinde)
                if (_canResendCode && !_isSendingCodeAgain)
                  Center(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _resendActivationCode,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          decoration: BoxDecoration(
                            color: isCupertino(context) 
                                ? CupertinoColors.systemBackground.withOpacity(0.8)
                                : Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isCupertino(context)
                                  ? CupertinoColors.systemGrey4
                                  : Colors.grey.shade300,
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isCupertino(context) 
                                    ? CupertinoIcons.refresh_circled
                                    : Icons.refresh,
                                color: isCupertino(context)
                                    ? CupertinoColors.activeBlue
                                    : Colors.blue.shade600,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Tekrar Kod Gönder',
                                style: TextStyle(
                                  color: isCupertino(context)
                                      ? CupertinoColors.activeBlue
                                      : Colors.blue.shade600,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                
                // Minimum yükseklik için spacing
                SizedBox(height: MediaQuery.of(context).size.height * 0.1),
                
                // Alt bilgi
                Text(
                  'Kod gelmedi mi? E-posta spam klasörünüzü kontrol etmeyi unutmayın.',
                  style: platformThemeData(
                    context,
                    material: (data) => data.textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                    cupertino: (data) => data.textTheme.textStyle.copyWith(
                      fontSize: 12,
                      color: CupertinoColors.secondaryLabel,
                    ),
                  ),
                  textAlign: TextAlign.center,
                ),
                
                // Bottom padding
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Apple Style Timer Widget
class _AppleStyleTimerWidget extends StatelessWidget {
  final int currentTime;
  final int totalTime;
  final Animation<double> animation;
  final bool isActive;
  final bool isSending;

  const _AppleStyleTimerWidget({
    required this.currentTime,
    required this.totalTime,
    required this.animation,
    required this.isActive,
    required this.isSending,
  });

  @override
  Widget build(BuildContext context) {
    // Kalan süreyi toplam süreye bölerek progress değerini hesaplıyoruz
    // Ters hesaplama yapıyoruz - 1.0'dan başlayıp 0.0'a doğru ilerleyecek
    final progress = totalTime > 0 ? currentTime / totalTime : 0.0;
    
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isCupertino(context) 
                ? CupertinoColors.systemBackground.withOpacity(0.95)
                : Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isCupertino(context)
                  ? CupertinoColors.systemGrey5
                  : Colors.grey.shade200,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 20,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Circular Timer
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCupertino(context)
                      ? CupertinoColors.systemGrey6
                      : Colors.grey.shade100,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Background Circle
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCupertino(context)
                            ? CupertinoColors.systemBackground
                            : Colors.white,
                      ),
                    ),
                    
                    // Progress Ring
                    if (isActive && !isSending)
                      SizedBox(
                        width: 100,
                        height: 100,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 6,
                          backgroundColor: isCupertino(context)
                              ? CupertinoColors.systemGrey4
                              : Colors.grey.shade300,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isCupertino(context)
                                ? CupertinoColors.activeBlue
                                : Colors.blue.shade500,
                          ),
                        ),
                      ),
                    
                    // Sending Animation
                    if (isSending)
                      SizedBox(
                        width: 100,
                        height: 100,
                        child: CircularProgressIndicator(
                          strokeWidth: 6,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isCupertino(context)
                                ? CupertinoColors.activeOrange
                                : Colors.orange.shade500,
                          ),
                        ),
                      ),
                    
                    // Content
                    if (isSending) ...[
                      Icon(
                        isCupertino(context) 
                            ? CupertinoIcons.paperplane 
                            : Icons.send,
                        color: isCupertino(context)
                            ? CupertinoColors.activeOrange
                            : Colors.orange.shade600,
                        size: 24,
                      ),
                    ] else if (isActive) ...[
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$currentTime',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w300,
                              color: isCupertino(context)
                                  ? CupertinoColors.label
                                  : Colors.grey.shade800,
                            ),
                          ),
                          Text(
                            'saniye',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: isCupertino(context)
                                  ? CupertinoColors.secondaryLabel
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Status Text
              Text(
                isSending 
                    ? 'Kod Gönderiliyor...'
                    : isActive 
                        ? 'Yeni kod için bekleyin'
                        : 'Hazır',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isSending
                      ? (isCupertino(context)
                          ? CupertinoColors.activeOrange
                          : Colors.orange.shade600)
                      : (isCupertino(context)
                          ? CupertinoColors.secondaryLabel
                          : Colors.grey.shade700),
                ),
                textAlign: TextAlign.center,
              ),
              
              if (isActive && !isSending && currentTime > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${currentTime} saniye sonra',
                    style: TextStyle(
                      fontSize: 12,
                      color: isCupertino(context)
                          ? CupertinoColors.tertiaryLabel
                          : Colors.grey.shade500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
} 