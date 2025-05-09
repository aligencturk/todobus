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