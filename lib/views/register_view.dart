import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../viewmodels/register_viewmodel.dart';
import 'login_view.dart';
import 'dart:math' as math;

// Telefon numarası formatlayıcı sınıf
class TurkeyPhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue, 
    TextEditingValue newValue
  ) {
    // Sadece rakamları alıyoruz
    String text = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    
    // Telefon numarası girilmemişse boş dön
    if (text.isEmpty) {
      return const TextEditingValue(
        text: "",
        selection: TextSelection.collapsed(offset: 0),
      );
    }
    
    // Başa 0 ekle (yoksa)
    if (!text.startsWith('0') && text.isNotEmpty) {
      text = '0$text';
    }
    
    // Telefon numarasını formatla
    String formattedText = '';
    
    // İlk basamak (0)
    if (text.length >= 1) {
      formattedText = text.substring(0, 1);
    }
    
    // Alan kodu
    if (text.length > 1) {
      formattedText += '(' + text.substring(1, math.min(4, text.length));
    }
    
    // Alan kodu sonrası kapanış parantezi
    if (text.length > 4) {
      formattedText += ') ';
    }
    
    // İlk üç rakam
    if (text.length > 4) {
      formattedText += text.substring(4, math.min(7, text.length));
    }
    
    // İkinci üç rakam (arada boşlukla)
    if (text.length > 7) {
      formattedText += ' ' + text.substring(7, math.min(9, text.length));
    }
    
    // Son iki rakam (arada boşlukla)
    if (text.length > 9) {
      formattedText += ' ' + text.substring(9, math.min(11, text.length));
    }
    
    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
    );
  }
}

// Telefon numarası input validatörü
String? validatePhoneNumber(String? value) {
  if (value == null || value.isEmpty) {
    return 'Telefon numarası gerekli';
  }
  
  // Sadece rakamları alarak kontrol et
  final digitsOnly = value.replaceAll(RegExp(r'[^0-9]'), '');
  
  if (digitsOnly.length != 11) {
    return 'Geçerli bir telefon numarası girin';
  }
  
  if (!digitsOnly.startsWith('0')) {
    return 'Telefon numarası 0 ile başlamalıdır';
  }
  
  return null;
}

class RegisterView extends StatefulWidget {
  const RegisterView({Key? key}) : super(key: key);

  @override
  _RegisterViewState createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RegisterViewModel(),
      child: Consumer<RegisterViewModel>(
        builder: (context, viewModel, _) {
          return CupertinoPageScaffold(
            backgroundColor: CupertinoColors.systemBackground,
            navigationBar: const CupertinoNavigationBar(
              middle: Text('Kayıt Ol'),
              backgroundColor: CupertinoColors.systemBackground,
              border: null,
            ),
            child: SafeArea(
              child: CustomScrollView(
                slivers: [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 20),
                          // Logo
                          Center(
                            child: Image.asset(
                              'assets/icon.png', 
                              width: 120,
                              height: 120,
                            ),
                          ),
                          const SizedBox(height: 30),
                          
                          // Form
                          Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Ad alanı
                                Text(
                                  'Ad',
                                  style: TextStyle(
                                    color: const Color(0xFF34495E),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                CupertinoTextField(
                                  controller: _firstNameController,
                                  keyboardType: TextInputType.name,
                                  placeholder: 'Adınızı girin',
                                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                                  style: const TextStyle(
                                    color: Color(0xFF2C3E50),
                                    fontSize: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF5F5F5),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  prefix: Padding(
                                    padding: const EdgeInsets.only(left: 12),
                                    child: Icon(
                                      CupertinoIcons.person,
                                      color: const Color(0xFF7F8C8D),
                                      size: 20,
                                    ),
                                  ),
                                ),
                                
                                const SizedBox(height: 16),
                                
                                // Soyad alanı
                                Text(
                                  'Soyad',
                                  style: TextStyle(
                                    color: const Color(0xFF34495E),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                CupertinoTextField(
                                  controller: _lastNameController,
                                  keyboardType: TextInputType.name,
                                  placeholder: 'Soyadınızı girin',
                                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                                  style: const TextStyle(
                                    color: Color(0xFF2C3E50),
                                    fontSize: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF5F5F5),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  prefix: Padding(
                                    padding: const EdgeInsets.only(left: 12),
                                    child: Icon(
                                      CupertinoIcons.person,
                                      color: const Color(0xFF7F8C8D),
                                      size: 20,
                                    ),
                                  ),
                                ),
                                
                                const SizedBox(height: 16),
                                
                                // E-posta alanı
                                Text(
                                  'E-posta',
                                  style: TextStyle(
                                    color: const Color(0xFF34495E),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                CupertinoTextField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  placeholder: 'E-posta adresinizi girin',
                                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                                  style: const TextStyle(
                                    color: Color(0xFF2C3E50),
                                    fontSize: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF5F5F5),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  prefix: Padding(
                                    padding: const EdgeInsets.only(left: 12),
                                    child: Icon(
                                      CupertinoIcons.mail,
                                      color: const Color(0xFF7F8C8D),
                                      size: 20,
                                    ),
                                  ),
                                ),
                                
                                const SizedBox(height: 16),
                                
                                // Telefon alanı
                                Text(
                                  'Telefon',
                                  style: TextStyle(
                                    color: const Color(0xFF34495E),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                CupertinoTextField(
                                  controller: _phoneController,
                                  keyboardType: TextInputType.phone,
                                  placeholder: '0(555) 555 55 55',
                                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                                  style: const TextStyle(
                                    color: Color(0xFF2C3E50),
                                    fontSize: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF5F5F5),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  prefix: Padding(
                                    padding: const EdgeInsets.only(left: 12),
                                    child: Icon(
                                      CupertinoIcons.phone,
                                      color: const Color(0xFF7F8C8D),
                                      size: 20,
                                    ),
                                  ),
                                  inputFormatters: [
                                    LengthLimitingTextInputFormatter(18), // Format uzunluğu kısıtlaması
                                    TurkeyPhoneFormatter(), // Özel formatımız
                                  ],
                                ),
                                
                                const SizedBox(height: 16),
                                
                                // Şifre alanı
                                Text(
                                  'Şifre',
                                  style: TextStyle(
                                    color: const Color(0xFF34495E),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                CupertinoTextField(
                                  controller: _passwordController,
                                  obscureText: viewModel.obscurePassword,
                                  placeholder: 'Şifrenizi girin',
                                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                                  style: const TextStyle(
                                    color: Color(0xFF2C3E50),
                                    fontSize: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF5F5F5),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  prefix: Padding(
                                    padding: const EdgeInsets.only(left: 12),
                                    child: Icon(
                                      CupertinoIcons.lock,
                                      color: const Color(0xFF7F8C8D),
                                      size: 20,
                                    ),
                                  ),
                                  suffix: Padding(
                                    padding: const EdgeInsets.only(right: 12),
                                    child: GestureDetector(
                                      onTap: () => viewModel.togglePasswordVisibility(),
                                      child: Icon(
                                        viewModel.obscurePassword
                                            ? CupertinoIcons.eye
                                            : CupertinoIcons.eye_slash,
                                        color: const Color(0xFF7F8C8D),
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                                
                                const SizedBox(height: 20),
                                
                                // Kullanım koşulları ve KVKK
                                Row(
                                  children: [
                                    Transform.scale(
                                      scale: 0.8,
                                      child: CupertinoSwitch(
                                        value: viewModel.acceptPolicy,
                                        activeColor: const Color(0xFF3498DB),
                                        onChanged: (bool value) {
                                          viewModel.togglePolicy();
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Kullanım Koşullarını kabul ediyorum',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: const Color(0xFF7F8C8D),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                
                                const SizedBox(height: 8),
                                
                                Row(
                                  children: [
                                    Transform.scale(
                                      scale: 0.8,
                                      child: CupertinoSwitch(
                                        value: viewModel.acceptKvkk,
                                        activeColor: const Color(0xFF3498DB),
                                        onChanged: (bool value) {
                                          viewModel.toggleKvkk();
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'KVKK Aydınlatma Metnini kabul ediyorum',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: const Color(0xFF7F8C8D),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          
                          // Hata mesajı
                          if (viewModel.status == RegisterStatus.error)
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
                                    Icon(
                                      CupertinoIcons.exclamationmark_triangle,
                                      color: const Color(0xFFE74C3C),
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        viewModel.errorMessage,
                                        style: TextStyle(
                                          color: const Color(0xFFE74C3C),
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          
                          const Spacer(),
                          
                          // Kayıt butonu
                          Padding(
                            padding: const EdgeInsets.only(bottom: 20, top: 20),
                            child: CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: viewModel.status == RegisterStatus.loading
                                  ? null
                                  : () async {
                                      // Telefon validasyonu ekle
                                      final phoneError = validatePhoneNumber(_phoneController.text);
                                      if (phoneError != null) {
                                        // setError fonksiyonu yerine bir CupertinoDialog gösterelim
                                        showCupertinoDialog(
                                          context: context,
                                          builder: (context) => CupertinoAlertDialog(
                                            title: const Text('Telefon Numarası Hatası'),
                                            content: Text(phoneError),
                                            actions: [
                                              CupertinoDialogAction(
                                                child: const Text('Tamam'),
                                                onPressed: () {
                                                  Navigator.of(context).pop();
                                                },
                                              ),
                                            ],
                                          ),
                                        );
                                        return;
                                      }
                                      
                                      final success = await viewModel.register(
                                        firstName: _firstNameController.text.trim(),
                                        lastName: _lastNameController.text.trim(),
                                        email: _emailController.text.trim(),
                                        phone: _phoneController.text.trim(),
                                        password: _passwordController.text,
                                      );
                                      
                                      if (success && mounted) {
                                        // Kayıt başarılıysa giriş sayfasına yönlendir
                                        showCupertinoDialog(
                                          context: context,
                                          builder: (context) => CupertinoAlertDialog(
                                            title: const Text('Kayıt Başarılı'),
                                            content: const Text('Hesabınız başarıyla oluşturuldu. Giriş yapabilirsiniz.'),
                                            actions: [
                                              CupertinoDialogAction(
                                                child: const Text('Tamam'),
                                                onPressed: () {
                                                  Navigator.of(context).pop();
                                                  Navigator.of(context).pushReplacement(
                                                    CupertinoPageRoute(
                                                      builder: (context) => const LoginView(),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                        );
                                      }
                                    },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF3498DB),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Center(
                                  child: viewModel.status == RegisterStatus.loading
                                      ? const CupertinoActivityIndicator(
                                          color: CupertinoColors.white,
                                        )
                                      : const Text(
                                          'Kayıt Ol',
                                          style: TextStyle(
                                            color: CupertinoColors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ),
                          
                          // Giriş yap bağlantısı
                          Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Zaten bir hesabınız var mı?',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: const Color(0xFF7F8C8D),
                                  ),
                                ),
                                CupertinoButton(
                                  padding: const EdgeInsets.only(left: 4),
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                  child: Text(
                                    'Giriş Yap',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: const Color(0xFF3498DB),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
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
} 