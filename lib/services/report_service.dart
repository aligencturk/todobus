import '../models/group_models.dart';
import '../services/logger_service.dart';
import '../services/storage_service.dart';
import 'base_api_service.dart';

class ReportService {
  static final ReportService _instance = ReportService._internal();
  final BaseApiService _apiService = BaseApiService();
  final StorageService _storageService = StorageService();
  final LoggerService _logger = LoggerService();

  factory ReportService() {
    return _instance;
  }

  ReportService._internal();

  // Grup raporlarını getir
  Future<List<GroupReport>> getGroupReports(int groupID) async {
    try {
      final userToken = await _storageService.getToken();
      if (userToken == null) {
        throw Exception('Oturum bilgisi bulunamadı');
      }

      final response = await _apiService.post(
        'service/user/report/list',
        body: {
          'userToken': userToken,
          'groupID': groupID,
          'projectID': 0,
        },
        requiresToken: true,
      );

      if (response['success'] == true && response['data'] != null && response['data']['reports'] != null) {
        final reportsList = List<GroupReport>.from(
          response['data']['reports'].map((report) => GroupReport.fromJson(report))
        );
        _logger.i('Grup raporları alındı: ${reportsList.length} adet');
        return reportsList;
      } else {
        _logger.w('Raporlar alınamadı: ${response['errorMessage'] ?? 'Bilinmeyen hata'}');
        return [];
      }
    } catch (e) {
      _logger.e('Raporlar alınırken hata: $e');
      throw Exception('Raporlar alınamadı: $e');
    }
  }

  // Proje raporlarını getir
  Future<List<GroupReport>> getProjectReports(int projectID, int groupID) async {
    try {
      final userToken = await _storageService.getToken();
      if (userToken == null) {
        throw Exception('Oturum bilgisi bulunamadı');
      }

      final response = await _apiService.post(
        'service/user/report/list',
        body: {
          'userToken': userToken,
          'groupID': groupID,
          'projectID': projectID,
        },
        requiresToken: true,
      );

      if (response['success'] == true && response['data'] != null && response['data']['reports'] != null) {
        final reportsList = List<GroupReport>.from(
          response['data']['reports'].map((report) => GroupReport.fromJson(report))
        );
        _logger.i('Proje raporları alındı: ${reportsList.length} adet');
        return reportsList;
      } else {
        _logger.w('Proje raporları alınamadı: ${response['errorMessage'] ?? 'Bilinmeyen hata'}');
        return [];
      }
    } catch (e) {
      _logger.e('Proje raporları alınırken hata: $e');
      throw Exception('Proje raporları alınamadı: $e');
    }
  }
  
  // Kullanıcının tüm raporlarını getir
  Future<List<GroupReport>> getUserReports() async {
    try {
      final userToken = await _storageService.getToken();
      if (userToken == null) {
        throw Exception('Oturum bilgisi bulunamadı');
      }

      final response = await _apiService.post(
        'service/user/report/list',
        body: {
          'userToken': userToken,
          'groupID': 0,
          'projectID': 0,
        },
        requiresToken: true,
      );

      if (response['success'] == true && response['data'] != null && response['data']['reports'] != null) {
        final reportsList = List<GroupReport>.from(
          response['data']['reports'].map((report) => GroupReport.fromJson(report))
        );
        _logger.i('Kullanıcı raporları alındı: ${reportsList.length} adet');
        return reportsList;
      } else {
        _logger.w('Kullanıcı raporları alınamadı: ${response['errorMessage'] ?? 'Bilinmeyen hata'}');
        return [];
      }
    } catch (e) {
      _logger.e('Kullanıcı raporları alınırken hata: $e');
      throw Exception('Kullanıcı raporları alınamadı: $e');
    }
  }

  // Rapor detayını getir
  Future<GroupReport> getReportDetail(int reportID) async {
    try {
      final userToken = await _storageService.getToken();
      if (userToken == null) {
        throw Exception('Oturum bilgisi bulunamadı');
      }

      final response = await _apiService.post(
        'service/user/report/id',
        body: {
          'userToken': userToken,
          'reportID': reportID,
        },
        requiresToken: true,
      );

      if (response['success'] == true && response['data'] != null) {
        final reportDetail = GroupReport.fromJson(response['data']);
        _logger.i('Rapor detayı alındı: ${reportDetail.reportTitle}');
        return reportDetail;
      } else {
        throw Exception(response['errorMessage'] ?? 'Rapor detayı alınamadı');
      }
    } catch (e) {
      _logger.e('Rapor detayı alınırken hata: $e');
      throw Exception('Rapor detayı alınamadı: $e');
    }
  }
  
  // Rapor oluştur
  Future<bool> createReport({
    required int groupID,
    required int projectID,
    required String reportTitle, 
    required String reportDesc,
    required String reportDate,
  }) async {
    try {
      final userToken = await _storageService.getToken();
      if (userToken == null) {
        throw Exception('Oturum bilgisi bulunamadı');
      }

      final response = await _apiService.post(
        'service/user/report/add',
        body: {
          'userToken': userToken,
          'groupID': groupID,
          'projectID': projectID,
          'reportTitle': reportTitle,
          'reportDesc': reportDesc,
          'reportDate': reportDate,
        },
        requiresToken: true,
      );

      if (response['success'] == true) {
        _logger.i('Rapor başarıyla oluşturuldu: $reportTitle');
        return true;
      } else {
        _logger.w('Rapor oluşturulamadı: ${response['errorMessage'] ?? 'Bilinmeyen hata'}');
        return false;
      }
    } catch (e) {
      _logger.e('Rapor oluşturulurken hata: $e');
      throw Exception('Rapor oluşturulamadı: $e');
    }
  }
  
  // Rapor güncelle
  Future<bool> updateReport({
    required int reportID,
    required int groupID,
    required int projectID,
    required String reportTitle, 
    required String reportDesc,
    required String reportDate,
  }) async {
    try {
      final userToken = await _storageService.getToken();
      if (userToken == null) {
        throw Exception('Oturum bilgisi bulunamadı');
      }

      final response = await _apiService.put(

        'service/user/report/update',
        body: {
          'userToken': userToken,
          'reportID': reportID,
          'groupID': groupID,
          'projectID': projectID,
          'reportTitle': reportTitle,
          'reportDesc': reportDesc,
          'reportDate': reportDate,
        },
        requiresToken: true,
      );

      if (response['success'] == true) {
        _logger.i('Rapor başarıyla güncellendi: $reportTitle');
        return true;
      } else {
        _logger.w('Rapor güncellenemedi: ${response['errorMessage'] ?? 'Bilinmeyen hata'}');
        return false;
      }
    } catch (e) {
      _logger.e('Rapor güncellenirken hata: $e');
      throw Exception('Rapor güncellenemedi: $e');
    }
  }
  
  // Rapor sil
  Future<bool> deleteReport(int reportID) async {
    try {
      final userToken = await _storageService.getToken();
      if (userToken == null) {
        throw Exception('Oturum bilgisi bulunamadı');
      }

      final response = await _apiService.delete(
        'service/user/report/delete',
        body: {
          'userToken': userToken,
          'reportID': reportID,
        },
        requiresToken: true,
      );

      if (response['success'] == true) {
        _logger.i('Rapor başarıyla silindi: ID $reportID');
        return true;
      } else {
        _logger.w('Rapor silinemedi: ${response['errorMessage'] ?? 'Bilinmeyen hata'}');
        return false;
      }
    } catch (e) {
      _logger.e('Rapor silinirken hata: $e');
      throw Exception('Rapor silinemedi: $e');
    }
  }
} 