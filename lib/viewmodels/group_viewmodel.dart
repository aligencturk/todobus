import 'package:flutter/material.dart';
import '../models/group_models.dart';
import '../services/api_service.dart';
import '../services/logger_service.dart';

enum GroupLoadStatus { initial, loading, loaded, error }

class GroupViewModel with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final LoggerService _logger = LoggerService();
  
  GroupLoadStatus _status = GroupLoadStatus.initial;
  String _errorMessage = '';
  List<Group> _groups = [];
  
  // Getters
  GroupLoadStatus get status => _status;
  String get errorMessage => _errorMessage;
  List<Group> get groups => _groups;
  bool get hasGroups => _groups.isNotEmpty;
  int get totalProjects => _groups.fold(0, (sum, group) => sum + group.projects.length);
  
  // Grup listesini yükle
  Future<void> loadGroups() async {
    if (_status == GroupLoadStatus.loading) return;
    
    try {
      _status = GroupLoadStatus.loading;
      _errorMessage = '';
      notifyListeners();
      
      _logger.i('Grup listesi yükleniyor');
      final response = await _apiService.getGroups();
      
      if (response.success && response.data != null) {
        _groups = response.data!.groups;
        _status = GroupLoadStatus.loaded;
        _logger.i('${_groups.length} grup yüklendi');
      } else {
        _errorMessage = response.errorMessage ?? 'Grup listesi alınamadı';
        _status = GroupLoadStatus.error;
        _logger.w('Grup listesi yükleme başarısız: $_errorMessage');
      }
    } catch (e) {
      _errorMessage = 'Bir hata oluştu: ${e.toString()}';
      _status = GroupLoadStatus.error;
      _logger.e('Grup listesi yükleme hatası:', e);
    } finally {
      notifyListeners();
    }
  }
  
  // Grupları adlarına göre sırala (A-Z)
  void sortGroupsByName() {
    _groups.sort((a, b) => a.groupName.compareTo(b.groupName));
    notifyListeners();
  }
  
  // Grupları oluşturma tarihine göre sırala (yeniden eskiye)
  void sortGroupsByDate() {
    _groups.sort((a, b) => b.createDate.compareTo(a.createDate));
    notifyListeners();
  }
  
  // Grupları proje sayısına göre sırala (çoktan aza)
  void sortGroupsByProjectCount() {
    _groups.sort((a, b) => b.projects.length.compareTo(a.projects.length));
    notifyListeners();
  }
  
  // Durumu sıfırla
  void reset() {
    _status = GroupLoadStatus.initial;
    _errorMessage = '';
    _groups = [];
    notifyListeners();
  }
} 