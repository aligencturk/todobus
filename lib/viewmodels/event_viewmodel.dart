import 'package:flutter/material.dart';
import '../models/event_models.dart';
import '../services/api_service.dart';
import '../services/logger_service.dart';

enum EventLoadStatus { initial, loading, loaded, error }

class EventViewModel with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final LoggerService _logger = LoggerService();
  
  EventLoadStatus _status = EventLoadStatus.initial;
  String _errorMessage = '';
  List<Event> _events = [];
  List<Event> _companyEvents = [];
  Event? _selectedEvent;
  
  // Getters
  EventLoadStatus get status => _status;
  String get errorMessage => _errorMessage;
  List<Event> get events => [..._events, ..._companyEvents];
  List<Event> get userEvents => _events;
  List<Event> get companyEvents => _companyEvents;
  Event? get selectedEvent => _selectedEvent;
  bool get isLoading => _status == EventLoadStatus.loading;
  
  // Tüm etkinlikleri yükle
  Future<void> loadEvents({int groupID = 0, bool includeCompanyEvents = true}) async {
    _status = EventLoadStatus.loading;
    _errorMessage = '';
    notifyListeners();
    
    try {
      _logger.i('Etkinlikler yükleniyor (Grup ID: $groupID)');
      final response = await _apiService.getEvents(groupID: groupID);
      
      if (response.success && response.data != null) {
        _events = response.data!.events;
        _logger.i('${_events.length} etkinlik başarıyla yüklendi');
        
        // Şirket etkinliklerini yükle
        if (includeCompanyEvents) {
          await _loadCompanyEvents();
        }
        
        _status = EventLoadStatus.loaded;
      } else {
        _errorMessage = response.errorMessage ?? 'Etkinlikler alınamadı';
        _status = EventLoadStatus.error;
        _logger.w('Etkinlikler yükleme başarısız: $_errorMessage');
      }
    } catch (e) {
      _errorMessage = 'Bir hata oluştu: ${e.toString()}';
      _status = EventLoadStatus.error;
      _logger.e('Etkinlikler yükleme hatası:', e);
    } finally {
      notifyListeners();
    }
  }
  
  // Şirket etkinliklerini yükle
  Future<void> _loadCompanyEvents() async {
    try {
      _logger.i('Şirket etkinlikleri yükleniyor');
      final response = await _apiService.getCompanyEvents();
      
      if (response.success && response.data != null) {
        _companyEvents = response.data!.events;
        _logger.i('${_companyEvents.length} şirket etkinliği başarıyla yüklendi');
      } else {
        _logger.w('Şirket etkinlikleri yüklenemedi: ${response.errorMessage}');
        _companyEvents = [];
      }
    } catch (e) {
      _logger.e('Şirket etkinlikleri yükleme hatası:', e);
      _companyEvents = [];
    }
  }
  
  // Sadece şirket etkinliklerini yükle
  Future<void> loadCompanyEventsOnly() async {
    _status = EventLoadStatus.loading;
    _errorMessage = '';
    _events = []; // Kullanıcı etkinliklerini temizle
    notifyListeners();
    
    try {
      await _loadCompanyEvents();
      _status = EventLoadStatus.loaded;
    } catch (e) {
      _errorMessage = 'Bir hata oluştu: ${e.toString()}';
      _status = EventLoadStatus.error;
    } finally {
      notifyListeners();
    }
  }
  
  // Etkinlik detayı getir
  Future<void> getEventDetail(int eventID) async {
    _status = EventLoadStatus.loading;
    notifyListeners();
    
    try {
      _logger.i('Etkinlik detayı yükleniyor (ID: $eventID)');
      final response = await _apiService.getEventDetail(eventID);
      
      if (response.success && response.data != null) {
        _selectedEvent = response.data;
        _status = EventLoadStatus.loaded;
        _logger.i('Etkinlik detayı başarıyla yüklendi: ${_selectedEvent?.eventTitle}');
      } else {
        _errorMessage = response.errorMessage ?? 'Etkinlik detayı alınamadı';
        _status = EventLoadStatus.error;
        _logger.w('Etkinlik detayı yükleme başarısız: $_errorMessage');
      }
    } catch (e) {
      _errorMessage = 'Bir hata oluştu: ${e.toString()}';
      _status = EventLoadStatus.error;
      _logger.e('Etkinlik detayı yükleme hatası:', e);
    } finally {
      notifyListeners();
    }
  }
  
  // Etkinlik oluştur
  Future<bool> createEvent({
    required int groupID,
    required String eventTitle,
    required String eventDesc,
    required String eventDate,
  }) async {
    _status = EventLoadStatus.loading;
    notifyListeners();
    
    try {
      _logger.i('Etkinlik oluşturuluyor: $eventTitle');
      final response = await _apiService.createEvent(
        groupID: groupID,
        eventTitle: eventTitle,
        eventDesc: eventDesc,
        eventDate: eventDate,
      );
      
      if (response['success'] == true) {
        // Etkinlik oluşturulduktan sonra listeyi yenile
        await loadEvents(groupID: groupID);
        _logger.i('Etkinlik başarıyla oluşturuldu');
        return true;
      } else {
        _errorMessage = response['message'] ?? 'Etkinlik oluşturulamadı';
        _status = EventLoadStatus.error;
        _logger.w('Etkinlik oluşturma başarısız: $_errorMessage');
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Bir hata oluştu: ${e.toString()}';
      _status = EventLoadStatus.error;
      _logger.e('Etkinlik oluşturma hatası:', e);
      notifyListeners();
      return false;
    }
  }
  
  // Etkinlik güncelle
  Future<bool> updateEvent({
    required int eventID,
    required String eventTitle,
    required String eventDesc,
    required String eventDate,
    required int eventStatus,
    int groupID = 0,
  }) async {
    _status = EventLoadStatus.loading;
    notifyListeners();
    
    try {
      _logger.i('Etkinlik güncelleniyor (ID: $eventID): $eventTitle');
      final response = await _apiService.updateEvent(
        eventID: eventID,
        eventTitle: eventTitle,
        eventDesc: eventDesc,
        eventDate: eventDate,
        eventStatus: eventStatus,
      );
      
      if (response['success'] == true) {
        // Etkinlik güncellendikten sonra listeyi yenile
        await loadEvents(groupID: groupID);
        _logger.i('Etkinlik başarıyla güncellendi');
        return true;
      } else {
        _errorMessage = response['message'] ?? 'Etkinlik güncellenemedi';
        _status = EventLoadStatus.error;
        _logger.w('Etkinlik güncelleme başarısız: $_errorMessage');
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Bir hata oluştu: ${e.toString()}';
      _status = EventLoadStatus.error;
      _logger.e('Etkinlik güncelleme hatası:', e);
      notifyListeners();
      return false;
    }
  }
  
  // Etkinlik sil
  Future<bool> deleteEvent(int eventID, {int groupID = 0}) async {
    try {
      _logger.i('Etkinlik siliniyor (ID: $eventID)');
      final response = await _apiService.deleteEvent(eventID);
      
      if (response['success'] == true) {
        // Etkinlik silindikten sonra listeyi yenile
        await loadEvents(groupID: groupID);
        _logger.i('Etkinlik başarıyla silindi');
        return true;
      } else {
        _errorMessage = response['message'] ?? 'Etkinlik silinemedi';
        _logger.w('Etkinlik silme başarısız: $_errorMessage');
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Bir hata oluştu: ${e.toString()}';
      _logger.e('Etkinlik silme hatası:', e);
      notifyListeners();
      return false;
    }
  }
  
  // Tarihi formatla
  String formatEventDate(String eventDate) {
    // Örnek tarih formatı: "27.04.2025 19:00"
    try {
      final parts = eventDate.split(' ');
      if (parts.length != 2) return eventDate;
      
      final datePart = parts[0]; // 27.04.2025
      final timePart = parts[1]; // 19:00
      
      return '$datePart $timePart';
    } catch (e) {
      return eventDate;
    }
  }
} 