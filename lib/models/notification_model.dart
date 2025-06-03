class NotificationModel {
  final String id;
  final String title;
  final String body;
  final String type;
  final String typeId;
  final String url;
  final String createDate;
  final bool isRead;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.typeId,
    required this.url,
    required this.createDate,
    this.isRead = false,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      type: json['type'] as String,
      typeId: json['type_id'] as String,
      url: json['url'] as String,
      createDate: json['create_date'] as String,
      isRead: json['is_read'] == 1 || json['is_read'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'type': type,
      'type_id': typeId,
      'url': url,
      'create_date': createDate,
      'is_read': isRead,
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