class User {
  final int userID;
  final String username;
  final String userFirstname;
  final String userLastname;
  final String userFullname;
  final String userEmail;
  final String userBirthday;
  final String userPhone;
  final String userRank;
  final String userStatus;
  final String userGender;
  final String userToken;
  final String userPlatform;
  final String userVersion;
  final String iosVersion;
  final String androidVersion;
  final String profilePhoto;

  User({
    required this.userID,
    required this.username,
    required this.userFirstname,
    required this.userLastname,
    required this.userFullname,
    required this.userEmail,
    required this.userBirthday,
    required this.userPhone,
    required this.userRank,
    required this.userStatus,
    required this.userGender,
    required this.userToken,
    required this.userPlatform,
    required this.userVersion,
    required this.iosVersion,
    required this.androidVersion,
    required this.profilePhoto,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userID: json['userID'] ?? 0,
      username: json['username'] ?? '',
      userFirstname: json['userFirstname'] ?? '',
      userLastname: json['userLastname'] ?? '',
      userFullname: json['userFullname'] ?? '',
      userEmail: json['userEmail'] ?? '',
      userBirthday: json['userBirthday'] ?? '',
      userPhone: json['userPhone'] ?? '',
      userRank: json['userRank'] ?? '',
      userStatus: json['userStatus'] ?? '',
      userGender: json['userGender'] ?? '',
      userToken: json['userToken'] ?? '',
      userPlatform: json['userPlatform'] ?? '',
      userVersion: json['userVersion'] ?? '',
      iosVersion: json['iosVersion'] ?? '',
      androidVersion: json['androidVersion'] ?? '',
      profilePhoto: json['profilePhoto'] ?? '',
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'userID': userID,
      'username': username,
      'userFirstname': userFirstname,
      'userLastname': userLastname,
      'userFullname': userFullname,
      'userEmail': userEmail,
      'userBirthday': userBirthday,
      'userPhone': userPhone,
      'userRank': userRank,
      'userStatus': userStatus,
      'userGender': userGender,
      'userToken': userToken,
      'userPlatform': userPlatform,
      'userVersion': userVersion,
      'iosVersion': iosVersion,
      'androidVersion': androidVersion,
      'profilePhoto': profilePhoto,
    };
  }
}

class UserResponse {
  final bool error;
  final bool success;
  final UserData? data;
  final String? errorMessage;
  final int? code;

  UserResponse({
    required this.error,
    required this.success,
    this.data,
    this.errorMessage,
    this.code,
  });

  factory UserResponse.fromJson(Map<String, dynamic> json) {
    return UserResponse(
      error: json['error'] ?? false,
      success: json['success'] ?? false,
      data: json['data'] != null ? UserData.fromJson(json['data']) : null,
      errorMessage: json['errorMessage'],
      code: json['code'],
    );
  }
}

class UserData {
  final User user;

  UserData({required this.user});

  factory UserData.fromJson(Map<String, dynamic> json) {
    return UserData(
      user: User.fromJson(json['user'] ?? {}),
    );
  }
} 