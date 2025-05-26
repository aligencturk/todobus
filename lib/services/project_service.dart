import '../models/group_models.dart';
import '../services/logger_service.dart';
import '../services/storage_service.dart';
import 'base_api_service.dart';

class ProjectService {
  static final ProjectService _instance = ProjectService._internal();
  final BaseApiService _apiService = BaseApiService();
  final StorageService _storageService = StorageService();
  final LoggerService _logger = LoggerService();

  factory ProjectService() {
    return _instance;
  }

  ProjectService._internal();

  // Proje detaylarını getir
  Future<ProjectDetail> getProjectDetail(int projectID, int groupID) async {
    try {
      final userToken = await _storageService.getToken();
      if (userToken == null) {
        throw Exception('Oturum bilgisi bulunamadı');
      }

      final response = await _apiService.post(
        'service/user/project/id',
        body: {
          'userToken': userToken,
          'projectID': projectID,
          'groupID': groupID,
        },
        requiresToken: true,
      );

      if (response['success'] == true && response['data'] != null) {
        final projectDetail = ProjectDetail.fromJson(response['data']);
        _logger.i('Proje detayları alındı: ${projectDetail.projectName}');
        return projectDetail;
      } else {
        throw Exception(response['errorMessage'] ?? 'Proje detayları alınamadı');
      }
    } catch (e) {
      _logger.e('Proje detayları alınırken hata: $e');
      throw Exception('Proje detayları alınamadı: $e');
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
      final userToken = _storageService.getToken();
      if (userToken == null) {
        throw Exception('Oturum bilgisi bulunamadı');
      }
      
      _logger.i('Proje oluşturuluyor: $projectName (GroupID: $groupID)');
      
      final response = await _apiService.post(
        'service/user/project/create',
        body: {
          'userToken': userToken,
          'groupID': groupID,
          'projectName': projectName,
          'projectDesc': projectDesc,
          'projectStartDate': projectStartDate,
          'projectEndDate': projectEndDate,
          'projectStatus': projectStatus,
          'users': users,
        },
        requiresToken: true,
      );
      
      if (response['success'] == true) {
        _logger.i('Proje başarıyla oluşturuldu');
        return true;
      } else {
        final errorMsg = response['message'] ?? 'Bilinmeyen hata';
        _logger.e('Proje oluşturulamadı: $errorMsg');
        throw Exception('Proje oluşturulamadı: $errorMsg');
      }
    } catch (e) {
      _logger.e('Proje oluşturulurken hata: $e');
      throw Exception('Proje oluşturulurken hata: $e');
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
      final userToken = _storageService.getToken();
      if (userToken == null) {
        throw Exception('Oturum bilgisi bulunamadı');
      }
      
      _logger.i('Proje güncelleniyor: ID: $projectID, Name: $projectName (GroupID: $groupID)');
      
      final response = await _apiService.put(
        'service/user/project/update',
        body: {
          'userToken': userToken,
          'groupID': groupID,
          'projectID': projectID,
          'projectStatus': projectStatus,
          'projectName': projectName,
          'projectDesc': projectDesc,
          'projectStartDate': projectStartDate,
          'projectEndDate': projectEndDate,
        },
        requiresToken: true,
      );
      
      if (response['success'] == true) {
        _logger.i('Proje başarıyla güncellendi');
        return true;
      } else {
        final errorMsg = response['message'] ?? 'Bilinmeyen hata';
        _logger.e('Proje güncellenemedi: $errorMsg');
        throw Exception('Proje güncellenemedi: $errorMsg');
      }
    } catch (e) {
      _logger.e('Proje güncellenirken hata: $e');
      throw Exception('Proje güncellenirken hata: $e');
    }
  }
  
  // Projeden kullanıcı çıkar
  Future<bool> removeUserFromProject(int groupID, int projectID, int userID) async {
    try {
      final userToken = _storageService.getToken();
      if (userToken == null) {
        throw Exception('Oturum bilgisi bulunamadı');
      }
      
      _logger.i('Projeden kullanıcı çıkarılıyor: ProjectID: $projectID, UserID: $userID (GroupID: $groupID)');
      
      final response = await _apiService.put(
        'service/user/group/userRemove',
        body: {
          'userToken': userToken,
          'groupID': groupID,
          'projectID': projectID,
          'userID': userID,
          'step': 'project',
        },
        requiresToken: true,
      );
      
      if (response['success'] == true) {
        _logger.i('Kullanıcı projeden başarıyla çıkarıldı');
        return true;
      } else {
        final errorMsg = response['message'] ?? 'Bilinmeyen hata';
        _logger.e('Kullanıcı projeden çıkarılamadı: $errorMsg');
        throw Exception('Kullanıcı projeden çıkarılamadı: $errorMsg');
      }
    } catch (e) {
      _logger.e('Kullanıcı projeden çıkarılırken hata: $e');
      throw Exception('Kullanıcı projeden çıkarılırken hata: $e');
    }
  }
  
  // Proje durumlarını getir
  Future<List<ProjectStatus>> getProjectStatuses() async {
    try {
      _logger.i('Proje durumları getiriliyor...');
      
      // Önbellek önlemek için timestamp parametresi ekle
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      final response = await _apiService.get(
        'service/general/general/proStatuses?t=$timestamp', // Önbellek önleme
        requiresToken: false,
      );
      
      if (response['success'] == true && response['data'] != null) {
        final projectStatusResponse = ProjectStatusResponse.fromJson(response);
        
        if (projectStatusResponse.data != null) {
          final statuses = projectStatusResponse.data!.statuses;
          _logger.i('${statuses.length} proje durumu alındı.');
          return statuses;
        }
      }
      
      _logger.w('Proje durumları alınamadı veya boş.');
      return [];
    } catch (e) {
      _logger.e('Proje durumları yüklenirken hata: $e');
      throw Exception('Proje durumları yüklenemedi: $e');
    }
  }
  
  // Proje görevlerini getir
  Future<List<ProjectWork>> getProjectWorks(int projectID) async {
    try {
      // 1) Token al
      final token = await _storageService.getToken();
      if (token == null) {
        throw Exception('Oturum bilgisi bulunamadı');
      }

      // 2) Body hazırla
      final body = {
        'userToken': token,
        'projectID': projectID,
      };

      _logger.i('Proje görevleri getiriliyor... ProjectID: $projectID');

      // 3) API çağrısı yap
      final response = await _apiService.post(
        'service/user/project/workList',
        body: body,
      );

      // API yanıt yapısı değişti, yeni formatı işle
      if (response['success'] == true && response['data'] != null) {
        if (response['data']['works'] != null) {
          final worksList = response['data']['works'] as List<dynamic>;
          
          // Görev listesini dönüştür
          final works = worksList
            .map((item) => ProjectWork.fromJson(item as Map<String, dynamic>))
            .toList();
          
          _logger.i('${works.length} proje görevi getirildi. ProjectID: $projectID');
          return works;
        } else {
          _logger.i('Projede görev bulunamadı (veri yapısı var ancak boş)');
          return []; // Boş liste
        }
      } else if (response['410'] == 'Gone') {
        // 410 Gone durumu - API'nin özel davranışı
        _logger.i('Proje için henüz görev bulunmuyor (410 Gone). ProjectID: $projectID');
        return [];
      }
      
      // Herhangi bir veri bulunamazsa boş liste dön
      _logger.i('API yanıtında geçerli veri bulunamadı. ProjectID: $projectID');
      return [];
    } catch (e) {
      _logger.e('Proje görevleri getirilirken hata oluştu. ProjectID: $projectID, Hata: $e');
      return []; // Hata durumunda boş liste dön
    }
  }

  // Görev detayını getir
  Future<ProjectWork> getWorkDetail(int projectID, int workID) async {
    try {
      _logger.i('Görev detayı getiriliyor... (ProjectID: $projectID, WorkID: $workID)');
      
      final token = await _storageService.getToken();
      if (token == null) {
        throw Exception('Kullanıcı token bilgisi bulunamadı');
      }
      
      final response = await _apiService.post(
        'service/user/project/workDetail',
        body: {
          'userToken': token,
          'projectID': projectID,
          'workID': workID,
        },
        requiresToken: true,
      );
      
      if (response['success'] == true && response['data'] != null) {
        final workDetail = ProjectWork.fromJson(response['data']);
        _logger.i('Görev detayı alındı: ${workDetail.workName}');
        return workDetail;
      } else {
        throw Exception(response['errorMessage'] ?? 'Görev detayı alınamadı');
      }
    } catch (e) {
      _logger.e('Görev detayı alınırken hata: $e');
      throw Exception('Görev detayı alınamadı: $e');
    }
  }
  
  // Projeye görev ekleme
  Future<bool> addProjectWork(
    int projectID,
    String workName,
    String workDesc,
    String workStartDate,
    String workEndDate,
    List<int> users
  ) async {
    try {
      _logger.i('Projeye görev ekleniyor: $workName (ProjectID: $projectID)');
      
      final token = await _storageService.getToken();
      if (token == null) {
        throw Exception('Kullanıcı token bilgisi bulunamadı');
      }
      
      final response = await _apiService.post(
        'service/user/project/addWork',
        body: {
          'userToken': token,
          'projectID': projectID,
          'workName': workName,
          'workDesc': workDesc,
          'workStartDate': workStartDate,
          'workEndDate': workEndDate,
          'users': users
        },
        requiresToken: true,
      );
      
      if (response['success'] == true) {
        _logger.i('Görev başarıyla eklendi');
        return true;
      } else {
        final errorMsg = response['message'] ?? 'Bilinmeyen hata';
        _logger.e('Görev eklenemedi: $errorMsg');
        throw Exception('Görev eklenemedi: $errorMsg');
      }
    } catch (e) {
      _logger.e('Görev eklenirken hata: $e');
      throw Exception('Görev eklenirken hata: $e');
    }
  }
  
  // Görev güncelleme
  Future<bool> updateProjectWork(
    int projectID,
    int workID,
    String workName,
    String workDesc,
    String workStartDate,
    String workEndDate,
    int isCompleted,
    List<int> users
  ) async {
    try {
      _logger.i('Görev güncelleniyor: ID: $workID, Name: $workName (ProjectID: $projectID)');
      
      final token = await _storageService.getToken();
      if (token == null) {
        throw Exception('Kullanıcı token bilgisi bulunamadı');
      }
      
      final response = await _apiService.put(
        'service/user/project/updateWork',
        body: {
          'userToken': token,
          'projectID': projectID,
          'workID': workID,
          'workName': workName,
          'workDesc': workDesc,
          'workStartDate': workStartDate,
          'workEndDate': workEndDate,
          'isComplated': isCompleted,
          'users': users
        },
        requiresToken: true,
      );
      
      if (response['success'] == true) {
        _logger.i('Görev başarıyla güncellendi');
        return true;
      } else {
        final errorMsg = response['message'] ?? 'Bilinmeyen hata';
        _logger.e('Görev güncellenemedi: $errorMsg');
        throw Exception('Görev güncellenemedi: $errorMsg');
      }
    } catch (e) {
      _logger.e('Görev güncellenirken hata: $e');
      throw Exception('Görev güncellenirken hata: $e');
    }
  }
  
  // Görev durumunu değiştirme (tamamlandı/tamamlanmadı)
  Future<bool> changeWorkCompletionStatus(int projectID, int workID, bool isCompleted) async {
    try {
      final step = isCompleted ? "complated" : "non-complated";
      _logger.i('Görev durumu değiştiriliyor: WorkID: $workID, Step: $step (ProjectID: $projectID)');
      
      final token = await _storageService.getToken();
      if (token == null) {
        throw Exception('Kullanıcı token bilgisi bulunamadı');
      }
      
      final response = await _apiService.put(
        'service/user/project/compWork',
        body: {
          'userToken': token,
          'projectID': projectID,
          'workID': workID,
          'step': step
        },
        requiresToken: true,
      );
      
      if (response['success'] == true) {
        _logger.i('Görev durumu başarıyla güncellendi');
        return true;
      } else {
        final errorMsg = response['message'] ?? 'Bilinmeyen hata';
        _logger.e('Görev durumu değiştirilemedi: $errorMsg');
        throw Exception('Görev durumu değiştirilemedi: $errorMsg');
      }
    } catch (e) {
      _logger.e('Görev durumu değiştirilirken hata: $e');
      throw Exception('Görev durumu değiştirilirken hata: $e');
    }
  }

  // Görev sil 
  Future<bool> deleteProjectWork(int projectID, int workID) async {
    try {
      final userToken = _storageService.getToken();
      if (userToken == null) {
        throw Exception('Oturum bilgisi bulunamadı'); 
      }
  
      final response = await _apiService.delete(
        'service/user/project/workDelete',
        body: {
          'userToken': userToken,
          'projectID': projectID,
          'workID': workID,
        },
        requiresToken: true,
      );
  
      if (response['success'] == true) {
        _logger.i('Görev başarıyla silindi');
        return true;
      } else {  
        final errorMsg = response['message'] ?? 'Bilinmeyen hata';
        _logger.e('Görev silinemedi: $errorMsg');
        throw Exception('Görev silinemedi: $errorMsg');
      }
    } catch (e) {
      _logger.e('Görev silinirken hata: $e');
      throw Exception('Görev silinirken hata: $e');
    }
  }

  // Proje sil
  Future<bool> deleteProject(int projectID, int groupID) async {
    try {
      final userToken = await _storageService.getToken();
      if (userToken == null) {
        throw Exception('Oturum bilgisi bulunamadı'); 
      }
  
      _logger.i('Proje silme isteği: ProjID: $projectID, GroupID: $groupID');
      
      final response = await _apiService.delete(
        'service/user/project/delete',
        body: {
          'userToken': userToken,
          'projectID': projectID,
          'groupID': groupID,
        },
        requiresToken: true,
      );

      // response kontrolü
      if (response == null) {
        _logger.e('Sunucudan boş yanıt alındı');
        throw Exception('Sunucudan yanıt alınamadı');
      }

      // success kontrolü
      final success = response['success'] as bool?;
      if (success == true) {
        _logger.i('Proje başarıyla silindi');
        return true;
      } else {
        final errorMsg = response['message'] ?? response['errorMessage'] ?? 'Bilinmeyen hata';
        _logger.e('Proje silinemedi: $errorMsg');
        throw Exception('Proje silinemedi: $errorMsg');
      }
    } catch (e) {
      _logger.e('Proje silinirken hata: $e');
      throw Exception('Proje silinirken hata: $e');
    }
  }

  // Kullanıcıyı projeye ekle (userID ve userRole ile)
  Future<bool> addUserToProject({
    required int groupID,
    required int projectID,
    required int userId,
    required int userRole,
  }) async {
    try {
      final userToken = await _storageService.getToken();
      if (userToken == null) {
        throw Exception('Oturum bilgisi bulunamadı');
      }
      
      _logger.i('Kullanıcı projeye ekleniyor: ProjectID: $projectID, UserID: $userId, Role: $userRole (GroupID: $groupID)');
      
      final response = await _apiService.put(
        'service/user/project/adduser',
        body: {
          'userToken': userToken,
          'groupID': groupID,
          'projectID': projectID,
          'userID': userId,
          'userRole': userRole,
        },
        requiresToken: true,
      );
      
      if (response['success'] == true) {
        _logger.i('Kullanıcı projeye başarıyla eklendi');
        return true;
      } else {
        final errorMsg = response['message'] ?? response['errorMessage'] ?? 'Bilinmeyen hata';
        _logger.e('Kullanıcı projeye eklenemedi: $errorMsg');
        return false;
      }
    } catch (e) {
      _logger.e('Kullanıcı projeye eklenirken hata: $e');
      return false;
    }
  }
} 