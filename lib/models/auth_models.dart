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

  LoginResponse({
    required this.error,
    required this.success,
    this.data,
    this.errorMessage,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      error: json['error'] ?? false,
      success: json['success'] ?? false,
      data: json['data'] != null ? LoginData.fromJson(json['data']) : null,
      errorMessage: json['errorMessage'],
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

  RegisterResponse({
    required this.error,
    required this.success,
    this.message,
  });

  factory RegisterResponse.fromJson(Map<String, dynamic> json) {
    return RegisterResponse(
      error: json['error'] ?? false,
      success: json['success'] ?? false,
      message: json['message'],
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

  ForgotPasswordResponse({
    required this.error,
    required this.success,
    this.message,
    this.data,
  });

  factory ForgotPasswordResponse.fromJson(Map<String, dynamic> json) {
    return ForgotPasswordResponse(
      error: json['error'] ?? false,
      success: json['success'] ?? false,
      message: json['message'],
      data: json['data'] != null ? ForgotPasswordData.fromJson(json['data']) : null,
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

  CodeCheckResponse({
    required this.error,
    required this.success,
    this.message,
    this.data,
  });

  factory CodeCheckResponse.fromJson(Map<String, dynamic> json) {
    return CodeCheckResponse(
      error: json['error'] ?? false,
      success: json['success'] ?? false,
      message: json['message'],
      data: json['data'] != null ? CodeCheckData.fromJson(json['data']) : null,
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

  UpdatePasswordResponse({
    required this.error,
    required this.success,
    this.message,
  });

  factory UpdatePasswordResponse.fromJson(Map<String, dynamic> json) {
    return UpdatePasswordResponse(
      error: json['error'] ?? false,
      success: json['success'] ?? false,
      message: json['message'],
    );
  }
} 