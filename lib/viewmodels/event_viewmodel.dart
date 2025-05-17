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
  bool _isDisposed = false;
  
  // Getters
  EventLoadStatus get status => _status;
  String get errorMessage => _errorMessage;
  List<Event> get events => [..._events, ..._companyEvents];
  List<Event> get userEvents => _events;
  List<Event> get companyEvents => _companyEvents;
  Event? get selectedEvent => _selectedEvent;
  bool get isLoading => _status == EventLoadStatus.loading;
  
  // Güvenli notifyListeners
  void _safeNotifyListeners() {
    if (!_isDisposed) {
      Future.microtask(() => notifyListeners());
    }
  }
  
  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
  
  // Tüm etkinlikleri yükle
  Future<void> loadEvents({int groupID = 0, bool includeCompanyEvents = true}) async {
    _status = EventLoadStatus.loading;
    _errorMessage = '';
    _safeNotifyListeners();
    
    try {
      _logger.i('Etkinlikler yükleniyor (Grup ID: $groupID)');
      final response = await _apiService.event.getEvents(groupID: groupID);
      
      if (response.success && response.data != null) {
        _events = response.data!.events;
        _logger.i('${_events.length} etkinlik başarıyla yüklendi');
        
        
        
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
      _safeNotifyListeners();
    }
  }
  
  // Etkinlik detayı getir
  Future<void> getEventDetail(int eventID) async {
    _status = EventLoadStatus.loading;
    _safeNotifyListeners();
    
    try {
      _logger.i('Etkinlik detayı yükleniyor (ID: $eventID)');
      final response = await _apiService.event.getEventDetail(eventID);
      
      if (response.success && response.data != null) {
        _selectedEvent = response.data;
        
        // userFullname boş gelirse API'den bu değeri doğru şekilde almadığımızdan emin olalım
        if (_selectedEvent!.userFullname.isEmpty) {
          _logger.w('Etkinlik detayında userFullname boş geldi, API yanıtını kontrol edin');
        }
        
        _status = EventLoadStatus.loaded;
        _logger.i('Etkinlik detayı başarıyla yüklendi: ${_selectedEvent?.eventTitle}, Oluşturan: ${_selectedEvent?.userFullname}');
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
      _safeNotifyListeners();
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
    _safeNotifyListeners();
    
    try {
      _logger.i('Etkinlik oluşturuluyor: $eventTitle');
      final response = await _apiService.event.createEvent(
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
        _safeNotifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Bir hata oluştu: ${e.toString()}';
      _status = EventLoadStatus.error;
      _logger.e('Etkinlik oluşturma hatası:', e);
      _safeNotifyListeners();
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
    _safeNotifyListeners();
    
    try {
      _logger.i('Etkinlik güncelleniyor (ID: $eventID): $eventTitle');
      final response = await _apiService.event.updateEvent(
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
        _safeNotifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Bir hata oluştu: ${e.toString()}';
      _status = EventLoadStatus.error;
      _logger.e('Etkinlik güncelleme hatası:', e);
      _safeNotifyListeners();
      return false;
    }
  }
  
  // Etkinlik sil
  Future<bool> deleteEvent(int eventID, {int groupID = 0}) async {
    try {
      _logger.i('Etkinlik siliniyor (ID: $eventID)');
      final response = await _apiService.event.deleteEvent(eventID);
      
      if (response['success'] == true) {
        // Etkinlik silindikten sonra listeyi yenile
        await loadEvents(groupID: groupID);
        _logger.i('Etkinlik başarıyla silindi');
        return true;
      } else {
        _errorMessage = response['message'] ?? 'Etkinlik silinemedi';
        _logger.w('Etkinlik silme başarısız: $_errorMessage');
        _safeNotifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Bir hata oluştu: ${e.toString()}';
      _logger.e('Etkinlik silme hatası:', e);
      _safeNotifyListeners();
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
  
  // ViewModel'i sıfırla
  void reset() {
    _status = EventLoadStatus.initial;
    _errorMessage = '';
    _events = [];
    _companyEvents = [];
    _selectedEvent = null;
    _safeNotifyListeners();
  }
} 