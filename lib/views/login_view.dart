import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../viewmodels/login_viewmodel.dart';
import '../main_app.dart';
import 'register_view.dart';
import 'forgot_password_view.dart';

class LoginView extends StatefulWidget {
  const LoginView({Key? key}) : super(key: key);

  @override
  _LoginViewState createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LoginViewModel(),
      child: Consumer<LoginViewModel>(
        builder: (context, viewModel, _) {
          return CupertinoPageScaffold(
            backgroundColor: CupertinoColors.systemBackground,
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
                          const SizedBox(height: 60),
                          // Logo
                          Center(
                            child: Image.asset(
                              'assets/icon.png', 
                              width: 250,
                              height: 250,
                            ),
                          ),
      
                          
                          // Form
                          Form(
                            key: _formKey,
                            child: Container(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // E-posta alanı
                                  Container(
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide.none,
                                      ),
                                    ),
                                    child: Text(
                                      'E-posta',
                                      style: TextStyle(
                                        color: const Color(0xFF34495E),
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        decoration: TextDecoration.none,
                                      ),
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
                                  
                                  const SizedBox(height: 20),
                                  
                                  // Şifre alanı
                                  Container(
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide.none,
                                      ),
                                    ),
                                    child: Text(
                                      'Şifre',
                                      style: TextStyle(
                                        color: const Color(0xFF34495E),
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        decoration: TextDecoration.none,
                                      ),
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
                                  
                                  // "Beni Hatırla" seçeneği
                                  Padding(
                                    padding: const EdgeInsets.only(top: 16),
                                    child: Row(
                                      children: [
                                        Transform.scale(
                                          scale: 0.8,
                                          child: CupertinoSwitch(
                                            value: true,
                                            activeColor: const Color(0xFF3498DB),
                                            onChanged: (bool value) {
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Beni Hatırla',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: const Color(0xFF7F8C8D),
                                            fontWeight: FontWeight.w500,
                                            decoration: TextDecoration.none,
                                          ),
                                        ),
                                        const Spacer(),
                                        CupertinoButton(
                                          padding: EdgeInsets.zero,
                                          onPressed: () {
                                            // Şifremi unuttum
                                            Navigator.of(context).push(
                                              CupertinoPageRoute(
                                                builder: (context) => const ForgotPasswordView(),
                                              ),
                                            );
                                          },
                                          child: Text(
                                            'Şifremi Unuttum',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: const Color(0xFF3498DB),
                                              fontWeight: FontWeight.w500,
                                              decoration: TextDecoration.none,
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
                          
                          // Hata mesajı
                          if (viewModel.status == LoginStatus.error)
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
                          
                          const SizedBox(height: 20),                          
                          // Giriş butonu
                          Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: viewModel.status == LoginStatus.loading
                                  ? null
                                  : () async {
                                      if (_formKey.currentState?.validate() ?? false) {
                                        final success = await viewModel.login(
                                          _emailController.text.trim(),
                                          _passwordController.text,
                                        );
                                        
                                        if (success && mounted) {
                                          Navigator.of(context).pushReplacement(
                                            CupertinoPageRoute(
                                              builder: (context) => const MainApp(),
                                            ),
                                          );
                                        }
                                      }
                                    },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF3498DB),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Center(
                                  child: viewModel.status == LoginStatus.loading
                                      ? const CupertinoActivityIndicator(
                                          color: CupertinoColors.white,
                                        )
                                      : const Text(
                                          'Giriş Yap',
                                          style: TextStyle(
                                            color: CupertinoColors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            decoration: TextDecoration.none,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ),
                          
                          // Kayıt ol butonu - büyük
                          Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () {
                                Navigator.of(context).push(
                                  CupertinoPageRoute(
                                    builder: (context) => const RegisterView(),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: const Color(0xFF3498DB)),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Center(
                                  child: Text(
                                    'Kayıt Ol',
                                    style: TextStyle(
                                      color: Color(0xFF3498DB),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                ),
                              ),
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