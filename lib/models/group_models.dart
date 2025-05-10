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