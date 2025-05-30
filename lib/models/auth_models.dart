// Auth modellerini tanımlıyorum

class LoginRequest {
  final String userEmail;
  final String userPassword;

  LoginRequest({
    required this.userEmail,
    required this.userPassword,
  });

  Map<String, dynamic> toJson() => {
        'userEmail': userEmail,
        'userPassword': userPassword,
      };
}

class LoginResponse {
  final bool error;
  final bool success;
  final LoginData? data;
  final String? errorMessage;
  final int? statusCode;
  final String? userFriendlyMessage;

  LoginResponse({
    required this.error,
    required this.success,
    this.data,
    this.errorMessage,
    this.statusCode,
    this.userFriendlyMessage,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    final int? statusCode = json['statusCode'] is int 
        ? json['statusCode'] 
        : (json['statusCode'] is String ? int.tryParse(json['statusCode']) : null);
    
    bool success = json['success'] ?? false;
    String? errorMessage = json['errorMessage'] ?? json['error_message'];
    String? userFriendlyMessage;

    if (!success) {
      String baseMessage = errorMessage ?? 'Giriş yapılırken bilinmeyen bir hata oluştu.';
      if (json.containsKey('417')) {
        baseMessage = 'E-posta adresi veya şifre hatalı.';
        userFriendlyMessage = 'API Hatası: 417 - $baseMessage';
      } else if (statusCode == 400) {
        baseMessage = 'E-posta veya şifre hatalı.';
        userFriendlyMessage = 'API Hatası: $statusCode - $baseMessage';
      } else if (statusCode == 401) {
        baseMessage = 'Hesabınız aktif değil. Lütfen e-postanızı kontrol edin.';
        userFriendlyMessage = 'API Hatası: $statusCode - $baseMessage';
      } else if (statusCode == 404) {
        baseMessage = 'Bu e-posta adresiyle kayıtlı kullanıcı bulunamadı.';
        userFriendlyMessage = 'API Hatası: $statusCode - $baseMessage';
      } else {
        if (statusCode != null) {
          userFriendlyMessage = 'API Hatası: $statusCode - $baseMessage';
        } else {
          userFriendlyMessage = baseMessage;
        }
      }
    }
    
    return LoginResponse(
      error: json['error'] ?? !success,
      success: success,
      data: json['data'] != null ? LoginData.fromJson(json['data']) : null,
      errorMessage: errorMessage,
      statusCode: statusCode,
      userFriendlyMessage: userFriendlyMessage,
    );
  }
}

class LoginData {
  final int userID;
  final String token;

  LoginData({
    required this.userID,
    required this.token,
  });

  factory LoginData.fromJson(Map<String, dynamic> json) {
    return LoginData(
      userID: json['userID'],
      token: json['token'],
    );
  }
}

// Kayıt isteği modeli
class RegisterRequest {
  final String userFirstname;
  final String userLastname;
  final String userEmail;
  final String userPhone;
  final String userPassword;
  final String version;
  final String platform;
  final bool policy;
  final bool kvkk;

  RegisterRequest({
    required this.userFirstname,
    required this.userLastname,
    required this.userEmail,
    required this.userPhone,
    required this.userPassword,
    required this.version,
    required this.platform,
    required this.policy,
    required this.kvkk,
  });

  Map<String, dynamic> toJson() => {
        'userFirstname': userFirstname,
        'userLastname': userLastname,
        'userEmail': userEmail,
        'userPhone': userPhone,
        'userPassword': userPassword,
        'version': version,
        'platform': platform,
        'policy': policy,
        'kvkk': kvkk,
      };
}

// Kayıt yanıtı modeli
class RegisterResponse {
  final bool error;
  final bool success;
  final String? message;
  final int? statusCode;
  final String? userFriendlyMessage;

  RegisterResponse({
    required this.error,
    required this.success,
    this.message,
    this.statusCode,
    this.userFriendlyMessage,
  });

  factory RegisterResponse.fromJson(Map<String, dynamic> json) {
    final int? statusCode = json['statusCode'] is int 
        ? json['statusCode'] 
        : (json['statusCode'] is String ? int.tryParse(json['statusCode']) : null);
    
    bool success = json['success'] ?? false;
    String? message = json['message'];
    String? userFriendlyMessage;

    if (!success) {
      String baseMessage = message ?? 'Kayıt işlemi sırasında bilinmeyen bir hata oluştu.';
      if (json.containsKey('417') || statusCode == 417) {
        baseMessage = 'Bu e-posta adresi zaten kayıtlı. Lütfen giriş yapın veya başka bir e-posta adresi kullanın.';
        userFriendlyMessage = 'API Hatası: 417 - $baseMessage';
      } else {
        if (statusCode != null) {
          userFriendlyMessage = 'API Hatası: $statusCode - $baseMessage';
        } else {
          userFriendlyMessage = baseMessage;
        }
      }
    }
    
    return RegisterResponse(
      error: json['error'] ?? !success,
      success: success,
      message: message,
      statusCode: statusCode,
      userFriendlyMessage: userFriendlyMessage,
    );
  }
}

// Şifremi unuttum isteği
class ForgotPasswordRequest {
  final String userEmail;

  ForgotPasswordRequest({
    required this.userEmail,
  });

  Map<String, dynamic> toJson() => {
        'userEmail': userEmail,
      };
}

// Şifremi unuttum yanıtı
class ForgotPasswordResponse {
  final bool error;
  final bool success;
  final String? message;
  final ForgotPasswordData? data;
  final int? statusCode;
  final String? userFriendlyMessage;

  ForgotPasswordResponse({
    required this.error,
    required this.success,
    this.message,
    this.data,
    this.statusCode,
    this.userFriendlyMessage,
  });

  factory ForgotPasswordResponse.fromJson(Map<String, dynamic> json) {
    final int? statusCode = json['statusCode'] is int 
        ? json['statusCode'] 
        : (json['statusCode'] is String ? int.tryParse(json['statusCode']) : null);
    
    // Kullanıcı dostu mesaj oluştur
    String? friendlyMessage;
    if (!(json['success'] ?? false)) {
      String baseMessage;
      if (statusCode == 404) {
        baseMessage = 'Bu e-posta adresiyle kayıtlı hesap bulunamadı.';
      } else {
        baseMessage = json['message'] ?? 'Şifre sıfırlama işlemi sırasında bir hata oluştu.';
      }

      if (statusCode != null) {
        friendlyMessage = 'API Hatası: $statusCode - $baseMessage';
      } else {
        friendlyMessage = baseMessage;
      }
    }
    
    return ForgotPasswordResponse(
      error: json['error'] ?? false,
      success: json['success'] ?? false,
      message: json['message'],
      data: json['data'] != null ? ForgotPasswordData.fromJson(json['data']) : null,
      statusCode: statusCode,
      userFriendlyMessage: friendlyMessage,
    );
  }
}

class ForgotPasswordData {
  final String token;

  ForgotPasswordData({
    required this.token,
  });

  factory ForgotPasswordData.fromJson(Map<String, dynamic> json) {
    return ForgotPasswordData(
      token: json['token'],
    );
  }
}

// Doğrulama kodu kontrolü
class CodeCheckRequest {
  final String code;
  final String token;

  CodeCheckRequest({
    required this.code,
    required this.token,
  });

  Map<String, dynamic> toJson() => {
        'code': code,
        'token': token,
      };
}

class CodeCheckResponse {
  final bool error;
  final bool success;
  final String? message;
  final CodeCheckData? data;
  final String? userFriendlyMessage;

  CodeCheckResponse({
    required this.error,
    required this.success,
    this.message,
    this.data,
    this.userFriendlyMessage,
  });

  factory CodeCheckResponse.fromJson(Map<String, dynamic> json) {
    // Kullanıcı dostu mesaj oluştur
    String? friendlyMessage;
    if (!json['success']) {
      final message = json['message'] as String?;
      if (message != null) {
        if (message.contains('hatalı')) {
          friendlyMessage = 'Girdiğiniz kod hatalı. Lütfen tekrar kontrol edin.';
        } else if (message.contains('süresi')) {
          friendlyMessage = 'Doğrulama kodunun süresi dolmuş. Lütfen yeni kod talep edin.';
        } else {
          friendlyMessage = 'Doğrulama kodu kontrolü sırasında bir hata oluştu.';
        }
      }
    }
    
    return CodeCheckResponse(
      error: json['error'] ?? false,
      success: json['success'] ?? false,
      message: json['message'],
      data: json['data'] != null ? CodeCheckData.fromJson(json['data']) : null,
      userFriendlyMessage: friendlyMessage,
    );
  }
}

class CodeCheckData {
  final String passToken;

  CodeCheckData({
    required this.passToken,
  });

  factory CodeCheckData.fromJson(Map<String, dynamic> json) {
    return CodeCheckData(
      passToken: json['passToken'],
    );
  }
}

// Şifre güncelleme
class UpdatePasswordRequest {
  final String passToken;
  final String password;
  final String passwordAgain;

  UpdatePasswordRequest({
    required this.passToken,
    required this.password,
    required this.passwordAgain,
  });

  Map<String, dynamic> toJson() => {
        'passToken': passToken,
        'password': password,
        'passwordAgain': passwordAgain,
      };
}

class UpdatePasswordResponse {
  final bool error;
  final bool success;
  final String? message;
  final String? userFriendlyMessage;

  UpdatePasswordResponse({
    required this.error,
    required this.success,
    this.message,
    this.userFriendlyMessage,
  });

  factory UpdatePasswordResponse.fromJson(Map<String, dynamic> json) {
    // Kullanıcı dostu mesaj oluştur
    String? friendlyMessage;
    if (!json['success']) {
      final message = json['message'] as String?;
      if (message != null) {
        if (message.contains('eşleşmiyor')) {
          friendlyMessage = 'Girdiğiniz şifreler birbiriyle eşleşmiyor. Lütfen tekrar deneyin.';
        } else if (message.contains('token')) {
          friendlyMessage = 'Şifre sıfırlama bağlantınızın süresi dolmuş. Lütfen yeni bir şifre sıfırlama işlemi başlatın.';
        } else {
          friendlyMessage = 'Şifre güncellenirken bir hata oluştu.';
        }
      }
    }
    
    return UpdatePasswordResponse(
      error: json['error'] ?? false,
      success: json['success'] ?? false,
      message: json['message'],
      userFriendlyMessage: friendlyMessage,
    );
  }
}

// Tekrar kod gönderme isteği
class AgainSendCodeRequest {
  final String userToken;

  AgainSendCodeRequest({
    required this.userToken,
  });

  Map<String, dynamic> toJson() => {
        'userToken': userToken,
      };
}

// Tekrar kod gönderme yanıtı
class AgainSendCodeResponse {
  final bool error;
  final bool success;
  final String? message;
  final AgainSendCodeData? data;
  final String? userFriendlyMessage;

  AgainSendCodeResponse({
    required this.error,
    required this.success,
    this.message,
    this.data,
    this.userFriendlyMessage,
  });

  factory AgainSendCodeResponse.fromJson(Map<String, dynamic> json) {
    // error_message ve message field'larını kontrol et
    String? message = json['message'] ?? json['error_message'];
    
    // Kullanıcı dostu mesaj oluştur
    String? friendlyMessage;
    if (!json['success']) {
      friendlyMessage = message ?? 'Yeni doğrulama kodu gönderilirken bir hata oluştu.';
    }
    
    return AgainSendCodeResponse(
      error: json['error'] ?? false,
      success: json['success'] ?? false,
      message: message,
      data: json['data'] != null ? AgainSendCodeData.fromJson(json['data']) : null,
      userFriendlyMessage: friendlyMessage,
    );
  }
}

class AgainSendCodeData {
  final String codeToken;

  AgainSendCodeData({
    required this.codeToken,
  });

  factory AgainSendCodeData.fromJson(Map<String, dynamic> json) {
    return AgainSendCodeData(
      codeToken: json['codeToken'],
    );
  }
} 