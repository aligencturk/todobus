import 'dart:async';
import 'package:flutter/material.dart';
import '../models/group_models.dart';
import '../services/api_service.dart';
import '../services/logger_service.dart';
import '../services/storage_service.dart';
import '../services/refresh_service.dart';

enum GroupLoadStatus { initial, loading, loaded, error }

class GroupViewModel with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final LoggerService _logger = LoggerService();
  final StorageService _storageService = StorageService();
  final RefreshService _refreshService = RefreshService();
  
  GroupLoadStatus _status = GroupLoadStatus.initial;
  String _errorMessage = '';
  List<Group> _groups = [];
  bool _isDisposed = false;
  bool _isLoadingFromApi = false;
  StreamSubscription? _refreshSubscription;
  
  // Proje durumları için önbellek
  List<ProjectStatus> _cachedProjectStatuses = [];
  
  // Getters
  GroupLoadStatus get status => _status;
  String get errorMessage => _errorMessage;
  List<Group> get groups => _groups;
  bool get hasGroups => _groups.isNotEmpty;
  int get totalProjects => _groups.fold(0, (sum, group) => sum + group.projects.length);
  List<ProjectStatus> get cachedProjectStatuses => _cachedProjectStatuses;
  
  GroupViewModel() {
    _initRefreshListener();
  }
  
  void _initRefreshListener() {
    _refreshSubscription = _refreshService.refreshStream.listen((refreshType) {
      if (refreshType == 'groups' || refreshType == 'all') {
        loadGroups();
      }
    });
  }
  
  // Güvenli notifyListeners
  void _safeNotifyListeners() {
    if (!_isDisposed) {
      Future.microtask(() => notifyListeners());
    }
  }
  
  @override
  void dispose() {
    _isDisposed = true;
    _refreshSubscription?.cancel();
    super.dispose();
  }
  
  // Grup listesini yükle
  Future<void> loadGroups() async {
    // Eğer yükleme zaten devam ediyorsa, yeni bir yükleme başlatma
    if (_isLoadingFromApi) return;
    
    try {
      _status = GroupLoadStatus.loading;
      _safeNotifyListeners();
      
      // Her zaman API'den yükle, önbellekten alma
      await _loadGroupsFromApi();
    } catch (e) {
      _status = GroupLoadStatus.error;
      _errorMessage = "Gruplar yüklenirken bir hata oluştu: ${e.toString()}";
      _logger.e('Gruplar yüklenirken hata: $e');
      _safeNotifyListeners();
    }
  }
  
  // API'den grupları yükle
  Future<void> _loadGroupsFromApi() async {
    if (_isLoadingFromApi) return;
    
    _isLoadingFromApi = true;
    try {
      _logger.i('Grup listesi API\'den yükleniyor');
      final groups = await _apiService.group.getGroups();
      
      _groups = groups;
      _status = GroupLoadStatus.loaded;
      
      // Önbelleğe kaydetmeyi kaldırdık
      
      _logger.i('${_groups.length} grup yüklendi');
      _safeNotifyListeners();
    } catch (e) {
      // API'den yükleme sırasında hata
      _status = GroupLoadStatus.error;
      _errorMessage = "Gruplar yüklenirken bir hata oluştu: ${e.toString()}";
      _logger.e('Gruplar API\'den yüklenirken hata: $e');
      _safeNotifyListeners();
    } finally {
      _isLoadingFromApi = false;
    }
  }
  
  // Grup oluşturma
  Future<bool> createGroup(String groupName, String groupDesc) async {
    try {
      // Durum güncellemesi sadece UI'ı bloke etmek için kullanılıyor, 
      // veri varsa silinmiyor
      final previousStatus = _status;
      final previousGroups = List<Group>.from(_groups);
      
      _status = GroupLoadStatus.loading;
      _errorMessage = '';
      _safeNotifyListeners();
      
      final success = await _apiService.group.createGroup(groupName, groupDesc);
      
      if (success) {
        // Grup başarıyla oluşturulduğunda grupları yeniden yükle
        await _loadGroupsFromApi();
        // Tüm uygulamaya bildirim gönder
        _refreshService.refreshGroups();
        return true;
      } else {
        // Başarısız olursa önceki duruma geri dön
        _status = previousStatus;
        _groups = previousGroups;
        _safeNotifyListeners();
        return false;
      }
    } catch (e) {
      _status = GroupLoadStatus.error;
      _errorMessage = "Grup oluşturulurken bir hata oluştu: ${e.toString()}";
      _logger.e('Grup oluşturulurken hata: $e');
      _safeNotifyListeners();
      return false;
    }
  }
  
  // Grup güncelleme
  Future<bool> updateGroup(int groupID, String groupName, String groupDesc) async {
    try {
      final previousStatus = _status;
      final previousGroups = List<Group>.from(_groups);
      
      _status = GroupLoadStatus.loading;
      _errorMessage = '';
      _safeNotifyListeners();
      
      final success = await _apiService.group.updateGroup(groupID, groupName, groupDesc);
      
      if (success) {
        // Grup başarıyla güncellendiğinde grupları yeniden yükle
        await _loadGroupsFromApi();
        // Tüm uygulamaya bildirim gönder
        _refreshService.refreshGroups();
        return true;
      } else {
        // Başarısız olursa önceki duruma geri dön
        _status = previousStatus;
        _groups = previousGroups;
        _safeNotifyListeners();
        return false;
      }
    } catch (e) {
      _status = GroupLoadStatus.error;
      _errorMessage = "Grup güncellenirken bir hata oluştu: ${e.toString()}";
      _logger.e('Grup güncellenirken hata: $e');
      _safeNotifyListeners();
      return false;
    }
  }
  
  // Grupları adlarına göre sırala (A-Z)
  void sortGroupsByName() {
    _groups.sort((a, b) => a.groupName.compareTo(b.groupName));
    _safeNotifyListeners();
  }
  
  // Grupları oluşturma tarihine göre sırala (yeniden eskiye)
  void sortGroupsByDate() {
    _groups.sort((a, b) => b.createDate.compareTo(a.createDate));
    _safeNotifyListeners();
  }
  
  // Grupları proje sayısına göre sırala (çoktan aza)
  void sortGroupsByProjectCount() {
    _groups.sort((a, b) => b.projects.length.compareTo(a.projects.length));
    _safeNotifyListeners();
  }
  
  // Gruptan kullanıcı çıkar
  Future<bool> removeUserFromGroup(int groupID, int userID) async {
    try {
      _status = GroupLoadStatus.loading;
      _errorMessage = '';
      _safeNotifyListeners();
      
      final success = await _apiService.group.removeUserFromGroup(groupID, userID);
      
      if (success) {
        // Başarı durumunda grupları yeniden yükle
        await loadGroups();
        // Tüm uygulamaya bildirim gönder
        _refreshService.refreshGroups();
        return true;
      }
      
      return false;
    } catch (e) {
      _status = GroupLoadStatus.error;
      _errorMessage = e.toString();
      _logger.e('Kullanıcı gruptan çıkarılırken hata: $e');
      _safeNotifyListeners();
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
      _safeNotifyListeners();
      
      final result = await _apiService.group.inviteUserToGroup(
        groupID, 
        userEmail, 
        userRole, 
        inviteType
      );
      
      _status = GroupLoadStatus.loaded;
      _safeNotifyListeners();
      
      return result;
    } catch (e) {
      _status = GroupLoadStatus.error;
      _errorMessage = e.toString();
      _logger.e('Kullanıcı davet edilirken hata: $e');
      _safeNotifyListeners();
      return {'success': false, 'error': e.toString()};
    }
  }
  
  // Grup silme
  Future<bool> deleteGroup(int groupID) async {
    try {
      final previousStatus = _status;
      final previousGroups = List<Group>.from(_groups);
      
      _status = GroupLoadStatus.loading;
      _errorMessage = '';
      _safeNotifyListeners();
      
      final success = await _apiService.group.deleteGroup(groupID);
      
      if (success) {
        // Grup başarıyla silindiğinde grupları yeniden yükle
        await _loadGroupsFromApi();
        // Tüm uygulamaya bildirim gönder
        _refreshService.refreshGroups();
        return true;
      } else {
        // Başarısız olursa önceki duruma geri dön
        _status = previousStatus;
        _groups = previousGroups;
        _safeNotifyListeners();
        return false;
      }
    } catch (e) {
      _status = GroupLoadStatus.error;
      _errorMessage = "Grup silinirken bir hata oluştu: ${e.toString()}";
      _logger.e('Grup silinirken hata: $e');
      _safeNotifyListeners();
      return false;
    }
  }
  
  // Grup raporları (logları) getir
  Future<List<GroupLog>> getGroupReports(int groupID, bool isAdmin) async {
    try {
      _status = GroupLoadStatus.loading;
      _safeNotifyListeners();
      
      try {
        final reports = await _apiService.group.getGroupReports(groupID, isAdmin);
        
        _status = GroupLoadStatus.loaded;
        _safeNotifyListeners();
        
        return reports;
      } catch (e) {
        // Hata durumunda sessizce boş liste dön, hata durumunu gösterme
        _logger.e('Grup raporları yüklenirken hata: $e'); // Sadece log'a yaz
        _status = GroupLoadStatus.loaded; // Loaded olarak işaretle, error değil
        _safeNotifyListeners();
        return []; // Boş liste dön
      }
    } catch (e) {
      // En dıştaki try-catch bloğu da boş liste dönsün
      _logger.e('Grup raporları işlenirken beklenmeyen hata: $e');
      _status = GroupLoadStatus.loaded; // Loaded olarak işaretle
      _safeNotifyListeners();
      return [];
    }
  }
  
  // Proje detaylarını getir
  Future<ProjectDetail?> getProjectDetail(int projectID, int groupID) async {
    try {
      _status = GroupLoadStatus.loading;
      _safeNotifyListeners();
      
      final projectDetail = await _apiService.project.getProjectDetail(projectID, groupID);
      
      _status = GroupLoadStatus.loaded;
      _safeNotifyListeners();
      
      return projectDetail;
    } catch (e) {
      _status = GroupLoadStatus.error;
      _errorMessage = e.toString();
      _logger.e('Proje detayları yüklenirken hata: $e');
      _safeNotifyListeners();
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
      _safeNotifyListeners();
      
      final success = await _apiService.project.createProject(
        groupID, 
        projectName, 
        projectDesc, 
        projectStartDate, 
        projectEndDate, 
        users,
        projectStatus,
      );
      
      _status = GroupLoadStatus.loaded;
      _safeNotifyListeners();
      
      if (success) {
        // Başarılı olduğunda verileri yenile
        await loadGroups();
        // Tüm uygulamaya bildirim gönder
        _refreshService.refreshProjects();
        _refreshService.refreshGroups();
      }
      
      return success;
    } catch (e) {
      _status = GroupLoadStatus.error;
      _errorMessage = e.toString();
      _logger.e('Proje oluşturulurken hata: $e');
      _safeNotifyListeners();
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
      _safeNotifyListeners();
      
      final success = await _apiService.project.updateProject(
        groupID, 
        projectID, 
        projectStatus,
        projectName, 
        projectDesc, 
        projectStartDate, 
        projectEndDate
      );
      
      _status = GroupLoadStatus.loaded;
      _safeNotifyListeners();
      
      if (success) {
        // Başarılı olduğunda verileri yenile
        await loadGroups();
        // Tüm uygulamaya bildirim gönder
        _refreshService.refreshProjects();
        _refreshService.refreshGroups();
      }
      
      return success;
    } catch (e) {
      _status = GroupLoadStatus.error;
      _errorMessage = e.toString();
      _logger.e('Proje güncellenirken hata: $e');
      _safeNotifyListeners();
      return false;
    }
  }
  
  // Projeden kullanıcı çıkar
  Future<bool> removeUserFromProject(int groupID, int projectID, int userID) async {
    try {
      _status = GroupLoadStatus.loading;
      _errorMessage = '';
      _safeNotifyListeners();
      
      final success = await _apiService.project.removeUserFromProject(groupID, projectID, userID);
      
      if (success) {
        _status = GroupLoadStatus.loaded;
        _safeNotifyListeners();
        return true;
      }
      
      return false;
    } catch (e) {
      _status = GroupLoadStatus.error;
      _errorMessage = e.toString();
      _logger.e('Kullanıcı projeden çıkarılırken hata: $e');
      _safeNotifyListeners();
      return false;
    }
  }
  
  // Proje görevlerini getir
  Future<List<ProjectWork>> getProjectWorks(int projectID) async {
    try {
      _status = GroupLoadStatus.loading;
      _safeNotifyListeners();
      
      try {
        final works = await _apiService.project.getProjectWorks(projectID);
        
        _status = GroupLoadStatus.loaded;
        _safeNotifyListeners();
        
        return works;
      } catch (e) {
        // 417 kodunu içeren hatalar, görev olmadığını belirtiyor, bu normal bir durum
        if (e.toString().contains('417') || e.toString().contains('Bu projeye ait henüz görev bulunmamaktadır')) {
          _status = GroupLoadStatus.loaded; // Hata değil, sadece veri yok
          _safeNotifyListeners();
          return []; // Boş liste dön
        }
        rethrow; // Diğer hataları yeniden fırlat
      }
    } catch (e) {
      _status = GroupLoadStatus.error;
      _errorMessage = e.toString();
      _logger.e('Proje görevleri yüklenirken hata: $e');
      _safeNotifyListeners();
      return [];
    }
  }
  
  // Görev detayını getir
  Future<ProjectWork?> getWorkDetail(int projectID, int workID) async {
    try {
      _status = GroupLoadStatus.loading;
      _safeNotifyListeners();
      
      final workDetail = await _apiService.project.getWorkDetail(projectID, workID);
      
      _status = GroupLoadStatus.loaded;
      _safeNotifyListeners();
      
      return workDetail;
    } catch (e) {
      _status = GroupLoadStatus.error;
      _errorMessage = e.toString();
      _logger.e('Görev detayı yüklenirken hata: $e');
      _safeNotifyListeners();
      return null;
    }
  }
  
  // Proje sil
  Future<bool> deleteProject(int projectID, int workID) async {
    try {
      _status = GroupLoadStatus.loading;
      _errorMessage = '';
      _safeNotifyListeners();  

      final success = await _apiService.project.deleteProjectWork(projectID, workID);
      
      if (success) {
        _status = GroupLoadStatus.loaded;
        _safeNotifyListeners();  
        return true;
      }
      
      return false;
    } catch (e) {
      _status = GroupLoadStatus.error;
      _errorMessage = e.toString(); 
      _logger.e('Proje silinirken hata: $e');
      _safeNotifyListeners();
      return false;
    }
  }
  
  // Proje durumlarını getir
  Future<List<ProjectStatus>> getProjectStatuses() async {
    try {
      // Her zaman API'den yeni durumları alalım
      _cachedProjectStatuses = []; // Önbelleği temizle
      _logger.i('Proje durumları için API çağrısı yapılıyor, önbellek temizlendi');
      
      _status = GroupLoadStatus.loading;
      _safeNotifyListeners();
      
      final statuses = await _apiService.project.getProjectStatuses();
      
      if (statuses.isEmpty) {
        _logger.w('API\'den boş proje durumları listesi alındı');
      } else {
        _logger.i('${statuses.length} proje durumu API\'den alındı');
        
        // Durum ID'lerini ve renklerini logla
        for (var status in statuses) {
          _logger.i('Durum ID: ${status.statusID}, Ad: ${status.statusName}, Renk: ${status.statusColor}');
        }
      }
      
      // Önbelleğe al
      _cachedProjectStatuses = statuses;
      
      _status = GroupLoadStatus.loaded;
      _safeNotifyListeners();
      
      return statuses;
    } catch (e) {
      _status = GroupLoadStatus.error;
      _errorMessage = e.toString();
      _logger.e('Proje durumları yüklenirken hata: $e');
      _safeNotifyListeners();
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
      _safeNotifyListeners();
      
      final success = await _apiService.project.addProjectWork(
        projectID,
        workName,
        workDesc,
        workStartDate,
        workEndDate,
        users
      );
      
      _status = GroupLoadStatus.loaded;
      _safeNotifyListeners();
      
      return success;
    } catch (e) {
      _status = GroupLoadStatus.error;
      _errorMessage = e.toString();
      _logger.e('Görev eklenirken hata: $e');
      _safeNotifyListeners();
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
      _safeNotifyListeners();
      
      final success = await _apiService.project.updateProjectWork(
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
      _safeNotifyListeners();
      
      return success;
    } catch (e) {
      _status = GroupLoadStatus.error;
      _errorMessage = e.toString();
      _logger.e('Görev güncellenirken hata: $e');
      _safeNotifyListeners();
      return false;
    }
  }
  
  // Görev durumunu değiştir (tamamlandı/tamamlanmadı)
  Future<bool> changeWorkCompletionStatus(int projectID, int workID, bool isCompleted) async {
    try {
      _status = GroupLoadStatus.loading;
      _errorMessage = '';
      _safeNotifyListeners();
      
      final success = await _apiService.project.changeWorkCompletionStatus(
        projectID,
        workID,
        isCompleted
      );
      
      _status = GroupLoadStatus.loaded;
      _safeNotifyListeners();
      
      return success;
    } catch (e) {
      _status = GroupLoadStatus.error;
      _errorMessage = e.toString();
      _logger.e('Görev durumu değiştirilirken hata: $e');
      _safeNotifyListeners();
      return false;
    }
  }
  
  // Durumu sıfırla
  void reset() {
    _status = GroupLoadStatus.initial;
    _errorMessage = '';
    _groups = [];
    _isLoadingFromApi = false;
    _safeNotifyListeners();
  }
} 