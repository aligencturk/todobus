import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/logger_service.dart';
import '../services/storage_service.dart';
import '../models/auth_models.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  final LoggerService _logger = LoggerService();
  final StorageService _storageService = StorageService();

  // API ayarları
  static const String baseUrl = 'https://api.ridvandasdelen.com/todobus/';  // Gerçek URL eklenecek
  static const String username = 'Tr2VAhW2ICWHJN2nlvp9T5ycBoyMJD';
  static const String password = 'vRP4rTBAqm1tm2I17I1EV3PH57Edl0';

  // Basic auth için encodelanmış yetkilendirme bilgisi
  final String _basicAuth = 'Basic ${base64.encode(utf8.encode('$username:$password'))}';

  factory ApiService() {
    return _instance;
  }

  ApiService._internal();

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
} 