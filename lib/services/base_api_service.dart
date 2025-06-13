import 'dart:convert';
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import '../services/logger_service.dart';
import '../services/storage_service.dart';
import '../services/device_info_service.dart';
import '../views/login_view.dart';

class BaseApiService {
  static final BaseApiService _instance = BaseApiService._internal();
  final LoggerService _logger = LoggerService();
  final StorageService _storageService = StorageService();
  final DeviceInfoService _deviceInfoService = DeviceInfoService();
  
  // Global navigasyon için key
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  // API ayarları
  static const String baseUrl = 'https://api.todobus.tr/v1.0.0/';  // Gerçek URL eklenecek
  static const String username = 'Tr2VAhW2ICWHJN2nlvp9T5ycBoyMJD';
  static const String password = 'vRP4rTBAqm1tm2I17I1EV3PH57Edl0';

  // API sürüm bilgileri
  static const String appVersion = '1.0';

  // Basic auth için encodelanmış yetkilendirme bilgisi
  final String _basicAuth = 'Basic ${base64.encode(utf8.encode('$username:$password'))}';

  factory BaseApiService() {
    return _instance;
  }

  BaseApiService._internal();

  // Platformu tespit et
  String getPlatform() {
    return _deviceInfoService.getApiPlatformType();
  }

  // Uygulama versiyonunu al
  String getAppVersion() {
    return _deviceInfoService.getAppVersion();
  }

  // Cihaz kimliğini al
  Future<String> getDeviceId() async {
    return await _deviceInfoService.getDeviceId();
  }

  // HTTP başlıklarını oluştur
  Map<String, String> getHeaders({bool withToken = false}) {
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
  
  // 401 Hatasını Yönet ve Login sayfasına yönlendir
  void _handle401Error() {
    _logger.w('401 Yetkisiz erişim hatası - Oturum zaman aşımı');
    
    // Token temizle
    
    // Login sayfasına yönlendir
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (navigatorKey.currentState != null) {
        navigatorKey.currentState!.pushAndRemoveUntil(
          CupertinoPageRoute(builder: (context) => const LoginView()),
          (route) => false, // Tüm sayfaları temizle
        );
      }
    });
  }
 
  // POST isteği yap
  Future<Map<String, dynamic>> post(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requiresToken = false,
  }) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = getHeaders(withToken: requiresToken);
    
    _logger.d('POST isteği: $url');
    _logger.d('Gövde: ${jsonEncode(body)}');

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      );

      if (response.statusCode == 401) {
        _handle401Error();
        throw Exception('Oturum süreniz dolmuş, giriş sayfasına yönlendiriliyorsunuz.');
      }
      
      // 410 Gone, bu API'de başarı yanıtı temsil ediyor
      if (response.statusCode == 410) {
        _logger.i('Başarılı yanıt alındı (410 Gone)');
        try {
          final result = jsonDecode(response.body);
          // 410 başarı kodunu ekle, böylece istemci tarafında kontrol edilebilir
          result['code'] = 410;
          return result;
        } catch (e) {
          // JSON parse hatası durumunda basit bir başarı yanıtı döndür
          _logger.w('410 yanıtı için JSON parse hatası: $e, varsayılan başarı yanıtı dönüyor');
          return {'success': true, 'code': 410};
        }
      } else {
        // Response body'yi decode et
        final responseBody = jsonDecode(response.body);
        
        // AuthService gibi servislerin response'u işleyebilmesi için
        // exception fırlatmak yerine responseBody'yi döndür
        // statusCode'u da ekle ki service katmanında kontrol edilebilsin
        responseBody['statusCode'] = response.statusCode;
        
        _logger.d('API yanıtı: ${response.statusCode} - $responseBody');
        return responseBody;
      }
    } catch (e) {
      // Eğer zaten bir Exception ise, re-throw et
      if (e is Exception) {
        rethrow;
      }
      // Diğer hatalar için Exception'a wrap et
      _logger.e('İstek hatası: $e');
      throw Exception(e.toString());
    }
  }

  // DELETE isteği yap
  Future<Map<String, dynamic>> delete(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requiresToken = false,
  }) async {  
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = getHeaders(withToken: requiresToken);
    
    _logger.d('DELETE isteği: $url');
    _logger.d('Gövde: ${jsonEncode(body)}');

    try {
      final response = await http.delete(
        url,
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      );
      
      if (response.statusCode == 401) {
        _handle401Error();
        throw Exception('Oturum süreniz dolmuş, giriş sayfasına yönlendiriliyorsunuz.');
      }

      _logger.d('DELETE yanıt: ${response.statusCode} ${response.reasonPhrase}');
      _logger.d('DELETE yanıt body: ${response.body}');

      if (response.statusCode == 410) {
        _logger.i('Başarılı yanıt alındı (410 Gone)');
        // Boş body kontrolü
        if (response.body.isEmpty) {
          _logger.w('Yanıt içeriği boş, varsayılan başarı yanıtı dönüyor');
          return {'success': true, 'code': 410};
        }
        
        try {
          final decodedJson = jsonDecode(response.body) as Map<String, dynamic>;
          // 410 kodunu ekle
          decodedJson['code'] = 410;
          return decodedJson;
        } catch (e) {
          _logger.e('JSON parse hatası: $e, response.body: ${response.body}');
          throw Exception('Sunucudan gelen yanıt işlenemedi: ${e.toString()}');
        }
      } else {
        String userMessage;
        try {
          final responseBody = jsonDecode(response.body);
          userMessage = _getUserFriendlyErrorMessage(response.statusCode, responseBody);
        } catch (e) {
          _logger.e('Hata yanıtı JSON parse hatası: $e, response.body: ${response.body}');
          userMessage = _getUserFriendlyErrorMessage(response.statusCode, null);
        }
        
        _logger.e('API hatası: ${response.statusCode} - $userMessage');
        throw Exception(userMessage);
      }
    } catch (e) {
      // Eğer zaten bir Exception ise, re-throw et
      if (e is Exception) {
        rethrow;
      }
      // Diğer hatalar için Exception'a wrap et
      _logger.e('İstek hatası: $e');
      throw Exception(e.toString());
    }
  }

  // GET isteği yap
  Future<Map<String, dynamic>> get(
    String endpoint, {
    Map<String, dynamic>? queryParams,
    bool requiresToken = false,
  }) async {  
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = getHeaders(withToken: requiresToken);
    
    // Önbellek önlemek için headers ekle
    headers['Cache-Control'] = 'no-cache, no-store, must-revalidate';
    headers['Pragma'] = 'no-cache';
    headers['Expires'] = '0';
    
    _logger.d('GET isteği: $url');
    _logger.d('Query Params: ${queryParams ?? ''}');  
    _logger.d('Headers: $headers');

    try {
      final response = await http.get(
        url,
        headers: headers,
      );
      
      if (response.statusCode == 401) {
        _handle401Error();
        throw Exception('Oturum süreniz dolmuş, giriş sayfasına yönlendiriliyorsunuz.');
      }

      // GET istekleri için 200 başarı durum kodudur
      if (response.statusCode == 200 || response.statusCode == 410) {
        _logger.i('Başarılı yanıt alındı (${response.statusCode})');
        try {
          final result = jsonDecode(response.body);
          // Yanıt kodunu ekle
          result['code'] = response.statusCode;
          return result;
        } catch (e) {
          // JSON parse hatası durumunda basit bir başarı yanıtı döndür
          _logger.w('Yanıt için JSON parse hatası: $e, varsayılan başarı yanıtı dönüyor');
          return {'success': true, 'code': response.statusCode};
        }
      } else {
        final responseBody = jsonDecode(response.body);
        final userMessage = _getUserFriendlyErrorMessage(response.statusCode, responseBody);
        _logger.e('API hatası: ${response.statusCode} - $userMessage');
        throw Exception(userMessage);
      }
    } catch (e) {
      // Eğer zaten bir Exception ise, re-throw et
      if (e is Exception) {
        rethrow;
      }
      // Diğer hatalar için Exception'a wrap et
      _logger.e('İstek hatası: $e');
      throw Exception(e.toString());
    }
  }

  // PUT isteği yap
  Future<Map<String, dynamic>> put(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requiresToken = false,
  }) async {  
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = getHeaders(withToken: requiresToken);
    
    _logger.d('PUT isteği: $url');
    _logger.d('Gövde: ${jsonEncode(body)}');

    try {
      final response = await http.put(
        url,
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      );
      
      if (response.statusCode == 401) {
        _handle401Error();
        throw Exception('Oturum süreniz dolmuş, giriş sayfasına yönlendiriliyorsunuz.');
      }

      // 410 Gone ve 200 OK, bu API'de başarı yanıtı temsil ediyor
      if (response.statusCode == 410 || response.statusCode == 200) {
        _logger.i('Başarılı yanıt alındı (${response.statusCode})');
        try {
          final result = jsonDecode(response.body);
          // Durum kodunu ekle, böylece istemci tarafında kontrol edilebilir
          result['code'] = response.statusCode;
          return result;
        } catch (e) {
          // JSON parse hatası durumunda basit bir başarı yanıtı döndür
          _logger.w('${response.statusCode} yanıtı için JSON parse hatası: $e, varsayılan başarı yanıtı dönüyor');
          return {'success': true, 'code': response.statusCode};
        }
      } else {
        final responseBody = jsonDecode(response.body);
        final userMessage = _getUserFriendlyErrorMessage(response.statusCode, responseBody);
        _logger.e('API hatası: ${response.statusCode} - $userMessage');
        throw Exception(userMessage);
      }
    } catch (e) {
      // Eğer zaten bir Exception ise, re-throw et
      if (e is Exception) {
        rethrow;
      }
      // Diğer hatalar için Exception'a wrap et
      _logger.e('İstek hatası: $e');
      throw Exception(e.toString());
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
        return 'E-posta adresi veya şifre hatalı.'; // Login için varsayılan 417 mesajı
      case 429:
        return 'Çok fazla istek gönderdiniz, lütfen biraz bekleyin.';
      case 500:
      case 502:
      case 503:
      case 504:
        return 'Sunucuda bir hata oluştu, lütfen daha sonra tekrar deneyin.';
      default:
        return 'Beklenmeyen bir hata oluştu (Kod: $statusCode), lütfen tekrar deneyin.';
    }
  }
  
  }
