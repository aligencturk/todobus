import 'package:flutter/material.dart';
import '../models/group_models.dart';
import '../services/api_service.dart';
import '../services/logger_service.dart';

enum GroupLoadStatus { initial, loading, loaded, error }

class GroupViewModel with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final LoggerService _logger = LoggerService();
  
  GroupLoadStatus _status = GroupLoadStatus.initial;
  String _errorMessage = '';
  List<Group> _groups = [];
  
  // Getters
  GroupLoadStatus get status => _status;
  String get errorMessage => _errorMessage;
  List<Group> get groups => _groups;
  bool get hasGroups => _groups.isNotEmpty;
  int get totalProjects => _groups.fold(0, (sum, group) => sum + group.projects.length);
  
  // Grup listesini yükle
  Future<void> loadGroups() async {
    if (_status == GroupLoadStatus.loading) return;
    
    try {
      _status = GroupLoadStatus.loading;
      _errorMessage = '';
      notifyListeners();
      
      _logger.i('Grup listesi yükleniyor');
      final groups = await _apiService.getGroups();
      
      _groups = groups;
      _status = GroupLoadStatus.loaded;
      _logger.i('${_groups.length} grup yüklendi');
    } catch (e) {
      _status = GroupLoadStatus.error;
      _errorMessage = e.toString();
      _logger.e('Gruplar yüklenirken hata: $e');
    } finally {
      notifyListeners();
    }
  }
  
  // Grup oluşturma
  Future<bool> createGroup(String groupName, String groupDesc) async {
    try {
      _status = GroupLoadStatus.loading;
      _errorMessage = '';
      notifyListeners();
      
      final success = await _apiService.createGroup(groupName, groupDesc);
      
      if (success) {
        // Grup başarıyla oluşturulduğunda grupları yeniden yükle
        await loadGroups();
        return true;
      }
      
      return false;
    } catch (e) {
      _status = GroupLoadStatus.error;
      _errorMessage = e.toString();
      _logger.e('Grup oluşturulurken hata: $e');
      notifyListeners();
      return false;
    }
  }
  
  // Grup güncelleme
  Future<bool> updateGroup(int groupID, String groupName, String groupDesc) async {
    try {
      _status = GroupLoadStatus.loading;
      _errorMessage = '';
      notifyListeners();
      
      final success = await _apiService.updateGroup(groupID, groupName, groupDesc);
      
      if (success) {
        // Grup başarıyla güncellendiğinde grupları yeniden yükle
        await loadGroups();
        return true;
      }
      
      return false;
    } catch (e) {
      _status = GroupLoadStatus.error;
      _errorMessage = e.toString();
      _logger.e('Grup güncellenirken hata: $e');
      notifyListeners();
      return false;
    }
  }
  
  // Grupları adlarına göre sırala (A-Z)
  void sortGroupsByName() {
    _groups.sort((a, b) => a.groupName.compareTo(b.groupName));
    notifyListeners();
  }
  
  // Grupları oluşturma tarihine göre sırala (yeniden eskiye)
  void sortGroupsByDate() {
    _groups.sort((a, b) => b.createDate.compareTo(a.createDate));
    notifyListeners();
  }
  
  // Grupları proje sayısına göre sırala (çoktan aza)
  void sortGroupsByProjectCount() {
    _groups.sort((a, b) => b.projects.length.compareTo(a.projects.length));
    notifyListeners();
  }
  
  // Gruptan kullanıcı çıkar
  Future<bool> removeUserFromGroup(int groupID, int userID) async {
    try {
      _status = GroupLoadStatus.loading;
      _errorMessage = '';
      notifyListeners();
      
      final success = await _apiService.removeUserFromGroup(groupID, userID);
      
      if (success) {
        // Başarı durumunda grupları yeniden yükle
        await loadGroups();
        return true;
      }
      
      return false;
    } catch (e) {
      _status = GroupLoadStatus.error;
      _errorMessage = e.toString();
      _logger.e('Kullanıcı gruptan çıkarılırken hata: $e');
      notifyListeners();
      return false;
    }
  }
  
  // Kullanıcı davet et
  Future<Map<String, dynamic>> inviteUserToGroup(
    int groupID, 
    String userEmail, 
    int userRole, 
    String inviteType
  ) async {
    try {
      _status = GroupLoadStatus.loading;
      _errorMessage = '';
      notifyListeners();
      
      final result = await _apiService.inviteUserToGroup(
        groupID, 
        userEmail, 
        userRole, 
        inviteType
      );
      
      _status = GroupLoadStatus.loaded;
      notifyListeners();
      
      return result;
    } catch (e) {
      _status = GroupLoadStatus.error;
      _errorMessage = e.toString();
      _logger.e('Kullanıcı davet edilirken hata: $e');
      notifyListeners();
      return {'success': false, 'error': e.toString()};
    }
  }
  
  // Grup silme
  Future<bool> deleteGroup(int groupID) async {
    try {
      _status = GroupLoadStatus.loading;
      _errorMessage = '';
      notifyListeners();
      
      final success = await _apiService.deleteGroup(groupID);
      
      if (success) {
        // Grup başarıyla silindiğinde grupları yeniden yükle
        await loadGroups();
        return true;
      }
      
      return false;
    } catch (e) {
      _status = GroupLoadStatus.error;
      _errorMessage = e.toString();
      _logger.e('Grup silinirken hata: $e');
      notifyListeners();
      return false;
    }
  }
  
  // Grup raporları (logları) getir
  Future<List<GroupLog>> getGroupReports(int groupID, bool isAdmin) async {
    try {
      _status = GroupLoadStatus.loading;
      notifyListeners();
      
      final reports = await _apiService.getGroupReports(groupID, isAdmin);
      
      _status = GroupLoadStatus.loaded;
      notifyListeners();
      
      return reports;
    } catch (e) {
      _status = GroupLoadStatus.error;
      _errorMessage = e.toString();
      _logger.e('Grup raporları yüklenirken hata: $e');
      notifyListeners();
      return [];
    }
  }
  
  // Proje detaylarını getir
  Future<ProjectDetail?> getProjectDetail(int projectID, int groupID) async {
    try {
      _status = GroupLoadStatus.loading;
      notifyListeners();
      
      final projectDetail = await _apiService.getProjectDetail(projectID, groupID);
      
      _status = GroupLoadStatus.loaded;
      notifyListeners();
      
      return projectDetail;
    } catch (e) {
      _status = GroupLoadStatus.error;
      _errorMessage = e.toString();
      _logger.e('Proje detayları yüklenirken hata: $e');
      notifyListeners();
      return null;
    }
  }
  
  // Proje oluştur
  Future<bool> createProject(
    int groupID, 
    String projectName, 
    String projectDesc, 
    String projectStartDate, 
    String projectEndDate, 
    List<Map<String, dynamic>> users,
    int projectStatus,
  ) async {
    try {
      _status = GroupLoadStatus.loading;
      _errorMessage = '';
      notifyListeners();
      
      final success = await _apiService.createProject(
        groupID, 
        projectName, 
        projectDesc, 
        projectStartDate, 
        projectEndDate, 
        users,
        projectStatus,
      );
      
      _status = GroupLoadStatus.loaded;
      notifyListeners();
      
      return success;
    } catch (e) {
      _status = GroupLoadStatus.error;
      _errorMessage = e.toString();
      _logger.e('Proje oluşturulurken hata: $e');
      notifyListeners();
      return false;
    }
  }
  
  // Proje güncelle
  Future<bool> updateProject(
    int groupID, 
    int projectID, 
    int projectStatus,
    String projectName, 
    String projectDesc, 
    String projectStartDate, 
    String projectEndDate
  ) async {
    try {
      _status = GroupLoadStatus.loading;
      _errorMessage = '';
      notifyListeners();
      
      final success = await _apiService.updateProject(
        groupID, 
        projectID, 
        projectStatus,
        projectName, 
        projectDesc, 
        projectStartDate, 
        projectEndDate
      );
      
      _status = GroupLoadStatus.loaded;
      notifyListeners();
      
      return success;
    } catch (e) {
      _status = GroupLoadStatus.error;
      _errorMessage = e.toString();
      _logger.e('Proje güncellenirken hata: $e');
      notifyListeners();
      return false;
    }
  }
  
  // Projeden kullanıcı çıkar
  Future<bool> removeUserFromProject(int groupID, int projectID, int userID) async {
    try {
      _status = GroupLoadStatus.loading;
      _errorMessage = '';
      notifyListeners();
      
      final success = await _apiService.removeUserFromProject(groupID, projectID, userID);
      
      if (success) {
        _status = GroupLoadStatus.loaded;
        notifyListeners();
        return true;
      }
      
      return false;
    } catch (e) {
      _status = GroupLoadStatus.error;
      _errorMessage = e.toString();
      _logger.e('Kullanıcı projeden çıkarılırken hata: $e');
      notifyListeners();
      return false;
    }
  }
  
  // Proje görevlerini getir
  Future<List<ProjectWork>> getProjectWorks(int projectID) async {
    try {
      _status = GroupLoadStatus.loading;
      notifyListeners();
      
      final works = await _apiService.getProjectWorks(projectID);
      
      _status = GroupLoadStatus.loaded;
      notifyListeners();
      
      return works;
    } catch (e) {
      _status = GroupLoadStatus.error;
      _errorMessage = e.toString();
      _logger.e('Proje görevleri yüklenirken hata: $e');
      notifyListeners();
      return [];
    }
  }
  
  // Görev detayını getir
  Future<ProjectWork?> getWorkDetail(int projectID, int workID) async {
    try {
      _status = GroupLoadStatus.loading;
      notifyListeners();
      
      final workDetail = await _apiService.getWorkDetail(projectID, workID);
      
      _status = GroupLoadStatus.loaded;
      notifyListeners();
      
      return workDetail;
    } catch (e) {
      _status = GroupLoadStatus.error;
      _errorMessage = e.toString();
      _logger.e('Görev detayı yüklenirken hata: $e');
      notifyListeners();
      return null;
    }
  }

  // Proje sil
  Future<bool> deleteProject(int projectID, int workID) async {
    try {
      _status = GroupLoadStatus.loading;
      _errorMessage = '';
      notifyListeners();  

      final success = await _apiService.deleteProject(projectID, workID);
      
      if (success) {
        _status = GroupLoadStatus.loaded;
        notifyListeners();  
        return true;
      }
      
      return false;
    } catch (e) {
      _status = GroupLoadStatus.error;
      _errorMessage = e.toString(); 
      _logger.e('Proje silinirken hata: $e');
      notifyListeners();
      return false;
    }
  }
  
  // Proje durumlarını getir
  Future<List<ProjectStatus>> getProjectStatuses() async {
    try {
      _status = GroupLoadStatus.loading;
      notifyListeners();
      
      final statuses = await _apiService.getProjectStatuses();
      
      _status = GroupLoadStatus.loaded;
      notifyListeners();
      
      return statuses;
    } catch (e) {
      _status = GroupLoadStatus.error;
      _errorMessage = e.toString();
      _logger.e('Proje durumları yüklenirken hata: $e');
      notifyListeners();
      return [];
    }
  }
  
  // Projeye görev ekle
  Future<bool> addProjectWork(
    int projectID,
    String workName,
    String workDesc,
    String workStartDate,
    String workEndDate,
    List<int> users
  ) async {
    try {
      _status = GroupLoadStatus.loading;
      _errorMessage = '';
      notifyListeners();
      
      final success = await _apiService.addProjectWork(
        projectID,
        workName,
        workDesc,
        workStartDate,
        workEndDate,
        users
      );
      
      _status = GroupLoadStatus.loaded;
      notifyListeners();
      
      return success;
    } catch (e) {
      _status = GroupLoadStatus.error;
      _errorMessage = e.toString();
      _logger.e('Görev eklenirken hata: $e');
      notifyListeners();
      return false;
    }
  }
  
  // Görev güncelle
  Future<bool> updateProjectWork(
    int projectID,
    int workID,
    String workName,
    String workDesc,
    String workStartDate,
    String workEndDate,
    bool isCompleted,
    List<int> users
  ) async {
    try {
      _status = GroupLoadStatus.loading;
      _errorMessage = '';
      notifyListeners();
      
      final success = await _apiService.updateProjectWork(
        projectID,
        workID,
        workName,
        workDesc,
        workStartDate,
        workEndDate,
        isCompleted ? 1 : 0,
        users
      );
      
      _status = GroupLoadStatus.loaded;
      notifyListeners();
      
      return success;
    } catch (e) {
      _status = GroupLoadStatus.error;
      _errorMessage = e.toString();
      _logger.e('Görev güncellenirken hata: $e');
      notifyListeners();
      return false;
    }
  }
  
  // Görev durumunu değiştir (tamamlandı/tamamlanmadı)
  Future<bool> changeWorkCompletionStatus(int projectID, int workID, bool isCompleted) async {
    try {
      _status = GroupLoadStatus.loading;
      _errorMessage = '';
      notifyListeners();
      
      final success = await _apiService.changeWorkCompletionStatus(
        projectID,
        workID,
        isCompleted
      );
      
      _status = GroupLoadStatus.loaded;
      notifyListeners();
      
      return success;
    } catch (e) {
      _status = GroupLoadStatus.error;
      _errorMessage = e.toString();
      _logger.e('Görev durumu değiştirilirken hata: $e');
      notifyListeners();
      return false;
    }
  }
  
  // Durumu sıfırla
  void reset() {
    _status = GroupLoadStatus.initial;
    _errorMessage = '';
    _groups = [];
    notifyListeners();
  }

} 