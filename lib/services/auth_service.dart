import '../models/auth_models.dart';
import 'base_api_service.dart';
import '../services/storage_service.dart';
import '../services/logger_service.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  final BaseApiService _apiService = BaseApiService();
  final StorageService _storageService = StorageService();
  final LoggerService _logger = LoggerService();

  factory AuthService() {
    return _instance;
  }

  AuthService._internal();

  // Login metodu
  Future<LoginResponse> login(String email, String password) async {
    final loginRequest = LoginRequest(
      userEmail: email,
      userPassword: password,
    );

    final response = await _apiService.post(
      'service/auth/login',
      body: loginRequest.toJson(),
    );

    final loginResponse = LoginResponse.fromJson(response);

    if (loginResponse.success) {
      // Başarılı girişte kullanıcı bilgilerini kaydet
      if (loginResponse.data != null) {
        await _storageService.saveToken(loginResponse.data!.token);
        await _storageService.saveUserId(loginResponse.data!.userID);
        await _storageService.setLoggedIn(true);
      }
    }

    return loginResponse;
  }

  // Kayıt metodu
  Future<RegisterResponse> register({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String password,
    required bool policy,
    required bool kvkk,
  }) async {
    try {
      _logger.i('Kullanıcı kaydı yapılıyor: $email');
      
      final registerRequest = RegisterRequest(
        userFirstname: firstName,
        userLastname: lastName,
        userEmail: email,
        userPhone: phone,
        userPassword: password,
        version: _apiService.getAppVersion(),
        platform: _apiService.getPlatform(),
        policy: policy,
        kvkk: kvkk,
      );
      
      final response = await _apiService.post(
        'service/auth/register',
        body: registerRequest.toJson(),
      );
      
      final registerResponse = RegisterResponse.fromJson(response);
      
      if (registerResponse.success) {
        _logger.i('Kullanıcı kaydı başarılı: $email');
      } else {
        _logger.w('Kullanıcı kaydı başarısız: ${registerResponse.message}');
      }
      
      return registerResponse;
    } catch (e) {
      _logger.e('Kullanıcı kaydı sırasında hata: $e');
      throw Exception('Kayıt işlemi sırasında bir hata oluştu: $e');
    }
  }
  
  // Şifremi unuttum metodu
  Future<ForgotPasswordResponse> forgotPassword(String email) async {
    try {
      _logger.i('Şifre sıfırlama isteği gönderiliyor: $email');
      
      final forgotRequest = ForgotPasswordRequest(
        userEmail: email,
      );
      
      final response = await _apiService.post(
        'service/auth/forgotPassword',
        body: forgotRequest.toJson(),
      );
      
      final forgotResponse = ForgotPasswordResponse.fromJson(response);
      
      if (forgotResponse.success) {
        _logger.i('Şifre sıfırlama isteği başarılı: $email');
      } else {
        _logger.w('Şifre sıfırlama isteği başarısız: ${forgotResponse.message}');
      }
      
      return forgotResponse;
    } catch (e) {
      _logger.e('Şifre sıfırlama isteği sırasında hata: $e');
      throw Exception('Bir hata oluştu, lütfen tekrar deneyin.');
    }
  }
  
  // Doğrulama kodu kontrolü
  Future<CodeCheckResponse> checkVerificationCode(String code, String token) async {
    try {
      _logger.i('Doğrulama kodu kontrol ediliyor: $code');
      
      final codeRequest = CodeCheckRequest(
        code: code,
        token: token,
      );
      
      final response = await _apiService.post(
        'service/auth/code/checkCode',
        body: codeRequest.toJson(),
      );
      
      final codeResponse = CodeCheckResponse.fromJson(response);
      
      if (codeResponse.success) {
        _logger.i('Doğrulama kodu kontrolü başarılı');
      } else {
        _logger.w('Doğrulama kodu kontrolü başarısız: ${codeResponse.message}');
      }
      
      return codeResponse;
    } catch (e) {
      _logger.e('Doğrulama kodu kontrolü sırasında hata: $e');
      throw Exception('Bir hata oluştu, lütfen tekrar deneyin.');
    }
  }
  
  // Şifre güncelleme
  Future<UpdatePasswordResponse> updatePassword(String passToken, String password, String passwordAgain) async {
    try {
      _logger.i('Şifre güncelleniyor');
      
      final updateRequest = UpdatePasswordRequest(
        passToken: passToken,
        password: password,
        passwordAgain: passwordAgain,
      );
      
      final response = await _apiService.post(
        'service/auth/forgotPassword/updatePass',
        body: updateRequest.toJson(),
      );
      
      final updateResponse = UpdatePasswordResponse.fromJson(response);
      
      if (updateResponse.success) {
        _logger.i('Şifre güncelleme başarılı');
      } else {
        _logger.w('Şifre güncelleme başarısız: ${updateResponse.message}');
      }
      
      return updateResponse;
    } catch (e) {
      _logger.e('Şifre güncelleme sırasında hata: $e');
      throw Exception('Bir hata oluştu, lütfen tekrar deneyin.');
    }
  }
} 