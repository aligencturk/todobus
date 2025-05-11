class EventsResponse {
  final bool error;
  final bool success;
  final EventsData? data;
  final String? errorMessage;

  EventsResponse({
    required this.error,
    required this.success,
    this.data,
    this.errorMessage,
  });

  factory EventsResponse.fromJson(Map<String, dynamic> json) {
    return EventsResponse(
      error: json['error'] ?? false,
      success: json['success'] ?? false,
      data: json['data'] != null ? EventsData.fromJson(json['data']) : null,
      errorMessage: json['errorMessage'],
    );
  }
}

class EventsData {
  final List<Event> events;

  EventsData({required this.events});

  factory EventsData.fromJson(Map<String, dynamic> json) {
    List<Event> eventsList = [];
    if (json['events'] != null) {
      eventsList = List<Event>.from(
          json['events'].map((event) => Event.fromJson(event)));
    }
    return EventsData(events: eventsList);
  }
}

class Event {
  final int eventID;
  final int groupID;
  final int userID;
  final String userFullname;
  final String eventTitle;
  final String eventDesc;
  final int eventStatusID;
  final String eventStatus;
  final String eventDate;
  final String createDate;
  final String eventType;

  Event({
    required this.eventID,
    required this.groupID,
    required this.userID,
    required this.userFullname,
    required this.eventTitle,
    required this.eventDesc,
    required this.eventStatusID,
    required this.eventStatus,
    required this.eventDate,
    required this.createDate,
    this.eventType = 'user',
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      eventID: json['eventID'] ?? 0,
      groupID: json['groupID'] ?? 0,
      userID: json['userID'] ?? 0,
      userFullname: json['userFullname'] ?? '',
      eventTitle: json['eventTitle'] ?? '',
      eventDesc: json['eventDesc'] ?? '',
      eventStatusID: json['eventStatusID'] ?? 0,
      eventStatus: json['eventStatus'] ?? '',
      eventDate: json['eventDate'] ?? '',
      createDate: json['createDate'] ?? '',
      eventType: json['eventType'] ?? 'user',
    );
  }

  DateTime get eventDateTime {
    // Örnek tarih formatı: "27.04.2025 19:00"
    final parts = eventDate.split(' ');
    if (parts.length != 2) return DateTime.now();
    
    final dateParts = parts[0].split('.');
    final timeParts = parts[1].split(':');
    
    if (dateParts.length != 3 || timeParts.length != 2) return DateTime.now();
    
    try {
      return DateTime(
        int.parse(dateParts[2]), // Yıl
        int.parse(dateParts[1]), // Ay
        int.parse(dateParts[0]), // Gün
        int.parse(timeParts[0]), // Saat
        int.parse(timeParts[1]), // Dakika
      );
    } catch (e) {
      return DateTime.now();
    }
  }
}

class EventDetailResponse {
  final bool error;
  final bool success;
  final Event? data;
  final String? errorMessage;

  EventDetailResponse({
    required this.error,
    required this.success,
    this.data,
    this.errorMessage,
  });

  factory EventDetailResponse.fromJson(Map<String, dynamic> json) {
    return EventDetailResponse(
      error: json['error'] ?? false,
      success: json['success'] ?? false,
      data: json['data'] != null ? Event.fromJson(json['data']) : null,
      errorMessage: json['errorMessage'],
    );
  }
} 