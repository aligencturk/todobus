import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../services/logger_service.dart';
import '../services/storage_service.dart';
import '../services/device_info_service.dart';
import '../models/auth_models.dart';
import '../models/user_model.dart';
import '../models/group_models.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  final LoggerService _logger = LoggerService();
  final StorageService _storageService = StorageService();
  final DeviceInfoService _deviceInfoService = DeviceInfoService();

  // API ayarları
  static const String baseUrl = 'https://api.ridvandasdelen.com/todobus/';  // Gerçek URL eklenecek
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
        _logger.e('API hatası: ${response.statusCode} - ${response.body}');
        throw Exception('API hatası: ${response.statusCode}');
      }
    } catch (e) {
      _logger.e('İstek hatası:', e);
      throw e;
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
        _logger.e('API hatası: ${response.statusCode} - ${response.body}');
        throw Exception('API hatası: ${response.statusCode}');
      }
    } catch (e) {
      _logger.e('İstek hatası:', e);
      throw e;
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
    if (userResponse.success && userResponse.data != null) {
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
  Future<GroupListResponse> getGroups() async {
    final token = _storageService.getToken();
    if (token == null) {
      throw Exception('Token bulunamadı. Lütfen tekrar giriş yapın.');
    }

    final body = {
      'userToken': token,
    };

    final response = await post(
      'service/user/group/list',
      body: body,
      requiresToken: true,
    );

    final groupListResponse = GroupListResponse.fromJson(response);
    
    if (groupListResponse.success) {
      _logger.i('${groupListResponse.data?.groups.length ?? 0} grup alındı.');
    } else {
      _logger.w('Grup listesi alınamadı: ${groupListResponse.errorMessage}');
    }
    
    return groupListResponse;
  }
} 