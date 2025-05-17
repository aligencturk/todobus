class NotificationModel {
  final int id;
  final int userId;
  final String title;
  final String message;
  final String createdAt;
  final bool isRead;
  final Map<String, dynamic>? data;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.isRead,
    this.data,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as int,
      userId: json['userId'] as int,
      title: json['title'] as String,
      message: json['message'] as String,
      createdAt: json['createdAt'] as String,
      isRead: json['isRead'] as bool,
      data: json['data'] != null ? Map<String, dynamic>.from(json['data']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'message': message,
      'createdAt': createdAt,
      'isRead': isRead,
      'data': data,
    };
  }
}

class NotificationResponse {
  final bool success;
  final String? errorMessage;
  final List<NotificationModel>? notifications;
  final int? unreadCount;

  NotificationResponse({
    required this.success,
    this.errorMessage,
    this.notifications,
    this.unreadCount,
  });

  factory NotificationResponse.fromJson(Map<String, dynamic> json) {
    return NotificationResponse(
      success: json['success'] as bool,
      errorMessage: json['errorMessage'] as String?,
      notifications: json['data'] != null && json['data']['notifications'] != null
          ? (json['data']['notifications'] as List)
              .map((e) => NotificationModel.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
      unreadCount: json['data'] != null ? json['data']['unreadCount'] as int? : null,
    );
  }
} 