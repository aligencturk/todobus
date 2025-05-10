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
      final groups = await _apiService.getGroups();
      
      _groups = groups;
      _status = GroupLoadStatus.loaded;
      _logger.i('${_groups.length} grup yüklendi');
    } catch (e) {
      _status = GroupLoadStatus.error;
      _errorMessage = e.toString();
      _logger.e('Gruplar yüklenirken hata: $e');
    } finally {
      notifyListeners();
    }
  }
  
  // Grup oluşturma
  Future<bool> createGroup(String groupName, String groupDesc) async {
    try {
      _status = GroupLoadStatus.loading;
      _errorMessage = '';
      notifyListeners();
      
      final success = await _apiService.createGroup(groupName, groupDesc);
      
      if (success) {
        // Grup başarıyla oluşturulduğunda grupları yeniden yükle
        await loadGroups();
        return true;
      }
      
      return false;
    } catch (e) {
      _status = GroupLoadStatus.error;
      _errorMessage = e.toString();
      _logger.e('Grup oluşturulurken hata: $e');
      notifyListeners();
      return false;
    }
  }
  
  // Grup güncelleme
  Future<bool> updateGroup(int groupID, String groupName, String groupDesc) async {
    try {
      _status = GroupLoadStatus.loading;
      _errorMessage = '';
      notifyListeners();
      
      final success = await _apiService.updateGroup(groupID, groupName, groupDesc);
      
      if (success) {
        // Grup başarıyla güncellendiğinde grupları yeniden yükle
        await loadGroups();
        return true;
      }
      
      return false;
    } catch (e) {
      _status = GroupLoadStatus.error;
      _errorMessage = e.toString();
      _logger.e('Grup güncellenirken hata: $e');
      notifyListeners();
      return false;
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