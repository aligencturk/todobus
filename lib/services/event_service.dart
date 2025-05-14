import '../models/event_models.dart';
import '../services/logger_service.dart';
import '../services/storage_service.dart';
import 'base_api_service.dart';

class EventService {
  static final EventService _instance = EventService._internal();
  final BaseApiService _apiService = BaseApiService();
  final StorageService _storageService = StorageService();
  final LoggerService _logger = LoggerService();

  factory EventService() {
    return _instance;
  }

  EventService._internal();

  // Etkinlikleri getir
  Future<EventsResponse> getEvents({int groupID = 0}) async {
    try {
      final token = await _storageService.getToken();
      if (token == null) {
        throw Exception('Oturum bilgisi bulunamadı');
      }

      final body = {
        'userToken': token,
        'groupID': groupID,
      };

      final response = await _apiService.post('service/user/event/list', body: body);
      return EventsResponse.fromJson(response);
    } catch (e) {
      _logger.e('Etkinlikler yüklenirken hata: $e');
      throw Exception('Etkinlikler yüklenemedi: $e');
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

      final response = await _apiService.post('service/user/event/id', body: body);
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

      final response = await _apiService.put('service/user/event/update', body: body);
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

      final response = await _apiService.post('service/user/event/create', body: body);
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

      final response = await _apiService.delete('service/user/event/delete', body: body);
      return response;
    } catch (e) {
      _logger.e('Etkinlik silinirken hata: $e');
      throw Exception('Etkinlik silinemedi: $e');
    }
  }
} 