import '../models/group_models.dart';
import '../services/logger_service.dart';
import '../services/storage_service.dart';
// Gereksiz import kaldırıldı
import 'base_api_service.dart';

class GroupService {
  static final GroupService _instance = GroupService._internal();
  final BaseApiService _apiService = BaseApiService();
  final StorageService _storageService = StorageService();
  final LoggerService _logger = LoggerService();

  factory GroupService() {
    return _instance;
  }

  GroupService._internal();

  // Grup Listesini Getir
  Future<List<Group>> getGroups() async {
    try {
      _logger.i('Grup listesi getiriliyor...');
      
      final token = _storageService.getToken();
      if (token == null) {
        throw Exception('Kullanıcı token bilgisi bulunamadı');
      }
      
      final response = await _apiService.post(
        'service/user/group/list',
        body: {'userToken': token},
        requiresToken: true,
      );
      
      final groupListResponse = GroupListResponse.fromJson(response);
      
      if (groupListResponse.success && groupListResponse.data != null) {
        final groups = groupListResponse.data!.groups;
        _logger.i('${groups.length} grup alındı.');
        return groups;
      } else {
        throw Exception('Grup verileri alınamadı: ${groupListResponse.errorMessage}');
      }
    } catch (e) {
      _logger.e('Gruplar yüklenirken hata: $e');
      throw Exception('Grup verileri yüklenemedi: $e');
    }
  }

  // Grup detayını getir
  Future<GroupDetail> getGroupDetail(int groupID) async {
    try {
      _logger.i('Grup detayı getiriliyor... (GroupID: $groupID)');
      
      final token =  _storageService.getToken();
      if (token == null) {
        throw Exception('Kullanıcı token bilgisi bulunamadı');
      }
      
      final response = await _apiService.post(
        'service/user/group/id',
        body: {
          'userToken': token,
          'groupID': groupID,
        },
        requiresToken: true,
      );
      
      if (response['error'] == false && response['success'] == true) {
        final Map<String, dynamic> groupData = response['data'] ?? {};
        final groupDetail = GroupDetail.fromJson(groupData);
        _logger.i('Grup detayları alındı. (${groupDetail.groupName})');
        return groupDetail;
      } else {
        throw Exception('Grup detayları alınamadı: ${response['message']}');
      }
    } catch (e) {
      _logger.e('Grup detayı yüklenirken hata: $e');
      throw Exception('Grup detayları yüklenemedi: $e');
    }
  }

  // Grup oluştur
  Future<bool> createGroup(String groupName, String groupDesc) async {
    try {
      _logger.i('Grup oluşturuluyor: $groupName');
      
      final token =  _storageService.getToken();
      if (token == null) {
        throw Exception('Kullanıcı token bilgisi bulunamadı');
      }
      
      final response = await _apiService.post(
        'service/user/group/create',
        body: {
          'userToken': token,
          'groupName': groupName,
          'groupDesc': groupDesc,
        },
        requiresToken: true,
      );
      
      if (response['error'] == false && response['success'] == true) {
        _logger.i('Grup başarıyla oluşturuldu');
        return true;
      } else {
        final errorMsg = response['message'] ?? 'Bilinmeyen hata';
        _logger.e('Grup oluşturulamadı: $errorMsg');
        throw Exception('Grup oluşturulamadı: $errorMsg');
      }
    } catch (e) {
      _logger.e('Grup oluşturulurken hata: $e');
      throw Exception('Grup oluşturulurken hata: $e');
    }
  }
  
  // Grup güncelle
  Future<bool> updateGroup(int groupID, String groupName, String groupDesc) async {
    try {
      _logger.i('Grup güncelleniyor: ID: $groupID, Ad: $groupName');
      
      final token = await _storageService.getToken();
      if (token == null) {
        throw Exception('Kullanıcı token bilgisi bulunamadı');
      }
      
      final response = await _apiService.put(
        'service/user/group/update',
        body: {
          'userToken': token,
          'groupID': groupID,
          'groupName': groupName,
          'groupDesc': groupDesc,
        },
        requiresToken: true,
      );
      
      if (response['error'] == false && response['success'] == true) {
        _logger.i('Grup başarıyla güncellendi');
        return true;
      } else {
        final errorMsg = response['message'] ?? 'Bilinmeyen hata';
        _logger.e('Grup güncellenemedi: $errorMsg');
        throw Exception('Grup güncellenemedi: $errorMsg');
      }
    } catch (e) {
      _logger.e('Grup güncellenirken hata: $e');
      throw Exception('Grup güncellenirken hata: $e');
    }
  }
  
  // Gruptan kullanıcı çıkar
  Future<bool> removeUserFromGroup(int groupID, int userID) async {
    try {
      _logger.i('Gruptan kullanıcı çıkarılıyor: GroupID: $groupID, UserID: $userID');
      
      final userToken = await _storageService.getToken();
      if (userToken == null) {
        throw Exception('Kullanıcı token bilgisi bulunamadı');
      }
      
      final response = await _apiService.put(
        'service/user/group/userRemove',
        body: {
          'userToken': userToken,
          'groupID': groupID,
          'userID': userID,
          'step': 'group',
        },
        requiresToken: true,
      );
      
      if (response['success'] == true || response['410'] == 'Gone') {
        _logger.i('Kullanıcı gruptan başarıyla çıkarıldı');
        return true;
      } else {
        final errorMsg = response['message'] ?? 'Bilinmeyen hata';
        _logger.e('Kullanıcı gruptan çıkarılamadı: $errorMsg');
        throw Exception('Kullanıcı gruptan çıkarılamadı: $errorMsg');
      }
    } catch (e) {
      _logger.e('Kullanıcı gruptan çıkarılırken hata: $e');
      throw Exception('Kullanıcı gruptan çıkarılırken hata: $e');
    }
  }
  
  // Kullanıcı davet et (email veya QR)
  Future<Map<String, dynamic>> inviteUserToGroup(int groupID, String userEmail, int userRole, String inviteType) async {
    try {
      _logger.i('Kullanıcı gruba davet ediliyor: GroupID: $groupID, Email: $userEmail, Role: $userRole, Type: $inviteType');
      
      final token = await _storageService.getToken();
      if (token == null) {
        throw Exception('Kullanıcı token bilgisi bulunamadı');
      }
      
      final response = await _apiService.post(
        'service/user/group/InviteUser',
        body: {
          'userToken': token,
          'userEmail': userEmail,
          'userRole': userRole,
          'groupID': groupID,
          'invateStep': inviteType, // "email" veya "qr"
        },
        requiresToken: true,
      );
      
      if (response['error'] == false && response['success'] == true) {
        _logger.i('Davet işlemi başarılı');
        // Davet URL'ini dön
        return {
          'success': true,
          'inviteUrl': response['data']?['invateURL'] ?? '',
        };
      } else {
        final errorMsg = response['message'] ?? 'Bilinmeyen hata';
        _logger.e('Davet işlemi başarısız: $errorMsg');
        throw Exception('Davet işlemi başarısız: $errorMsg');
      }
    } catch (e) {
      _logger.e('Davet gönderilirken hata: $e');
      throw Exception('Davet gönderilirken hata: $e');
    }
  }
  
  // Grup silme
  Future<bool> deleteGroup(int groupID) async {
    try {
      _logger.i('Grup siliniyor: GroupID: $groupID');
      
      final token = await _storageService.getToken();
      if (token == null) {
        throw Exception('Kullanıcı token bilgisi bulunamadı');
      }
      
      final response = await _apiService.delete(
        'service/user/group/delete',
        body: {
          'userToken': token,
          'groupID': groupID,
        },
        requiresToken: true,
      );
      
      if (response['error'] == false && response['success'] == true) {
        _logger.i('Grup başarıyla silindi');
        return true;
      } else {
        final errorMsg = response['message'] ?? 'Bilinmeyen hata';
        _logger.e('Grup silinemedi: $errorMsg');
        throw Exception('Grup silinemedi: $errorMsg');
      }
    } catch (e) {
      _logger.e('Grup silinirken hata: $e');
      throw Exception('Grup silinirken hata: $e');
    }
  }

  // Kullanıcıyı projeye ekle
  Future<bool> addUserToProject({
    required int groupId,
    required int projectId,
    required String userEmail,
  }) async {
    try {
      _logger.i('Kullanıcı projeye ekleniyor: GroupID: $groupId, ProjectID: $projectId, Email: $userEmail');
      
      final token = await _storageService.getToken();
      if (token == null) {
        throw Exception('Kullanıcı token bilgisi bulunamadı');
      }
      
      final response = await _apiService.put(
        'service/user/project/addmember',
        body: {
          'userToken': token,
          'groupID': groupId,
          'projectID': projectId,
          'userEmail': userEmail,
        },
        requiresToken: true,
      );
      
      if (response['success'] == true) {
        _logger.i('Kullanıcı projeye başarıyla eklendi');
        return true;
      } else {
        final errorMsg = response['errorMessage'] ?? 'Bilinmeyen hata';
        _logger.e('Kullanıcı projeye eklenemedi: $errorMsg');
        return false;
      }
    } catch (e) {
      _logger.e('Kullanıcı projeye eklenirken hata: $e');
      return false;
    }
  }

  // Kullanıcıyı projeye ekle (bildirim backend tarafından gönderilecek)
  Future<bool> addUserToProjectWithNotification({
    required int groupId,
    required int projectId,
    required String projectName,
    required String userEmail,
    required String currentUserName,
  }) async {
    // Sadece backend API'yi çağır, bildirim backend tarafından gönderilir
    return await addUserToProject(
      groupId: groupId,
      projectId: projectId,
      userEmail: userEmail
    );
  }
} 