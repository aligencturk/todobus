import 'dart:async';
import 'package:flutter/material.dart';
import '../models/group_models.dart';
import '../services/api_service.dart';
import '../services/logger_service.dart';
import '../services/refresh_service.dart';

enum ReportLoadStatus { initial, loading, loaded, error, updating, deleting }

class ReportViewModel with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final LoggerService _logger = LoggerService();
  final RefreshService _refreshService = RefreshService();
  
  ReportLoadStatus _status = ReportLoadStatus.initial;
  String _errorMessage = '';
  List<GroupReport> _reports = [];
  GroupReport? _selectedReport;
  bool _isDisposed = false;
  StreamSubscription? _refreshSubscription;
  
  // Getters
  ReportLoadStatus get status => _status;
  String get errorMessage => _errorMessage;
  List<GroupReport> get reports => _reports;
  GroupReport? get selectedReport => _selectedReport;
  bool get isLoading => _status == ReportLoadStatus.loading;
  
  ReportViewModel() {
    _initRefreshListener();
  }
  
  void _initRefreshListener() {
    _refreshSubscription = _refreshService.refreshStream.listen((refreshType) {
      if (refreshType == 'reports' || refreshType == 'all') {
        loadUserReports();
      }
    });
  }
  
  // Güvenli notifyListeners
  void _safeNotifyListeners() {
    if (!_isDisposed) {
      Future.microtask(() => notifyListeners());
    }
  }
  
  @override
  void dispose() {
    _isDisposed = true;
    _refreshSubscription?.cancel();
    super.dispose();
  }
  
  // Kullanıcının tüm raporlarını yükle
  Future<void> loadUserReports() async {
    _status = ReportLoadStatus.loading;
    _safeNotifyListeners();
    
    try {
      final reports = await _apiService.report.getUserReports();
      _reports = reports;
      _status = ReportLoadStatus.loaded;
      _logger.i('Kullanıcı raporları yüklendi: ${reports.length}');
    } catch (e) {
      _errorMessage = e.toString();
      _status = ReportLoadStatus.error;
      _logger.e('Kullanıcı raporları yüklenirken hata: $e');
    }
    
    _safeNotifyListeners();
  }
  
  // Grup raporlarını yükle
  Future<List<GroupReport>> loadGroupReports(int groupId) async {
    _status = ReportLoadStatus.loading;
    _safeNotifyListeners();
    
    try {
      final reports = await _apiService.report.getGroupReports(groupId);
      _status = ReportLoadStatus.loaded;
      _logger.i('Grup raporları yüklendi: ${reports.length}');
      _safeNotifyListeners();
      return reports;
    } catch (e) {
      _errorMessage = e.toString();
      _status = ReportLoadStatus.error;
      _logger.e('Grup raporları yüklenirken hata: $e');
      _safeNotifyListeners();
      return [];
    }
  }
  
  // Proje raporlarını yükle
  Future<List<GroupReport>> loadProjectReports(int projectId, int groupId) async {
    _status = ReportLoadStatus.loading;
    _safeNotifyListeners();
    
    try {
      final reports = await _apiService.report.getProjectReports(projectId, groupId);
      _status = ReportLoadStatus.loaded;
      _logger.i('Proje raporları yüklendi: ${reports.length}');
      _safeNotifyListeners();
      return reports;
    } catch (e) {
      _errorMessage = e.toString();
      _status = ReportLoadStatus.error;
      _logger.e('Proje raporları yüklenirken hata: $e');
      _safeNotifyListeners();
      return [];
    }
  }
  
  // Rapor detayını getir
  Future<GroupReport?> getReportDetail(int reportId) async {
    _status = ReportLoadStatus.loading;
    _safeNotifyListeners();
    
    try {
      final report = await _apiService.report.getReportDetail(reportId);
      _selectedReport = report;
      _status = ReportLoadStatus.loaded;
      _logger.i('Rapor detayı yüklendi: ${report.reportTitle}');
      _safeNotifyListeners();
      return report;
    } catch (e) {
      _errorMessage = e.toString();
      _status = ReportLoadStatus.error;
      _logger.e('Rapor detayı yüklenirken hata: $e');
      _safeNotifyListeners();
      return null;
    }
  }
  
  // Rapor oluştur
  Future<bool> createReport({
    required int groupId, 
    required int projectId, 
    required String title, 
    required String desc,
    required String date,
  }) async {
    _status = ReportLoadStatus.loading;
    _safeNotifyListeners();
    
    try {
      final success = await _apiService.report.createReport(
        groupID: groupId,
        projectID: projectId,
        reportTitle: title,
        reportDesc: desc,
        reportDate: date,
      );
      
      _status = ReportLoadStatus.loaded;
      _logger.i('Rapor oluşturma sonucu: $success');
      
      if (success) {
        // Raporları yenile
        _refreshService.refreshData('reports');
      }
      
      _safeNotifyListeners();
      return success;
    } catch (e) {
      _errorMessage = e.toString();
      _status = ReportLoadStatus.error;
      _logger.e('Rapor oluşturulurken hata: $e');
      _safeNotifyListeners();
      return false;
    }
  }
  
  // Rapor güncelle
  Future<bool> updateReport({
    required int reportId,
    required int groupId,
    required int projectId,
    required String title,
    required String desc,
    required String date,
  }) async {
    _status = ReportLoadStatus.updating;
    _safeNotifyListeners();
    
    try {
      final success = await _apiService.report.updateReport(
        reportID: reportId,
        groupID: groupId,
        projectID: projectId,
        reportTitle: title,
        reportDesc: desc,
        reportDate: date,
      );
      
      _status = ReportLoadStatus.loaded;
      _logger.i('Rapor güncelleme sonucu: $success');
      
      if (success) {
        // Raporları yenile
        _refreshService.refreshData('reports');
      }
      
      _safeNotifyListeners();
      return success;
    } catch (e) {
      _errorMessage = e.toString();
      _status = ReportLoadStatus.error;
      _logger.e('Rapor güncellenirken hata: $e');
      _safeNotifyListeners();
      return false;
    }
  }
  
  // Rapor sil
  Future<bool> deleteReport(int reportId) async {
    _status = ReportLoadStatus.deleting;
    _safeNotifyListeners();
    
    try {
      final success = await _apiService.report.deleteReport(reportId);
      
      _status = ReportLoadStatus.loaded;
      _logger.i('Rapor silme sonucu: $success');
      
      if (success) {
        // Raporları yenile
        _refreshService.refreshData('reports');
      }
      
      _safeNotifyListeners();
      return success;
    } catch (e) {
      _errorMessage = e.toString();
      _status = ReportLoadStatus.error;
      _logger.e('Rapor silinirken hata: $e');
      _safeNotifyListeners();
      return false;
    }
  }
} 