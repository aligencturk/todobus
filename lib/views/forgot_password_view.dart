import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../viewmodels/forgot_password_viewmodel.dart';
import '../services/snackbar_service.dart';
import 'login_view.dart';

class ForgotPasswordView extends StatefulWidget {
  const ForgotPasswordView({Key? key}) : super(key: key);

  @override
  _ForgotPasswordViewState createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends State<ForgotPasswordView> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _passwordConfirmController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _snackbarService = SnackBarService();

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ForgotPasswordViewModel(),
      child: Consumer<ForgotPasswordViewModel>(
        builder: (context, viewModel, _) {
          return Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              
              title: Text(_getScreenTitle(viewModel.status)),
              backgroundColor: Colors.transparent,
              elevation: 0,
              foregroundColor: const Color(0xFF2C3E50),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => _handleBackButton(context, viewModel),
              ),
            ),
            body: SafeArea(
              child: CustomScrollView(
                slivers: [
                  
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 40),
                            
                            // Logo
                            Center(
                              child: Image.asset(
                                'assets/icon.png', 
                                width: 120,
                                height: 120,
                              ),
                            ),
                            const SizedBox(height: 40),
                            
                            // Açıklama
                            Text(
                              _getScreenDescription(viewModel.status),
                              style: const TextStyle(
                                fontSize: 16,
                                color: Color(0xFF7F8C8D),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 40),
                            
                            // Form içeriği (duruma göre değişir)
                            _buildFormContent(viewModel),
                            
                            // Hata mesajı
                            if (viewModel.status == ForgotPasswordStatus.error)
                              Padding(
                                padding: const EdgeInsets.only(top: 16.0),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFDECED),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.error_outline,
                                        color: Color(0xFFE74C3C),
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          viewModel.errorMessage,
                                          style: const TextStyle(
                                            color: Color(0xFFE74C3C),
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            
                            const Spacer(),
                            
                            // Aksiyon butonu
                            Padding(
                              padding: const EdgeInsets.only(bottom: 20),
                              child: ElevatedButton(
                                onPressed: viewModel.status == ForgotPasswordStatus.loading
                                    ? null
                                    : () => _handlePrimaryAction(context, viewModel),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF3498DB),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  elevation: 0,
                                ),
                                child: viewModel.status == ForgotPasswordStatus.loading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        _getActionButtonText(viewModel.status),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
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
          );
        },
      ),
    );
  }

  // Ekran başlığını durum değişkenine göre ayarla
  String _getScreenTitle(ForgotPasswordStatus status) {
    switch (status) {
      case ForgotPasswordStatus.initial:
        return 'Şifremi Unuttum';
      case ForgotPasswordStatus.codeVerification:
        return 'Doğrulama Kodu';
      case ForgotPasswordStatus.resetPassword:
        return 'Yeni Şifre';
      case ForgotPasswordStatus.success:
        return 'Şifre Sıfırlandı';
      default:
        return 'Şifremi Unuttum';
    }
  }

  // Ekran açıklamasını durum değişkenine göre ayarla
  String _getScreenDescription(ForgotPasswordStatus status) {
    switch (status) {
      case ForgotPasswordStatus.initial:
        return 'Şifrenizi sıfırlamak için kayıtlı e-posta adresinizi girin.';
      case ForgotPasswordStatus.codeVerification:
        return 'E-posta adresinize gönderilen doğrulama kodunu girin.';
      case ForgotPasswordStatus.resetPassword:
        return 'Lütfen yeni şifrenizi belirleyin.';
      case ForgotPasswordStatus.success:
        return 'Şifreniz başarıyla değiştirildi. Artık yeni şifrenizle giriş yapabilirsiniz.';
      default:
        return '';
    }
  }

  // Aksiyon butonu metnini durum değişkenine göre ayarla
  String _getActionButtonText(ForgotPasswordStatus status) {
    switch (status) {
      case ForgotPasswordStatus.initial:
        return 'Doğrulama Kodu Gönder';
      case ForgotPasswordStatus.codeVerification:
        return 'Doğrula';
      case ForgotPasswordStatus.resetPassword:
        return 'Şifreyi Sıfırla';
      case ForgotPasswordStatus.success:
        return 'Giriş Yap';
      default:
        return 'Devam Et';
    }
  }

  // Form içeriğini durum değişkenine göre oluştur
  Widget _buildFormContent(ForgotPasswordViewModel viewModel) {
    switch (viewModel.status) {
      case ForgotPasswordStatus.initial:
        return _buildEmailStep();
      case ForgotPasswordStatus.codeVerification:
        return _buildCodeVerificationStep();
      case ForgotPasswordStatus.resetPassword:
        return _buildResetPasswordStep(viewModel);
      case ForgotPasswordStatus.success:
        return _buildSuccessStep();
      case ForgotPasswordStatus.loading:
        return Container();
      case ForgotPasswordStatus.error:
        // Hata durumunda mevcut adımın formunu göster
        if (viewModel.verificationToken.isNotEmpty && viewModel.passToken.isEmpty) {
          return _buildCodeVerificationStep();
        } else if (viewModel.passToken.isNotEmpty) {
          return _buildResetPasswordStep(viewModel);
        } else {
          return _buildEmailStep();
        }
      default:
        return Container();
    }
  }

  // E-posta adımı
  Widget _buildEmailStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'E-posta',
          style: TextStyle(
            color: Color(0xFF34495E),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            hintText: 'E-posta adresinizi girin',
            prefixIcon: const Icon(
              Icons.mail_outline,
              color: Color(0xFF7F8C8D),
              size: 20,
            ),
            filled: true,
            fillColor: const Color(0xFFF5F5F5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          ),
          style: const TextStyle(
            color: Color(0xFF2C3E50),
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  // Doğrulama kodu adımı
  Widget _buildCodeVerificationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Doğrulama Kodu',
          style: TextStyle(
            color: Color(0xFF34495E),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _codeController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: '6 haneli doğrulama kodunu girin',
            prefixIcon: const Icon(
              Icons.security,
              color: Color(0xFF7F8C8D),
              size: 20,
            ),
            filled: true,
            fillColor: const Color(0xFFF5F5F5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          ),
          style: const TextStyle(
            color: Color(0xFF2C3E50),
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  // Şifre sıfırlama adımı
  Widget _buildResetPasswordStep(ForgotPasswordViewModel viewModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Yeni Şifre',
          style: TextStyle(
            color: Color(0xFF34495E),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _passwordController,
          obscureText: viewModel.obscurePassword,
          decoration: InputDecoration(
            hintText: 'Yeni şifrenizi girin',
            prefixIcon: const Icon(
              Icons.lock_outline,
              color: Color(0xFF7F8C8D),
              size: 20,
            ),
            suffixIcon: IconButton(
              onPressed: () => viewModel.togglePasswordVisibility(),
              icon: Icon(
                viewModel.obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: const Color(0xFF7F8C8D),
                size: 20,
              ),
            ),
            filled: true,
            fillColor: const Color(0xFFF5F5F5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          ),
          style: const TextStyle(
            color: Color(0xFF2C3E50),
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Şifre Tekrar',
          style: TextStyle(
            color: Color(0xFF34495E),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _passwordConfirmController,
          obscureText: viewModel.obscurePasswordConfirm,
          decoration: InputDecoration(
            hintText: 'Yeni şifrenizi tekrar girin',
            prefixIcon: const Icon(
              Icons.lock_outline,
              color: Color(0xFF7F8C8D),
              size: 20,
            ),
            suffixIcon: IconButton(
              onPressed: () => viewModel.togglePasswordConfirmVisibility(),
              icon: Icon(
                viewModel.obscurePasswordConfirm
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: const Color(0xFF7F8C8D),
                size: 20,
              ),
            ),
            filled: true,
            fillColor: const Color(0xFFF5F5F5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          ),
          style: const TextStyle(
            color: Color(0xFF2C3E50),
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  // Başarı adımı
  Widget _buildSuccessStep() {
    return const Center(
      child: Column(
        children: [
          Icon(
            Icons.check_circle,
            color: Color(0xFF27AE60),
            size: 60,
          ),
          SizedBox(height: 16),
          Text(
            'Şifreniz başarıyla değiştirildi.',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF34495E),
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Geri butonuna basıldığında durum değişkenine göre işlem yap
  void _handleBackButton(BuildContext context, ForgotPasswordViewModel viewModel) {
    switch (viewModel.status) {
      case ForgotPasswordStatus.initial:
        Navigator.of(context).pop();
        break;
      case ForgotPasswordStatus.codeVerification:
        viewModel.backToInitial();
        break;
      case ForgotPasswordStatus.resetPassword:
        viewModel.backToCodeVerification();
        break;
      case ForgotPasswordStatus.success:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginView()),
        );
        break;
      default:
        Navigator.of(context).pop();
        break;
    }
  }

  // Durum değişkenine göre ileri butonuna basıldığında işlem yap
  void _handlePrimaryAction(BuildContext context, ForgotPasswordViewModel viewModel) async {
    switch (viewModel.status) {
      case ForgotPasswordStatus.initial:
        if (_emailController.text.isNotEmpty) {
          await viewModel.forgotPassword(_emailController.text.trim());
        }
        break;
        
      case ForgotPasswordStatus.codeVerification:
        if (_codeController.text.isNotEmpty) {
          await viewModel.verifyCode(_codeController.text.trim());
        }
        break;
        
      case ForgotPasswordStatus.resetPassword:
        if (_passwordController.text.isNotEmpty && _passwordConfirmController.text.isNotEmpty) {
          await viewModel.resetPassword(
            _passwordController.text,
            _passwordConfirmController.text,
          );
        }
        break;
        
      case ForgotPasswordStatus.success:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginView()),
        );
        break;
        
      default:
        break;
    }
    
    // Hata durumunda kullanıcıya Snackbar ile bildirim göster
    if (viewModel.status == ForgotPasswordStatus.error) {
      String formattedMessage = _formatErrorMessage(viewModel.errorMessage);
      _snackbarService.showError(formattedMessage);
    }
  }
  
  // Hata mesajını formatla
  String _formatErrorMessage(String errorMessage) {
    // Exception: hatası gibi prefix'leri kaldır
    if (errorMessage.startsWith('Exception: ')) {
      errorMessage = errorMessage.substring('Exception: '.length);
    }
    
    // Şifre sıfırlama hatası gibi tekrarlanan mesajları kaldır
    if (errorMessage.contains('Şifre sıfırlama isteği sırasında bir hata oluştu:')) {
      errorMessage = errorMessage.replaceAll('Şifre sıfırlama isteği sırasında bir hata oluştu:', '');
    }
    
    if (errorMessage.contains('Bir hata oluştu:')) {
      errorMessage = errorMessage.replaceAll('Bir hata oluştu:', '');
    }
    
    // HTTP kodlarını temizle
    final regExp = RegExp(r'\b\d{3}\b');
    errorMessage = errorMessage.replaceAll(regExp, '');
    
    // Teknik detayları içeren uzun hataları kısalt
    if (errorMessage.length > 120) {
      return '${errorMessage.substring(0, 120)}...';
    }
    
    return errorMessage.trim();
  }
} 