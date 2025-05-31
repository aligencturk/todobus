import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'dart:async';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../services/logger_service.dart';

class AccountActivationView extends StatefulWidget {
  const AccountActivationView({super.key});

  @override
  State<AccountActivationView> createState() => _AccountActivationViewState();
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
  
  Timer? _resendTimer;
  int _resendCountdown = 0;
  bool _canResendCode = true;
  String? _currentCodeToken; // Yeni kod gönderildikten sonra kullanılacak codeToken
  
  // Animation controller for circular timer
  late AnimationController _timerAnimationController;
  late Animation<double> _timerAnimation;
  
  @override
  void initState() {
    super.initState();
    _timerAnimationController = AnimationController(
      duration: const Duration(seconds: 180),
      vsync: this,
    );
    _timerAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _timerAnimationController,
      curve: Curves.linear,
    ));
    
    // Sayfa açıldığında otomatik olarak doğrulama kodu gönder
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sendInitialActivationCode();
    });
  }
  
  @override
  void dispose() {
    _resendTimer?.cancel();
    _timerAnimationController.dispose();
    _activationCodeController.dispose();
    super.dispose();
  }
  
  Future<void> _verifyActivationCode() async {
    final code = _activationCodeController.text.trim();
    
    if (code.isEmpty) {
      setState(() {
        _errorMessage = 'Lütfen doğrulama kodunu giriniz.';
      });
      return;
    }
    
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
      // Debug: currentCodeToken durumu
      _logger.d('_verifyActivationCode çağrıldı - _currentCodeToken: $_currentCodeToken');
      
      // CodeToken olması zorunlu, yoksa hata ver
      if (_currentCodeToken == null || _currentCodeToken!.isEmpty) {
        setState(() {
          _errorMessage = 'Doğrulama kodu henüz gönderilmedi. Lütfen "Tekrar Kod Gönder" butonuna tıklayın.';
          _isVerifyingCode = false;
        });
        return;
      }
      
      _logger.i('Aktivasyon kodu doğrulanıyor: $code, codeToken: ${_currentCodeToken!.substring(0, 8)}...');
      
      final response = await _authService.checkVerificationCode(code, _currentCodeToken!);
      
      if (response.success) {
        _logger.i('Hesap aktivasyonu başarılı');
        // Başarılı doğrulama sonrası codeToken'ı temizle
        _currentCodeToken = null;
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
  
  // Sayfa açıldığında otomatik olarak doğrulama kodu gönder
  Future<void> _sendInitialActivationCode() async {
    await _resendActivationCode();
  }
  
  Future<void> _resendActivationCode() async {
    setState(() {
      _isSendingCodeAgain = true;
      _errorMessage = '';
    });
    
    try {
      final userToken = _storageService.getToken();
      
      if (userToken == null || userToken.isEmpty) {
        setState(() {
          _errorMessage = 'Kullanıcı token bilgisi bulunamadı. Lütfen tekrar giriş yapınız.';
          _isSendingCodeAgain = false;
        });
        return;
      }
      
      _logger.i('Yeni aktivasyon kodu isteniyor');
      
      final response = await _authService.againSendCode(userToken);
      
      _logger.d('againSendCode response: success=${response.success}, statusCode=${response.statusCode}, message=${response.message}');
      _logger.d('againSendCode response data: ${response.data}');
      
      // Başarı kontrolü: response.success VEYA mesajın "başarıyla gönderilmiştir" içermesi
      bool isActuallySuccessful = response.success || 
          (response.message != null && response.message!.contains('başarıyla gönderilmiştir'));
      
      if (isActuallySuccessful) {
        _logger.i('Yeni aktivasyon kodu başarıyla gönderildi');
        
        // CodeToken'ı sakla
        if (response.data?.codeToken != null) {
          _currentCodeToken = response.data!.codeToken;
          _logger.i('CodeToken güncellendi: ${_currentCodeToken!.substring(0, 8)}...');
        } else {
          _logger.w('Response başarılı ama codeToken null! Response data: ${response.data}');
        }
        
        setState(() {
          _errorMessage = '';
          _isSendingCodeAgain = false;
        });
        
        _startResendCountdown(180);
        
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
        _logger.w('Kod gönderme başarısız: ${response.message}');
        
        final apiMessage = response.message ?? '';
        final waitTime = _extractWaitTimeFromError(apiMessage);
        
        if (waitTime > 0) {
          _startResendCountdown(waitTime);
        }
        
        setState(() {
          String cleanMessage = apiMessage.replaceAll('Exception: ', '');
          _errorMessage = cleanMessage.isNotEmpty 
              ? cleanMessage 
              : 'Yeni doğrulama kodu gönderilirken bir hata oluştu.';
          _isSendingCodeAgain = false;
        });
      }
    } catch (e) {
      _logger.e('Yeni kod gönderme sırasında hata: $e');
      setState(() {
        String errorString = e.toString().replaceAll('Exception: ', '');
        _errorMessage = errorString.contains('lütfen') && errorString.contains('saniye')
            ? errorString
            : 'Lütfen daha sonra tekrar deneyiniz.';
        _isSendingCodeAgain = false;
      });
    }
  }
  
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
              Navigator.of(context).pop(true);
            },
          ),
        ],
      ),
    );
  }
  
  int _extractWaitTimeFromError(String errorMessage) {
    _logger.d('Parsing error message: $errorMessage');
    
    final patterns = [
      r'(\d+)\s*saniye\s*bekleyin',
      r'(\d+)\s*saniye\s*bekle',
      r'lütfen\s*(\d+)\s*saniye\s*bekleyin',
      r'(\d+)\s*saniye\s*sonra',
      r'(\d+)\s*sn\s*bekleyin',
      r'(\d+)\s*saniye',
    ];
    
    for (final pattern in patterns) {
      final regex = RegExp(pattern, caseSensitive: false);
      final match = regex.firstMatch(errorMessage);
      if (match != null) {
        final waitTime = int.tryParse(match.group(1) ?? '0') ?? 0;
        _logger.d('Extracted wait time: $waitTime seconds');
        return waitTime;
      }
    }
    
    return 0;
  }
  
  void _startResendCountdown(int seconds) {
    _logger.d('Geri sayım başlatılıyor: $seconds saniye');
    
    setState(() {
      _resendCountdown = seconds;
      _canResendCode = false;
    });
    
    // Animation controller'ı ayarla ve başlat
    _timerAnimationController.reset();
    _timerAnimationController.duration = Duration(seconds: seconds);
    _timerAnimationController.forward();
    
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
                // Timer Widget (Sadece aktifken göster)
                if (!_canResendCode || _isSendingCodeAgain)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 32),
                      child: _buildTimerWidget(),
                    ),
                  ),
                
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
                
                if (_canResendCode && !_isSendingCodeAgain)
                  Center(
                    child: TextButton.icon(
                      onPressed: _resendActivationCode,
                      icon: Icon(
                        isCupertino(context) 
                            ? CupertinoIcons.refresh
                            : Icons.refresh,
                      ),
                      label: const Text('Tekrar Kod Gönder'),
                    ),
                  ),
                
                if (_isSendingCodeAgain)
                  const Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Text('Kod gönderiliyor...'),
                      ],
                    ),
                  ),
                
                const SizedBox(height: 48),
                
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
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  // Apple Style Circular Timer Widget
  Widget _buildTimerWidget() {
    return AnimatedBuilder(
      animation: _timerAnimation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isCupertino(context) 
                ? CupertinoColors.systemBackground.withValues(alpha: 0.98)
                : Colors.white.withValues(alpha: 0.98),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isCupertino(context)
                  ? CupertinoColors.systemGrey5
                  : Colors.grey.shade200,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Circular Progress Indicator
              Stack(
                alignment: Alignment.center,
                children: [
                  // Background Circle
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isCupertino(context)
                          ? CupertinoColors.systemGrey6.withValues(alpha: 0.3)
                          : Colors.grey.shade100,
                    ),
                  ),
                  
                  // Progress Circle
                  SizedBox(
                    width: 130,
                    height: 130,
                    child: CircularProgressIndicator(
                      value: _timerAnimation.value,
                      strokeWidth: 8,
                      backgroundColor: isCupertino(context)
                          ? CupertinoColors.systemGrey4.withValues(alpha: 0.3)
                          : Colors.grey.shade300,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _getTimerColor(),
                      ),
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  
                  // Center Content
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Timer Icon
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _getTimerColor().withValues(alpha: 0.1),
                        ),
                        child: Icon(
                          isCupertino(context) 
                              ? CupertinoIcons.time
                              : Icons.schedule,
                          color: _getTimerColor(),
                          size: 24,
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Timer Display
                      Text(
                        _formatTime(_resendCountdown),
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w300,
                          color: isCupertino(context)
                              ? CupertinoColors.label
                              : Colors.grey.shade800,
                        ),
                      ),
                      
                      const SizedBox(height: 4),
                      
                      Text(
                        'kalan süre',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isCupertino(context)
                              ? CupertinoColors.secondaryLabel
                              : Colors.grey.shade600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // Status Text
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _getTimerColor().withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _isSendingCodeAgain 
                      ? 'Kod Gönderiliyor...'
                      : 'Yeni kod için bekleyin',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _getTimerColor(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  // Timer için renk döndüren fonksiyon
  Color _getTimerColor() {
    if (_isSendingCodeAgain) {
      return isCupertino(context)
          ? CupertinoColors.activeOrange
          : Colors.orange.shade600;
    }
    
    // Zamanın azalmasına göre renk geçişi
    final progress = _resendCountdown / 180.0;
    if (progress > 0.6) {
      return isCupertino(context)
          ? CupertinoColors.activeBlue
          : Colors.blue.shade600;
    } else if (progress > 0.3) {
      return isCupertino(context)
          ? CupertinoColors.systemOrange
          : Colors.orange.shade600;
    } else {
      return isCupertino(context)
          ? CupertinoColors.systemRed
          : Colors.red.shade600;
    }
  }
  
  // Zamanı formatlayan fonksiyon (MM:SS)
  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
} 