import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:provider/provider.dart';
import '../models/group_models.dart';
import '../services/logger_service.dart';
import '../services/snackbar_service.dart';
import '../viewmodels/group_viewmodel.dart';
import '../services/storage_service.dart';

class ProjectReportView extends StatefulWidget {
  final int projectId;
  final int groupId;
  final ProjectDetail? projectDetail;
  
  const ProjectReportView({
    Key? key,
    required this.projectId,
    required this.groupId,
    this.projectDetail,
  }) : super(key: key);
  
  @override
  _ProjectReportViewState createState() => _ProjectReportViewState();
}

class _ProjectReportViewState extends State<ProjectReportView> {
  final LoggerService _logger = LoggerService();
  final SnackBarService _snackBarService = SnackBarService();
  
  ProjectDetail? _projectDetail;
  List<ProjectWork>? _projectWorks;
  List<ProjectUser>? _projectUsers;
  
  bool _isLoading = true;
  String _errorMessage = '';
  
  @override
  void initState() {
    super.initState();
    _projectDetail = widget.projectDetail;
    _loadProjectData();
  }
  
  Future<void> _loadProjectData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      final groupViewModel = Provider.of<GroupViewModel>(context, listen: false);
      
      // Proje detayını yükle (eğer yoksa)
      if (_projectDetail == null) {
        _projectDetail = await groupViewModel.getProjectDetail(widget.projectId, widget.groupId);
      }
      
      // Proje görevlerini yükle
      try {
        _projectWorks = await groupViewModel.getProjectWorks(widget.projectId);
      } catch (e) {
        // 417 hata kodu normal, görev yoksa boş liste
        if (e.toString().contains('417') || e.toString().contains('Bu projeye ait henüz görev bulunmamaktadır')) {
          _projectWorks = [];
        } else {
          throw e;
        }
      }
      
      // Proje kullanıcılarını ata
      _projectUsers = _projectDetail?.users ?? [];
      
      setState(() {
        _isLoading = false;
      });
      
      _logger.i('Proje raporu verileri yüklendi');
    } catch (e) {
      setState(() {
        _errorMessage = 'Veriler yüklenemedi: $e';
        _isLoading = false;
      });
      _logger.e('Proje raporu verileri yüklenirken hata: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final isIOS = isCupertino(context);
    
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: Text('Proje Raporu'),
        leading: PlatformIconButton(
          icon: Icon(isIOS ? CupertinoIcons.back : Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? Center(child: PlatformCircularProgressIndicator())
            : _errorMessage.isNotEmpty
                ? _buildErrorView(context)
                : _buildReportContent(context),
      ),
    );
  }
  
  Widget _buildErrorView(BuildContext context) {
    final isIOS = isCupertino(context);
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isIOS ? CupertinoIcons.exclamationmark_circle : Icons.error_outline,
              size: 56,
              color: isIOS ? CupertinoColors.systemRed : Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Hata Oluştu',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isIOS ? CupertinoColors.label : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              style: TextStyle(
                color: isIOS ? CupertinoColors.systemGrey : Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            PlatformElevatedButton(
              onPressed: _loadProjectData,
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildReportContent(BuildContext context) {
    if (_projectDetail == null) return const SizedBox();
    
    final isIOS = isCupertino(context);
    final project = _projectDetail!;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Rapor başlığı
          _buildSectionTitle(context, 'Proje Raporu'),
          const SizedBox(height: 16),
          
          // Proje genel bilgileri
          _buildInfoCard(
            context,
            title: '1. Proje Genel Bilgileri',
            children: [
              _buildInfoRow('Proje Adı:', project.projectName),
              _buildInfoRow('Açıklama:', project.projectDesc.isNotEmpty ? project.projectDesc : 'Açıklama bulunmuyor'),
              _buildInfoRow('Durum:', project.projectStatus),
              _buildInfoRow('Oluşturan:', project.createdBy),
              _buildInfoRow('Başlangıç Tarihi:', project.proStartDate),
              _buildInfoRow('Bitiş Tarihi:', project.proEndDate),
              _buildInfoRow('Oluşturma Tarihi:', project.proCreateDate),
              _buildInfoRow('İlerleme:', '%${project.projectProgress}'),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Proje üyeleri
          _buildInfoCard(
            context,
            title: '2. Proje Üyeleri',
            children: [
              _buildInfoRow('Toplam Üye Sayısı:', '${_projectUsers?.length ?? 0} kişi'),
              const SizedBox(height: 8),
              if (_projectUsers != null && _projectUsers!.isNotEmpty) ...[
                Text(
                  'Üye Listesi:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isIOS ? CupertinoColors.label : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                ..._projectUsers!.asMap().entries.map((entry) {
                  int index = entry.key + 1;
                  ProjectUser user = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(left: 16, bottom: 4),
                    child: Text(
                      '• $index. ${user.userName} (${user.userRole})',
                      style: TextStyle(
                        color: isIOS ? CupertinoColors.secondaryLabel : Colors.grey[700],
                      ),
                    ),
                  );
                }).toList(),
              ] else ...[
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Text(
                    '• Henüz üye bulunmuyor',
                    style: TextStyle(
                      color: isIOS ? CupertinoColors.secondaryLabel : Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Proje görevleri
          _buildInfoCard(
            context,
            title: '3. Proje Görevleri',
            children: [
              _buildInfoRow('Toplam Görev Sayısı:', '${_projectWorks?.length ?? 0} adet'),
              if (_projectWorks != null && _projectWorks!.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildInfoRow(
                  'Tamamlanan Görevler:',
                  '${_projectWorks!.where((w) => w.workCompleted).length} adet',
                ),
                _buildInfoRow(
                  'Devam Eden Görevler:',
                  '${_projectWorks!.where((w) => !w.workCompleted).length} adet',
                ),
                const SizedBox(height: 8),
                Text(
                  'Görev Listesi:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isIOS ? CupertinoColors.label : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                ..._projectWorks!.asMap().entries.map((entry) {
                  int index = entry.key + 1;
                  ProjectWork work = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(left: 16, bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '• $index. ${work.workName} ${work.workCompleted ? "(✓ Tamamlandı)" : "(○ Devam Ediyor)"}',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: work.workCompleted 
                                ? (isIOS ? CupertinoColors.systemGreen : Colors.green)
                                : (isIOS ? CupertinoColors.systemOrange : Colors.orange),
                          ),
                        ),
                        if (work.workDesc.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.only(left: 16, top: 2),
                            child: Text(
                              'Açıklama: ${work.workDesc}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isIOS ? CupertinoColors.secondaryLabel : Colors.grey[600],
                              ),
                            ),
                          ),
                        ],
                        Padding(
                          padding: const EdgeInsets.only(left: 16, top: 2),
                          child: Text(
                            'Tarih: ${work.workStartDate} - ${work.workEndDate}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isIOS ? CupertinoColors.secondaryLabel : Colors.grey[600],
                            ),
                          ),
                        ),
                        if (work.workUsers.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.only(left: 16, top: 2),
                            child: Text(
                              'Atananlar: ${work.workUsers.map((u) => u.userName).join(", ")}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isIOS ? CupertinoColors.secondaryLabel : Colors.grey[600],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
              ] else ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Text(
                    '• Henüz görev bulunmuyor',
                    style: TextStyle(
                      color: isIOS ? CupertinoColors.secondaryLabel : Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Proje istatistikleri
          _buildInfoCard(
            context,
            title: '4. Proje İstatistikleri',
            children: [
              _buildInfoRow('Proje İlerleme Oranı:', '%${project.projectProgress}'),
              if (_projectWorks != null && _projectWorks!.isNotEmpty) ...[
                _buildInfoRow(
                  'Görev Tamamlanma Oranı:', 
                  '%${((_projectWorks!.where((w) => w.workCompleted).length / _projectWorks!.length) * 100).toStringAsFixed(1)}'
                ),
              ],
              _buildInfoRow('Aktif Üye Sayısı:', '${_projectUsers?.length ?? 0}'),
              _buildInfoRow('Proje Süresi:', _calculateProjectDuration(project.proStartDate, project.proEndDate)),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Rapor oluşturma tarihi
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isIOS 
                  ? CupertinoColors.systemGrey6
                  : Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isIOS 
                    ? CupertinoColors.systemGrey4
                    : Colors.grey[300]!,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  isIOS ? CupertinoIcons.doc_text : Icons.description,
                  size: 24,
                  color: isIOS ? CupertinoColors.systemBlue : Colors.blue,
                ),
                const SizedBox(height: 8),
                Text(
                  'Rapor Oluşturma Tarihi',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isIOS ? CupertinoColors.label : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getCurrentDate(),
                  style: TextStyle(
                    color: isIOS ? CupertinoColors.secondaryLabel : Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSectionTitle(BuildContext context, String title) {
    final isIOS = isCupertino(context);
    
    return Text(
      title,
      style: platformThemeData(
        context,
        material: (data) => data.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
        cupertino: (data) => data.textTheme.navLargeTitleTextStyle.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: CupertinoColors.label,
        ),
      ),
    );
  }
  
  Widget _buildInfoCard(BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    final isIOS = isCupertino(context);
    
    return Card(
      elevation: isIOS ? 0 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isIOS 
            ? BorderSide(color: CupertinoColors.systemGrey4) 
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isIOS ? CupertinoColors.label : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
  
  Widget _buildInfoRow(String label, String value) {
    final isIOS = isCupertino(context);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isIOS ? CupertinoColors.secondaryLabel : Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                color: isIOS ? CupertinoColors.label : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  String _calculateProjectDuration(String startDate, String endDate) {
    try {
      // DD.MM.YYYY formatından DateTime'a çevir
      final startParts = startDate.split('.');
      final endParts = endDate.split('.');
      
      if (startParts.length == 3 && endParts.length == 3) {
        final start = DateTime(
          int.parse(startParts[2]),
          int.parse(startParts[1]),
          int.parse(startParts[0]),
        );
        final end = DateTime(
          int.parse(endParts[2]),
          int.parse(endParts[1]),
          int.parse(endParts[0]),
        );
        
        final difference = end.difference(start).inDays;
        return '$difference gün';
      }
    } catch (e) {
      _logger.e('Tarih hesaplanırken hata: $e');
    }
    
    return 'Hesaplanamadı';
  }
  
  String _getCurrentDate() {
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}';
  }
} 