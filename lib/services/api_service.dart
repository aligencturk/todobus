import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../services/logger_service.dart';
import '../services/storage_service.dart';
import '../services/device_info_service.dart';
import '../models/auth_models.dart';
import '../models/user_model.dart';
import '../models/group_models.dart';
import '../models/event_models.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  final LoggerService _logger = LoggerService();
  final StorageService _storageService = StorageService();
  final DeviceInfoService _deviceInfoService = DeviceInfoService();

  // API ayarları
  static const String baseUrl = 'https://api.todobus.tr/';  // Gerçek URL eklenecek
  static const String username = 'Tr2VAhW2ICWHJN2nlvp9T5ycBoyMJD';
  static const String password = 'vRP4rTBAqm1tm2I17I1EV3PH57Edl0';

  // API sürüm bilgileri
  static const String appVersion = '1.0';

  // Basic auth için encodelanmış yetkilendirme bilgisi
  final String _basicAuth = 'Basic ${base64.encode(utf8.encode('$username:$password'))}';

  factory ApiService() {
    return _instance;
  }

  ApiService._internal();

  // Platformu tespit et
  String getPlatform() {
    return _deviceInfoService.getApiPlatformType();
  }

  // Uygulama versiyonunu al
  String getAppVersion() {
    return _deviceInfoService.getAppVersion();
  }

  // HTTP başlıklarını oluştur
  Map<String, String> _getHeaders({bool withToken = false}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Authorization': _basicAuth,
    };

    if (withToken) {
      final token = _storageService.getToken();
      if (token != null) {
        headers['Token'] = token;
      } else {
        _logger.w('Token bulunamadı');
      }
    }

    return headers;
  }

  // POST isteği yap
  Future<Map<String, dynamic>> post(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requiresToken = false,
  }) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = _getHeaders(withToken: requiresToken);
    
    _logger.d('POST isteği: $url');
    _logger.d('Gövde: ${jsonEncode(body)}');

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      );

      // 410 Gone, bu API'de başarı yanıtı temsil ediyor
      if (response.statusCode == 410) {
        _logger.i('Başarılı yanıt alındı (410 Gone)');
        return jsonDecode(response.body);
      } else {
        final responseBody = jsonDecode(response.body);
        final userMessage = _getUserFriendlyErrorMessage(response.statusCode, responseBody);
        _logger.e('API hatası: ${response.statusCode} - $userMessage');
        throw Exception(userMessage);
      }
    } catch (e) {
      final userMessage = _handleNetworkException(e);
      _logger.e('İstek hatası: $userMessage');
      throw Exception(userMessage);
    }
  }

  // DELETE isteği yap
  Future<Map<String, dynamic>> delete(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requiresToken = false,
  }) async {  
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = _getHeaders(withToken: requiresToken);
    
    _logger.d('DELETE isteği: $url');
    _logger.d('Gövde: ${jsonEncode(body)}');

    try {
      final response = await http.delete(
        url,
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      );

      if (response.statusCode == 410) {
        _logger.i('Başarılı yanıt alındı (410 Gone)');
        return jsonDecode(response.body);
      } else {
        final responseBody = jsonDecode(response.body);
        final userMessage = _getUserFriendlyErrorMessage(response.statusCode, responseBody);
        _logger.e('API hatası: ${response.statusCode} - $userMessage');
        throw Exception(userMessage);
      }
    } catch (e) {
      final userMessage = _handleNetworkException(e);
      _logger.e('İstek hatası: $userMessage');
      throw Exception(userMessage);
    }
  }

  // GET isteği yap
  Future<Map<String, dynamic>> get(
    String endpoint, {
    Map<String, dynamic>? queryParams,
    bool requiresToken = false,
  }) async {  
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = _getHeaders(withToken: requiresToken);
    
    _logger.d('GET isteği: $url');
    _logger.d('Query Params: ${queryParams ?? ''}');  

    try {
      final response = await http.get(
        url,
        headers: headers,
      );

      // GET istekleri için 200 başarı durum kodudur
      if (response.statusCode == 200 || response.statusCode == 410) {
        _logger.i('Başarılı yanıt alındı (${response.statusCode})');
        return jsonDecode(response.body);
      } else {
        final responseBody = jsonDecode(response.body);
        final userMessage = _getUserFriendlyErrorMessage(response.statusCode, responseBody);
        _logger.e('API hatası: ${response.statusCode} - $userMessage');
        throw Exception(userMessage);
      }
    } catch (e) {
      final userMessage = _handleNetworkException(e);
      _logger.e('İstek hatası: $userMessage');
      throw Exception(userMessage);
    }
  }

  // PUT isteği yap
  Future<Map<String, dynamic>> put(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requiresToken = false,
  }) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = _getHeaders(withToken: requiresToken);
    
    _logger.d('PUT isteği: $url');
    _logger.d('Gövde: ${jsonEncode(body)}');

    try {
      final response = await http.put(
        url,
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      );

      // 410 Gone, bu API'de başarı yanıtı temsil ediyor
      if (response.statusCode == 410) {
        _logger.i('Başarılı yanıt alındı (410 Gone)');
        return jsonDecode(response.body);
      } else {
        final responseBody = jsonDecode(response.body);
        final userMessage = _getUserFriendlyErrorMessage(response.statusCode, responseBody);
        _logger.e('API hatası: ${response.statusCode} - $userMessage');
        throw Exception(userMessage);
      }
    } catch (e) {
      final userMessage = _handleNetworkException(e);
      _logger.e('İstek hatası: $userMessage');
      throw Exception(userMessage);
    }
  }

  // Kullanıcı dostu hata mesajları
  String _getUserFriendlyErrorMessage(int statusCode, dynamic responseBody) {
    // Öncelikle API'nin döndüğü özel mesaj varsa onu kullanalım
    if (responseBody is Map<String, dynamic>) {
      final message = responseBody['message'] as String?;
      if (message != null && message.isNotEmpty) {
        return message;
      }
      
      final errorMessage = responseBody['error_message'] as String?;
      if (errorMessage != null && errorMessage.isNotEmpty) {
        return errorMessage;
      }
    }
    
    // API mesaj dönmediyse durum koduna göre genel mesajlar
    switch (statusCode) {
      case 400:
        return 'İstek geçersiz, lütfen bilgileri kontrol ediniz.';
      case 401:
        return 'Oturum süreniz dolmuş olabilir, lütfen tekrar giriş yapın.';
      case 403:
        return 'Bu işlemi yapmaya yetkiniz bulunmuyor.';
      case 404:
        return 'İstenen kaynak bulunamadı.';
      case 417:
        return 'İşlem tamamlanamadı, lütfen tekrar deneyin.';
      case 429:
        return 'Çok fazla istek gönderdiniz, lütfen biraz bekleyin.';
      case 500:
      case 502:
      case 503:
      case 504:
        return 'Sunucuda bir hata oluştu, lütfen daha sonra tekrar deneyin.';
      default:
        return 'Beklenmeyen bir hata oluştu, lütfen tekrar deneyin.';
    }
  }
  
  // Ağ hatalarını kullanıcı dostu mesajlara çevir
  String _handleNetworkException(dynamic exception) {
    if (exception is SocketException) {
      return 'İnternet bağlantınızı kontrol edin ve tekrar deneyin.';
    } else if (exception is TimeoutException) {
      return 'İşlem zaman aşımına uğradı, lütfen tekrar deneyin.';
    } else if (exception is FormatException) {
      return 'Sunucudan geçersiz veri alındı.';
    } else {
      // Diğer tüm hatalar
      return 'Bir hata oluştu, lütfen tekrar deneyin.';
    }
  }

  // Login metodu
  Future<LoginResponse> login(String email, String password) async {
    final loginRequest = LoginRequest(
      userEmail: email,
      userPassword: password,
    );

    final response = await post(
      'service/auth/login',
      body: loginRequest.toJson(),
    );

    final loginResponse = LoginResponse.fromJson(response);

    if (loginResponse.success) {
      // Başarılı girişte kullanıcı bilgilerini kaydet
      if (loginResponse.data != null) {
        await _storageService.saveToken(loginResponse.data!.token);
        await _storageService.saveUserId(loginResponse.data!.userID);
        await _storageService.setLoggedIn(true);
      }
    }

    return loginResponse;
  }

  // Kayıt metodu
  Future<RegisterResponse> register({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String password,
    required bool policy,
    required bool kvkk,
  }) async {
    try {
      _logger.i('Kullanıcı kaydı yapılıyor: $email');
      
      final registerRequest = RegisterRequest(
        userFirstname: firstName,
        userLastname: lastName,
        userEmail: email,
        userPhone: phone,
        userPassword: password,
        version: getAppVersion(),
        platform: getPlatform(),
        policy: policy,
        kvkk: kvkk,
      );
      
      final response = await post(
        'service/auth/register',
        body: registerRequest.toJson(),
      );
      
      final registerResponse = RegisterResponse.fromJson(response);
      
      if (registerResponse.success) {
        _logger.i('Kullanıcı kaydı başarılı: $email');
      } else {
        _logger.w('Kullanıcı kaydı başarısız: ${registerResponse.message}');
      }
      
      return registerResponse;
    } catch (e) {
      _logger.e('Kullanıcı kaydı sırasında hata: $e');
      throw Exception('Kayıt işlemi sırasında bir hata oluştu: $e');
    }
  }
  
  // Şifremi unuttum metodu
  Future<ForgotPasswordResponse> forgotPassword(String email) async {
    try {
      _logger.i('Şifre sıfırlama isteği gönderiliyor: $email');
      
      final forgotRequest = ForgotPasswordRequest(
        userEmail: email,
      );
      
      final response = await post(
        'service/auth/forgotPassword',
        body: forgotRequest.toJson(),
      );
      
      final forgotResponse = ForgotPasswordResponse.fromJson(response);
      
      if (forgotResponse.success) {
        _logger.i('Şifre sıfırlama isteği başarılı: $email');
      } else {
        _logger.w('Şifre sıfırlama isteği başarısız: ${forgotResponse.message}');
      }
      
      return forgotResponse;
    } catch (e) {
      _logger.e('Şifre sıfırlama isteği sırasında hata: $e');
      throw Exception('Şifre sıfırlama isteği sırasında bir hata oluştu: $e');
    }
  }
  
  // Doğrulama kodu kontrolü
  Future<CodeCheckResponse> checkVerificationCode(String code, String token) async {
    try {
      _logger.i('Doğrulama kodu kontrol ediliyor: $code');
      
      final codeRequest = CodeCheckRequest(
        code: code,
        token: token,
      );
      
      final response = await post(
        'service/auth/code/checkCode',
        body: codeRequest.toJson(),
      );
      
      final codeResponse = CodeCheckResponse.fromJson(response);
      
      if (codeResponse.success) {
        _logger.i('Doğrulama kodu kontrolü başarılı');
      } else {
        _logger.w('Doğrulama kodu kontrolü başarısız: ${codeResponse.message}');
      }
      
      return codeResponse;
    } catch (e) {
      _logger.e('Doğrulama kodu kontrolü sırasında hata: $e');
      throw Exception('Doğrulama kodu kontrolü sırasında bir hata oluştu: $e');
    }
  }
  
  // Şifre güncelleme
  Future<UpdatePasswordResponse> updatePassword(String passToken, String password, String passwordAgain) async {
    try {
      _logger.i('Şifre güncelleniyor');
      
      final updateRequest = UpdatePasswordRequest(
        passToken: passToken,
        password: password,
        passwordAgain: passwordAgain,
      );
      
      final response = await post(
        'service/auth/forgotPassword/updatePass',
        body: updateRequest.toJson(),
      );
      
      final updateResponse = UpdatePasswordResponse.fromJson(response);
      
      if (updateResponse.success) {
        _logger.i('Şifre güncelleme başarılı');
      } else {
        _logger.w('Şifre güncelleme başarısız: ${updateResponse.message}');
      }
      
      return updateResponse;
    } catch (e) {
      _logger.e('Şifre güncelleme sırasında hata: $e');
      throw Exception('Şifre güncelleme sırasında bir hata oluştu: $e');
    }
  }

  // Kullanıcı Bilgilerini Getir
  Future<UserResponse> getUser() async {
    final token = _storageService.getToken();
    if (token == null) {
      throw Exception('Token bulunamadı. Lütfen tekrar giriş yapın.');
    }

    final platform = getPlatform();
    final version = getAppVersion();
    
    final body = {
      'userToken': token,
      'platform': platform,
      'version': version,
    };

    final response = await put(
      'service/user/id',
      body: body,
      requiresToken: true,
    );

    final userResponse = UserResponse.fromJson(response);
    
    // Platform ve versiyon kontrolü
    if (userResponse.success == true && userResponse.data != null) {
      final user = userResponse.data!.user;
      
      // Platform'a göre kontroller
      if (platform == 'ios' && user.iosVersion != version) {
        _logger.w('iOS versiyonu güncel değil: ${user.iosVersion} vs $version');
        // Burada güncelleme uyarısı işlenebilir
      } else if (platform == 'android' && user.androidVersion != version) {
        _logger.w('Android versiyonu güncel değil: ${user.androidVersion} vs $version');
        // Burada güncelleme uyarısı işlenebilir
      }
    }
    
    return userResponse;
  }

  // Grup Listesini Getir
  Future<List<Group>> getGroups() async {
    try {
      _logger.i('Grup listesi getiriliyor...');
      
      final token = await _storageService.getToken();
      if (token == null) {
        throw Exception('Kullanıcı token bilgisi bulunamadı');
      }
      
      final response = await post(
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

  Future<GroupDetail> getGroupDetail(int groupID) async {
    try {
      _logger.i('Grup detayı getiriliyor... (GroupID: $groupID)');
      
      final token = await _storageService.getToken();
      if (token == null) {
        throw Exception('Kullanıcı token bilgisi bulunamadı');
      }
      
      final response = await post(
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
      
      final token = await _storageService.getToken();
      if (token == null) {
        throw Exception('Kullanıcı token bilgisi bulunamadı');
      }
      
      final response = await post(
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
      
      final response = await put(
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
      
      final token = await _storageService.getToken();
      if (token == null) {
        throw Exception('Kullanıcı token bilgisi bulunamadı');
      }
      
      final response = await put(
        'service/user/group/userRemove',
        body: {
          'userToken': token,
          'groupID': groupID,
          'userID': userID,
          'step': 'group',
        },
        requiresToken: true,
      );
      
      // 410 Gone durumu başarılı kabul edilir
      if ((response['error'] == false && response['success'] == true) || response['410'] == 'Gone') {
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
      
      final response = await post(
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
      
      final response = await delete(
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
  
  // Grup raporlarını getir
  Future<List<GroupLog>> getGroupReports(int groupID, bool isAdmin) async {
    try {
      final userToken = _storageService.getToken();
      if (userToken == null) {
        throw Exception('Oturum bilgisi bulunamadı');
      }

      final response = await post(
        'service/user/group/reports',
        body: {
          'userToken': userToken,
          'groupID': groupID,
          'isAdmin': isAdmin,
        },
        requiresToken: true,
      );

      if (response['success'] == true && response['data'] != null) {
        final List<dynamic> logsJson = response['data']['logs'] ?? [];
        final List<GroupLog> logs = logsJson
            .map((log) => GroupLog.fromJson(log))
            .toList();
        return logs;
      }

      return [];
    } catch (e) {
      _logger.e('Grup raporları alınırken hata: $e');
      throw Exception('Grup raporları alınamadı: $e');
    }
  }

  // Proje detaylarını getir
  Future<ProjectDetail> getProjectDetail(int projectID, int groupID) async {
    try {
      final userToken = _storageService.getToken();
      if (userToken == null) {
        throw Exception('Oturum bilgisi bulunamadı');
      }

      final response = await post(
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
      
      final response = await post(
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
      
      final response = await put(
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
      
      final response = await put(
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
      
      final response = await get(
        'service/general/general/proStatuses',
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
      _logger.i('Proje görevleri getiriliyor... (ProjectID: $projectID)');
      
      final token = await _storageService.getToken();
      if (token == null) {
        throw Exception('Kullanıcı token bilgisi bulunamadı');
      }
      
      final response = await post(
        'service/user/project/workList',
        body: {
          'userToken': token,
          'projectID': projectID,
        },
        requiresToken: true,
      );
      
      if (response['success'] == true && response['data'] != null) {
        final workListResponse = ProjectWorkListResponse.fromJson(response);
        
        if (workListResponse.data != null) {
          final works = workListResponse.data!.works;
          _logger.i('${works.length} görev alındı.');
          return works;
        }
      }
      
      _logger.w('Proje görevleri alınamadı veya boş.');
      return [];
    } catch (e) {
      _logger.e('Proje görevleri yüklenirken hata: $e');
      throw Exception('Proje görevleri yüklenemedi: $e');
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
      
      final response = await post(
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
      
      final response = await post(
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
      
      final response = await put(
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
      
      final response = await put(
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

  // Proje sil 
  Future<bool> deleteProject(int projectID, int workID) async {
    try {
      final userToken = _storageService.getToken();
      if (userToken == null) {
        throw Exception('Oturum bilgisi bulunamadı'); 
      }
  
      final response = await delete(
        'service/user/project/workDelete',
        body: {
          'userToken': userToken,
          'projectID': projectID,
          'workID': workID,
        },
        requiresToken: true,
      );
  
      if (response['success'] == true) {
        _logger.i('Proje başarıyla silindi');
        return true;
      } else {  
        final errorMsg = response['message'] ?? 'Bilinmeyen hata';
        _logger.e('Proje silinemedi: $errorMsg');
        throw Exception('Proje silinemedi: $errorMsg');
      }
    } catch (e) {
      _logger.e('Proje silinirken hata: $e');
      throw Exception('Proje silinirken hata: $e');
    }
  }

  // Etkinlikleri getir
  Future<EventsResponse> getEvents({int groupID = 0}) async {
    try {
      final token = await  _storageService.getToken();
      if (token == null) {
        throw Exception('Oturum bilgisi bulunamadı');
      }

      final body = {
        'userToken': token,
        'groupID': groupID,
      };

      final response = await post('service/user/event/list', body: body);
      return EventsResponse.fromJson(response);
    } catch (e) {
      _logger.e('Etkinlikler yüklenirken hata: $e');
      throw Exception('Etkinlikler yüklenemedi: $e');
    }
  }

  // Kullanıcının görevlerini getir
  Future<UserWorksResponse> getUserWorks() async {
    try {
      final token = await _storageService.getToken();
      if (token == null) {
        throw Exception('Oturum bilgisi bulunamadı');
      }

      final body = {
        'userToken': token,
      };

      _logger.i('Kullanıcı görevleri getiriliyor...');
      final response = await post('service/user/project/workListUser', body: body);
      
      final worksResponse = UserWorksResponse.fromJson(response);
      _logger.i('Kullanıcı görevleri başarıyla getirildi: ${worksResponse.data?.works.length ?? 0} görev');
      
      return worksResponse;
    } catch (e) {
      _logger.e('Kullanıcı görevleri yüklenirken hata: $e');
      throw Exception('Kullanıcı görevleri yüklenemedi: $e');
    }
  }

  // Etkinlik detayı getir
  Future<EventDetailResponse> getEventDetail(int eventID) async {
    try {
      final token = await _storageService.getToken();
      if (token == null) {
        throw Exception('Oturum bilgisi bulunamadı');
      }

      final body = {
        'userToken': token,
        'eventID': eventID,
      };

      final response = await post('service/user/event/id', body: body);
      return EventDetailResponse.fromJson(response);
    } catch (e) {
      _logger.e('Etkinlik detayı yüklenirken hata: $e');
      throw Exception('Etkinlik detayı yüklenemedi: $e');
    }
  }

  // Etkinlik güncelle
  Future<Map<String, dynamic>> updateEvent({
    required int eventID,
    required String eventTitle,
    required String eventDesc,
    required String eventDate,
    required int eventStatus,
  }) async {
    try {
      final token = await _storageService.getToken();
      if (token == null) {
        throw Exception('Oturum bilgisi bulunamadı');
      }

      final body = {
        'userToken': token,
        'eventID': eventID,
        'eventTitle': eventTitle,
        'eventDesc': eventDesc,
        'eventDate': eventDate,
        'eventStatus': eventStatus,
      };

      final response = await post('service/user/event/update', body: body);
      return response;
    } catch (e) {
      _logger.e('Etkinlik güncellenirken hata: $e');
      throw Exception('Etkinlik güncellenemedi: $e');
    }
  }

  // Yeni etkinlik oluştur
  Future<Map<String, dynamic>> createEvent({
    required int groupID,
    required String eventTitle,
    required String eventDesc,
    required String eventDate,
  }) async {
    try {
      final token = await _storageService.getToken();
      if (token == null) {
        throw Exception('Oturum bilgisi bulunamadı');
      }

      final body = {
        'userToken': token,
        'groupID': groupID,
        'eventTitle': eventTitle,
        'eventDesc': eventDesc,
        'eventDate': eventDate,
      };

      final response = await post('service/user/event/create', body: body);
      return response;
    } catch (e) {
      _logger.e('Etkinlik oluşturulurken hata: $e');
      throw Exception('Etkinlik oluşturulamadı: $e');
    }
  }

  // Etkinlik sil
  Future<Map<String, dynamic>> deleteEvent(int eventID) async {
    try {
      final token = await _storageService.getToken();
      if (token == null) {
        throw Exception('Oturum bilgisi bulunamadı');
      }

      final body = {
        'userToken': token,
        'eventID': eventID,
      };

      final response = await post('service/user/event/delete', body: body);
      return response;
    } catch (e) {
      _logger.e('Etkinlik silinirken hata: $e');
      throw Exception('Etkinlik silinemedi: $e');
    }
  }
  

} 