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
    try {
      _logger.i('Kullanıcı giriş yapıyor: $email');
      
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
          _logger.i('Kullanıcı başarıyla giriş yaptı: $email');
        }
      } else {
        if (loginResponse.statusCode == 400) {
          _logger.w('Hatalı giriş denemesi: E-posta veya şifre hatalı');
        } else if (loginResponse.statusCode == 401) {
          _logger.w('Hesap aktif değil: $email');
        } else if (loginResponse.statusCode == 404) {
          _logger.w('Kullanıcı bulunamadı: $email');
        } else {
          _logger.w('Giriş başarısız: ${loginResponse.statusCode} - ${loginResponse.errorMessage}');
        }
      }

      return loginResponse;
    } catch (e, s) {
      _logger.e('Giriş sırasında kritik hata: $e', null, s);
      
      // Exception'dan gerçek mesajı extract et
      String errorMessage = e.toString();
      String userFriendlyMessage = errorMessage;
      
      // "Exception: " prefix'ini temizle
      if (errorMessage.startsWith('Exception: ')) {
        userFriendlyMessage = errorMessage.substring('Exception: '.length);
      }
      
      return LoginResponse(
        error: true,
        success: false,
        errorMessage: errorMessage,
        statusCode: null,
        userFriendlyMessage: userFriendlyMessage,
        data: null,
      );
    }
  }

  // Kayıt metodu
  Future<RegisterResponse> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required bool policy,
    required bool kvkk,
  }) async {
    _logger.i('Kullanıcı kaydı yapılıyor: $email');
    
    final registerRequest = RegisterRequest(
      userFirstname: firstName,
      userLastname: lastName,
      userEmail: email,
      userPhone: '',
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
      // Log the specific error message if available
      _logger.w('Kullanıcı kaydı başarısız: ${registerResponse.userFriendlyMessage ?? registerResponse.message ?? registerResponse.statusCode?.toString() ?? "Bilinmeyen hata"}');
    }
    
    return registerResponse;
  }
  
  // Şifremi unuttum metodu
  Future<ForgotPasswordResponse> forgotPassword(String email) async {
    try {
      print('🔍 AUTH_SERVICE: forgotPassword başlatıldı - email: $email');
      _logger.i('Şifre sıfırlama isteği gönderiliyor: $email');
      
      final forgotRequest = ForgotPasswordRequest(
        userEmail: email,
      );
      
      _logger.d('API endpoint: service/auth/forgotPassword');
      _logger.d('Request payload: ${forgotRequest.toJson()}');
      print('🔍 AUTH_SERVICE: Request payload hazırlandı: ${forgotRequest.toJson()}');
      
      print('🔍 AUTH_SERVICE: API çağrısı yapılıyor: service/auth/forgotPassword');
      final response = await _apiService.post(
        'service/auth/forgotPassword',
        body: forgotRequest.toJson(),
      );
      
      print('🔍 AUTH_SERVICE: Ham API yanıtı alındı');
      print('🔍 AUTH_SERVICE: Response type: ${response.runtimeType}');
      print('🔍 AUTH_SERVICE: Response: $response');
      
      _logger.d('Raw API response: $response');
      
      print('🔍 AUTH_SERVICE: Response parsing başlıyor...');
      final forgotResponse = ForgotPasswordResponse.fromJson(response);
      print('🔍 AUTH_SERVICE: Response parsing tamamlandı');
      
      _logger.d('Parsed response - success: ${forgotResponse.success}, statusCode: ${forgotResponse.statusCode}');
      _logger.d('Response message: ${forgotResponse.message}');
      _logger.d('Response data: ${forgotResponse.data}');
      _logger.d('Token in data: ${forgotResponse.data?.token}');
      
      print('🔍 AUTH_SERVICE: Parsed response özeti:');
      print('  - success: ${forgotResponse.success}');
      print('  - statusCode: ${forgotResponse.statusCode}');
      print('  - message: ${forgotResponse.message}');
      print('  - data is null: ${forgotResponse.data == null}');
      if (forgotResponse.data != null) {
        print('  - token is null: ${forgotResponse.data!.token == null}');
        print('  - token: ${forgotResponse.data!.token}');
      }
      
      if (forgotResponse.success) {
        print('🔍 AUTH_SERVICE: ✅ API başarılı');
        _logger.i('Şifre sıfırlama isteği başarılı: $email');
      } else {
        print('🔍 AUTH_SERVICE: ❌ API başarısız');
        if (forgotResponse.statusCode == 404) {
          _logger.w('Şifre sıfırlama: Kullanıcı bulunamadı: $email');
        } else if (forgotResponse.statusCode == 417) {
          _logger.w('Şifre sıfırlama: Rate limiting - çok sık istek gönderildi');
          print('🔍 AUTH_SERVICE: 417 - Rate limiting hatası');
          // 417 durumunda kullanıcı dostu mesaj oluştur
          return ForgotPasswordResponse(
            error: true,
            success: false,
            message: forgotResponse.message,
            statusCode: 417,
            userFriendlyMessage: 'Çok sık şifre sıfırlama isteği gönderdiniz. Lütfen birkaç dakika bekleyip tekrar deneyin.',
            data: null,
          );
        } else {
          _logger.w('Şifre sıfırlama isteği başarısız: ${forgotResponse.statusCode} - ${forgotResponse.message}');
        }
      }
      
      return forgotResponse;
    } catch (e, s) {
      print('🔍 AUTH_SERVICE: ❌ Exception yakalandı: $e');
      print('🔍 AUTH_SERVICE: Stack trace: $s');
      _logger.e('Şifre sıfırlama isteği sırasında kritik hata: $e', null, s);
      return ForgotPasswordResponse(
        error: true,
        success: false,
        message: e.toString(),
        statusCode: null,
        userFriendlyMessage: 'Şifre sıfırlama işlemi sırasında bir sorun oluştu. Lütfen daha sonra tekrar deneyin.',
      );
    }
  }
  
  // Doğrulama kodu kontrolü
  Future<CodeCheckResponse> checkVerificationCode(String code, String codeToken) async {
    try {
      _logger.i('Doğrulama kodu kontrol ediliyor: $code');
      _logger.i('Kullanılacak codeToken: ${codeToken.length > 8 ? '${codeToken.substring(0, 8)}...' : codeToken}');
      
      final codeRequest = CodeCheckRequest(
        code: code,
        codeToken: codeToken,
      );
      
      _logger.d('API\'ye gönderilecek payload: ${codeRequest.toJson()}');
      
      final response = await _apiService.post(
        'service/auth/code/checkCode',
        body: codeRequest.toJson(),
      );
      
      final codeResponse = CodeCheckResponse.fromJson(response);
      
      if (codeResponse.success) {
        _logger.i('Doğrulama kodu kontrolü başarılı');
      } else {
        if (codeResponse.message?.contains('hatalı') == true) {
          _logger.w('Doğrulama kodu hatalı: $code');
        } else if (codeResponse.message?.contains('süresi') == true) {
          _logger.w('Doğrulama kodunun süresi dolmuş');
        } else if (codeResponse.statusCode == 417) {
          _logger.w('Doğrulama kodu: Rate limiting veya geçersiz token - 417');
          // 417 durumunda kullanıcı dostu mesaj döndür
          return CodeCheckResponse(
            error: true,
            success: false,
            message: codeResponse.message,
            userFriendlyMessage: 'Doğrulama kodunuz yanlış veya süresi dolmuş olabilir. Lütfen yeni kod talep edin.',
            data: null,
          );
        } else {
          _logger.w('Doğrulama kodu kontrolü başarısız: ${codeResponse.message}');
        }
      }
      
      return codeResponse;
    } catch (e, s) {
      _logger.e('Doğrulama kodu kontrolü sırasında kritik hata: $e', null, s);
      return CodeCheckResponse(
        error: true,
        success: false,
        message: e.toString(),
        userFriendlyMessage: 'Kod doğrulaması sırasında bir sorun oluştu. Lütfen daha sonra tekrar deneyin.',
      );
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
        if (updateResponse.message?.contains('eşleşmiyor') == true) {
          _logger.w('Şifre güncelleme: Şifreler eşleşmiyor');
        } else if (updateResponse.message?.contains('token') == true) {
          _logger.w('Şifre güncelleme: Geçersiz veya süresi dolmuş token');
        } else {
          _logger.w('Şifre güncelleme başarısız: ${updateResponse.message}');
        }
      }
      
      return updateResponse;
    } catch (e, s) {
      _logger.e('Şifre güncelleme sırasında kritik hata: $e', null, s);
      return UpdatePasswordResponse(
        error: true,
        success: false,
        message: e.toString(),
        userFriendlyMessage: 'Şifre güncellenirken bir sorun oluştu. Lütfen daha sonra tekrar deneyin.',
      );
    }
  }
  
  // Tekrar doğrulama kodu gönderme
  Future<AgainSendCodeResponse> againSendCode(String userToken) async {
    try {
      _logger.i('Yeni doğrulama kodu gönderiliyor');
      
      final codeRequest = AgainSendCodeRequest(
        userToken: userToken,
      );
      
      final response = await _apiService.post(
        'service/auth/code/againSendCode',
        body: codeRequest.toJson(),
      );
      
      // Debug: Raw API response'unu logla
      _logger.d('Raw API response: $response');
      
      final codeResponse = AgainSendCodeResponse.fromJson(response);
      
      // Debug: Parse edilmiş response'u detaylı logla
      _logger.d('Parsed response - success: ${codeResponse.success}, statusCode: ${codeResponse.statusCode}, message: ${codeResponse.message}');
      _logger.d('Response data: ${codeResponse.data?.codeToken != null ? "codeToken var (${codeResponse.data!.codeToken.length} karakter)" : "codeToken yok"}');
      
      // Status code'a göre işlem yap
      if (codeResponse.statusCode == 410) {
        // 410 = Başarılı kod gönderildi
        _logger.i('Yeni doğrulama kodu başarıyla gönderildi');
        return codeResponse.copyWith(success: true);
      } else if (codeResponse.statusCode == 417) {
        // 417 = Bekleme süresi var
        _logger.w('Kod gönderme için bekleme süresi: ${codeResponse.message}');
        return codeResponse.copyWith(success: false);
      } else {
        // Diğer status code'lar hata
        _logger.w('Yeni doğrulama kodu gönderme başarısız: ${codeResponse.statusCode} - ${codeResponse.message}');
        return codeResponse.copyWith(success: false);
      }
    } catch (e, s) {
      _logger.e('Yeni doğrulama kodu gönderme sırasında kritik hata: $e', null, s);
      return AgainSendCodeResponse(
        error: true,
        success: false,
        message: e.toString(),
      );
    }
  }
  
  // Kullanıcı hesap silme
  Future<DeleteUserResponse> deleteUser(String userToken) async {
    try {
      _logger.i('Kullanıcı hesap silme işlemi başlatılıyor');
      
      final deleteRequest = DeleteUserRequest(
        userToken: userToken,
      );
      
      final response = await _apiService.delete(
        'service/user/account/delete',
        body: deleteRequest.toJson(),
      );
      
      final deleteResponse = DeleteUserResponse.fromJson(response);
      
      if (deleteResponse.success) {
        _logger.i('Kullanıcı hesabı başarıyla silindi');
      } else {
        if (deleteResponse.statusCode == 400) {
          _logger.w('Hesap silme: Geçersiz token veya kullanıcı bilgisi');
        } else if (deleteResponse.statusCode == 401) {
          _logger.w('Hesap silme: Yetki hatası');
        } else if (deleteResponse.statusCode == 404) {
          _logger.w('Hesap silme: Kullanıcı bulunamadı');
        } else {
          _logger.w('Hesap silme başarısız: ${deleteResponse.statusCode} - ${deleteResponse.message}');
        }
      }
      
      return deleteResponse;
    } catch (e, s) {
      _logger.e('Kullanıcı hesap silme sırasında kritik hata: $e', null, s);
      return DeleteUserResponse(
        error: true,
        success: false,
        message: e.toString(),
        userFriendlyMessage: 'Hesap silme işlemi sırasında bir sorun oluştu. Lütfen daha sonra tekrar deneyin.',
      );
    }
  }
} 