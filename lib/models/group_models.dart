class GroupListResponse {
  final bool error;
  final bool success;
  final GroupListData? data;
  final String? errorMessage;

  GroupListResponse({
    required this.error,
    required this.success,
    this.data,
    this.errorMessage,
  });

  factory GroupListResponse.fromJson(Map<String, dynamic> json) {
    return GroupListResponse(
      error: json['error'] ?? false,
      success: json['success'] ?? false,
      data: json['data'] != null ? GroupListData.fromJson(json['data']) : null,
      errorMessage: json['errorMessage'],
    );
  }
}

class GroupListData {
  final List<Group> groups;

  GroupListData({required this.groups});

  factory GroupListData.fromJson(Map<String, dynamic> json) {
    List<Group> groupsList = [];
    if (json['groups'] != null) {
      groupsList = List<Group>.from(
          json['groups'].map((group) => Group.fromJson(group)));
    }
    return GroupListData(groups: groupsList);
  }
}

class Group {
  final int groupID;
  final String groupName;
  final String groupDesc;
  final String createdBy;
  final String packageName;
  final String packageExpires;
  final String createDate;
  final bool isFree;
  final bool isAdmin;
  final List<Project> projects;

  Group({
    required this.groupID,
    required this.groupName,
    required this.groupDesc,
    required this.createdBy,
    required this.packageName,
    required this.packageExpires,
    required this.createDate,
    required this.isFree,
    required this.isAdmin,
    required this.projects,
  });

  factory Group.fromJson(Map<String, dynamic> json) {
    List<Project> projectsList = [];
    if (json['projects'] != null) {
      projectsList = List<Project>.from(
          json['projects'].map((project) => Project.fromJson(project)));
    }
    return Group(
      groupID: json['groupID'] ?? 0,
      groupName: json['groupName'] ?? '',
      groupDesc: json['groupDesc'] ?? '',
      createdBy: json['createdBy'] ?? '',
      packageName: json['packageName'] ?? '',
      packageExpires: json['packageExpires'] ?? '',
      createDate: json['createDate'] ?? '',
      isFree: json['isFree'] ?? false,
      isAdmin: json['isAdmin'] ?? false,
      projects: projectsList,
    );
  }
}

class Project {
  final int projectID;
  final String projectName;
  final String projectStatus;
  final int projectStatusID;

  Project({
    required this.projectID,
    required this.projectName,
    required this.projectStatus,
    required this.projectStatusID,
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      projectID: json['projectID'] ?? 0,
      projectName: json['projectName'] ?? '',
      projectStatus: json['projectStatus'] ?? '',
      projectStatusID: json['projectStatusID'] ?? 0,
    );
  }
}

class GroupDetail {
  final int groupID;
  final String groupName;
  final String groupDesc;
  final String createdBy;
  final String packageName;
  final int packMaxUsers;
  final int packMaxProjects;
  final String packPrice;
  final String packageExpires;
  final String createDate;
  final int totalUsers;
  final bool isFree;
  final bool isAddUser;
  final bool isAddProject;
  final List<GroupUser> users;
  final List<Project> projects;
  final List<GroupEvent> events;

  GroupDetail({
    required this.groupID,
    required this.groupName,
    required this.groupDesc,
    required this.createdBy,
    required this.packageName,
    required this.packMaxUsers,
    required this.packMaxProjects,
    required this.packPrice,
    required this.packageExpires,
    required this.createDate,
    required this.totalUsers,
    required this.isFree,
    required this.isAddUser,
    required this.isAddProject,
    required this.users,
    required this.projects,
    required this.events,
  });

  factory GroupDetail.fromJson(Map<String, dynamic> json) {
    return GroupDetail(
      groupID: json['groupID'] ?? 0,
      groupName: json['groupName'] ?? '',
      groupDesc: json['groupDesc'] ?? '',
      createdBy: json['createdBy'] ?? '',
      packageName: json['packageName'] ?? '',
      packMaxUsers: json['packMaxUsers'] ?? 0,
      packMaxProjects: json['packMaxProjects'] ?? 0,
      packPrice: json['packPrice'] ?? '',
      packageExpires: json['packageExpires'] ?? '',
      createDate: json['createDate'] ?? '',
      totalUsers: json['totalUsers'] ?? 0,
      isFree: json['isFree'] ?? false,
      isAddUser: json['isAddUser'] ?? false,
      isAddProject: json['isAddProject'] ?? false,
      users: (json['users'] as List<dynamic>?)
              ?.map((user) => GroupUser.fromJson(user))
              .toList() ??
          [],
      projects: (json['projects'] as List<dynamic>?)
              ?.map((project) => Project.fromJson(project))
              .toList() ??
          [],
      events: (json['events'] as List<dynamic>?)
              ?.map((event) => GroupEvent.fromJson(event))
              .toList() ??
          [],
    );
  }
}

class GroupUser {
  final int groupUID;
  final int userID;
  final String userName;
  final int userRoleID;
  final String userRole;
  final String joinedDate;
  final bool isAdmin;

  GroupUser({
    required this.groupUID,
    required this.userID,
    required this.userName,
    required this.userRoleID,
    required this.userRole,
    required this.joinedDate,
    required this.isAdmin,
  });

  factory GroupUser.fromJson(Map<String, dynamic> json) {
    return GroupUser(
      groupUID: json['groupUID'] ?? 0,
      userID: json['userID'] ?? 0,
      userName: json['userName'] ?? '',
      userRoleID: json['userRoleID'] ?? 0,
      userRole: json['userRole'] ?? '',
      joinedDate: json['joinedDate'] ?? '',
      isAdmin: json['isAdmin'] ?? false,
    );
  }
}

class GroupEvent {
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

  GroupEvent({
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
  });

  factory GroupEvent.fromJson(Map<String, dynamic> json) {
    return GroupEvent(
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