import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/logger_service.dart';
import '../services/storage_service.dart';
import '../models/group_models.dart';

enum DashboardLoadStatus { initial, loading, loaded, error }

class DashboardViewModel with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final LoggerService _logger = LoggerService();
  final StorageService _storageService = StorageService();
  
  DashboardLoadStatus _status = DashboardLoadStatus.initial;
  String _errorMessage = '';
  bool _isDisposed = false;
  
  User? _user;
  int _taskCount = 0;
  String _userName = ''; // Kullanıcı adı
  
  // Etkinlikler için yeni değişkenler
  List<GroupEvent> _upcomingEvents = [];
  List<GroupDetail> _userGroups = [];
  
  // Kullanıcı görevleri için gerekli değişkenler
  List<UserProjectWork> _userTasks = [];
  bool _isLoadingTasks = false;
  String _tasksErrorMessage = '';
  
  // Getters
  DashboardLoadStatus get status => _status;
  String get errorMessage => _errorMessage;
  User? get user => _user;
  int get taskCount => _userTasks.length;
  bool get isLoading => _status == DashboardLoadStatus.loading;
  List<GroupEvent> get upcomingEvents => _upcomingEvents;
  List<UserProjectWork> get userTasks => _userTasks;
  bool get isLoadingTasks => _isLoadingTasks;
  String get tasksErrorMessage => _tasksErrorMessage;
  
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
  
  // Kullanıcı bilgilerini yükle
  Future<void> loadUserInfo() async {
    if (_status == DashboardLoadStatus.loading) return;
    
    try {
      _status = DashboardLoadStatus.loading;
      _errorMessage = '';
      _safeNotifyListeners();
      
      _logger.i('Dashboard kullanıcı bilgileri yükleniyor');
      final response = await _apiService.getUser();
      
      if (response.success && response.data != null) {
        _user = response.data!.user;
        _userName = _user?.userFullname ?? '';
        _status = DashboardLoadStatus.loaded;
        _logger.i('Kullanıcı bilgileri başarıyla yüklendi: ${_user?.userFullname}');
      } else {
        _errorMessage = response.errorMessage ?? 'Kullanıcı bilgileri alınamadı';
        _status = DashboardLoadStatus.error;
        _logger.w('Kullanıcı bilgileri yükleme başarısız: $_errorMessage');
      }
    } catch (e) {
      _errorMessage = 'Bir hata oluştu: ${e.toString()}';
      _status = DashboardLoadStatus.error;
      _logger.e('Kullanıcı bilgileri yükleme hatası:', e);
    } finally {
      _safeNotifyListeners();
    }
  }
  
  // Görev sayısını yükle - API eklendikçe güncellenecek
  Future<void> loadTaskCount() async {
    // Bu fonksiyon ileride API ile görev sayısını alacak
    _taskCount = 0; // Şimdilik varsayılan değer
    _safeNotifyListeners();
  }
  
  // Tüm verileri yükle
  Future<void> loadDashboardData() async {
    _status = DashboardLoadStatus.loading;
    _errorMessage = '';
    _safeNotifyListeners();
    
    try {
      await loadUserInfo();
      await loadUserTasks();
      await _loadUpcomingEvents();
      
      _status = DashboardLoadStatus.loaded;
      _safeNotifyListeners();
    } catch (e) {
      _status = DashboardLoadStatus.error;
      _errorMessage = 'Veriler yüklenirken bir hata oluştu: $e';
      _logger.e('Dashboard veri yüklenirken hata: $e');
      _safeNotifyListeners();
    }
  }
  
  // Kullanıcı görevlerini yükle
  Future<void> loadUserTasks() async {
    if (_isLoadingTasks) return;
    
    _isLoadingTasks = true;
    _tasksErrorMessage = '';
    _safeNotifyListeners();
    
    try {
      _logger.i('Kullanıcı görevleri yükleniyor...');
      final response = await _apiService.getUserWorks();
      
      if (response.success && response.data != null) {
        _userTasks = response.data!.works;
        
        // Görevleri tarihe göre sırala (önce yaklaşan tarihli görevler)
        _userTasks.sort((a, b) {
          if (a.workCompleted != b.workCompleted) {
            return a.workCompleted ? 1 : -1; // Tamamlanmamış olanlar önce
          }
          // Tarih formatı: 25.04.2025
          try {
            final aEndDateParts = a.workEndDate.split('.');
            final bEndDateParts = b.workEndDate.split('.');
            
            if (aEndDateParts.length != 3 || bEndDateParts.length != 3) {
              return 0;
            }
            
            final aEndDate = DateTime(
              int.parse(aEndDateParts[2]), // Yıl
              int.parse(aEndDateParts[1]), // Ay
              int.parse(aEndDateParts[0]), // Gün
            );
            
            final bEndDate = DateTime(
              int.parse(bEndDateParts[2]), // Yıl
              int.parse(bEndDateParts[1]), // Ay
              int.parse(bEndDateParts[0]), // Gün
            );
            
            return aEndDate.compareTo(bEndDate);
          } catch (e) {
            return 0;
          }
        });
        
        _logger.i('${_userTasks.length} görev başarıyla yüklendi');
        _taskCount = _userTasks.length;
      } else {
        _tasksErrorMessage = response.errorMessage ?? 'Görevler alınamadı';
        _logger.w('Görevler yükleme başarısız: $_tasksErrorMessage');
      }
    } catch (e) {
      _tasksErrorMessage = 'Bir hata oluştu: ${e.toString()}';
      _logger.e('Görevler yükleme hatası:', e);
    } finally {
      _isLoadingTasks = false;
      _safeNotifyListeners();
    }
  }
  
  // Yeni metod: Tüm grupları yükle ve detayları al
  Future<void> _loadUserGroups() async {
    try {
      final groups = await _apiService.getGroups();
      _userGroups = [];
      
      // Her grup için detay bilgilerini getir
      for (final group in groups) {
        try {
          final groupDetail = await _apiService.getGroupDetail(group.groupID);
          _userGroups.add(groupDetail);
        } catch (e) {
          _logger.w('Grup detayı yüklenemedi (ID: ${group.groupID}): $e');
        }
      }
      
      _logger.i('${_userGroups.length} grup detayı yüklendi');
    } catch (e) {
      _logger.e('Gruplar yüklenirken hata: $e');
      throw Exception('Grup bilgileri yüklenemedi: $e');
    }
  }
  
  // Yaklaşan etkinlikleri yükle
  Future<void> _loadUpcomingEvents() async {
    try {
      await _loadUserGroups(); // Önce tüm grupları yükle
      
      // Tüm gruplardan etkinlikleri al
      final allEvents = <GroupEvent>[];
      for (final group in _userGroups) {
        allEvents.addAll(group.events);
      }
      
      // Şimdiki zaman
      final now = DateTime.now();
      
      // Etkinlikleri tarihe göre filtrele ve sırala (sadece gelecek olanlar)
      _upcomingEvents = allEvents
          .where((event) {
            try {
              return event.eventDateTime.isAfter(now);
            } catch (e) {
              return false;
            }
          })
          .toList();
      
      // Tarihe göre sırala (yakın tarihli olanlar önce)
      _upcomingEvents.sort((a, b) => a.eventDateTime.compareTo(b.eventDateTime));
      
      // En fazla 5 etkinlik göster
      if (_upcomingEvents.length > 5) {
        _upcomingEvents = _upcomingEvents.sublist(0, 5);
      }
      
      _logger.i('${_upcomingEvents.length} yaklaşan etkinlik yüklendi');
    } catch (e) {
      _logger.e('Etkinlikler yüklenirken hata: $e');
      // Ana process'i durdurmamak için hata fırlatma
      _upcomingEvents = [];
    }
  }
  
  // Etkinlik tarihini formatlama
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


 