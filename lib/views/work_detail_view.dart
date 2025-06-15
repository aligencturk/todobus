import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:provider/provider.dart';
import '../models/group_models.dart';
import '../services/logger_service.dart';
import '../viewmodels/group_viewmodel.dart';
import '../services/snackbar_service.dart';
import '../views/work_edit_view.dart';

class WorkDetailView extends StatefulWidget {
  final int projectId;
  final int groupId;
  final int workId;
  
  const WorkDetailView({
    Key? key,
    required this.projectId,
    required this.groupId,
    required this.workId,
  }) : super(key: key);
  
  @override
  State<WorkDetailView> createState() => _WorkDetailViewState();
}

class _WorkDetailViewState extends State<WorkDetailView> {
  final LoggerService _logger = LoggerService();
  final SnackBarService _snackBarService = SnackBarService();
  
  bool _isLoading = true;
  String _errorMessage = '';
  ProjectWork? _workDetail;
  
  @override
  void initState() {
    super.initState();
    _loadWorkDetail();
  }
  
  Future<void> _loadWorkDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      final workDetail = await Provider.of<GroupViewModel>(context, listen: false)
          .getWorkDetail(widget.projectId, widget.workId);
      
      if (mounted) {
        setState(() {
          _workDetail = workDetail;
          _isLoading = false;
        });
        _logger.i('Görev detayları yüklendi: ${workDetail?.workName}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Görev detayları yüklenemedi: $e';
          _isLoading = false;
        });
        _logger.e('Görev detayları yüklenirken hata: $e');
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: Text(_workDetail?.workName ?? 'Görev Detayı'),
        trailingActions: _workDetail != null
            ? [
                PlatformIconButton(
                  icon: Icon(
                    isCupertino(context) ? CupertinoIcons.pencil : Icons.edit,
                  ),
                  onPressed: _editWork,
                ),
              ]
            : null,
      ),
      body: SafeArea(
        child: _isLoading
            ? Center(child: PlatformCircularProgressIndicator())
            : _errorMessage.isNotEmpty
                ? _buildErrorView(context)
                : _buildWorkDetailView(context),
      ),
    );
  }
  
  Widget _buildErrorView(BuildContext context) {
    final isIOS = isCupertino(context);
    
    return SingleChildScrollView(
      child: Center(
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
                'İşlem Tamamlanamadı',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isIOS ? CupertinoColors.label : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _formatErrorMessage(_errorMessage),
                style: TextStyle(
                  color: isIOS ? CupertinoColors.systemGrey : Colors.grey[700],
                  fontSize: 15,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              PlatformElevatedButton(
                onPressed: _loadWorkDetail,
                child: const Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  String _formatErrorMessage(String errorMessage) {
    // Exception: hatası gibi prefix'leri kaldır
    if (errorMessage.startsWith('Exception: ')) {
      errorMessage = errorMessage.substring('Exception: '.length);
    }
    
    // HTTP kodlarını temizle
    final regExp = RegExp(r'\b\d{3}\b');
    errorMessage = errorMessage.replaceAll(regExp, '');
    
    // Teknik detayları içeren uzun hataları kısalt
    if (errorMessage.length > 120) {
      return '${errorMessage.substring(0, 120)}...';
    }
    
    return errorMessage;
  }
  
  Widget _buildWorkDetailView(BuildContext context) {
    if (_workDetail == null) {
      return const Center(child: Text('Görev detayları bulunamadı'));
    }
    
    final work = _workDetail!;
    final isIOS = isCupertino(context);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Görev durumu başlık kartı
          Card(
            margin: EdgeInsets.zero,
            elevation: isIOS ? 0 : 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: isIOS ? BorderSide(color: CupertinoColors.systemGrey5) : BorderSide.none,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: work.workCompleted
                              ? (isIOS ? CupertinoColors.systemGreen : Colors.green).withOpacity(0.2)
                              : (isIOS ? CupertinoColors.systemGrey : Colors.grey).withOpacity(0.2),
                        ),
                        padding: const EdgeInsets.all(10),
                        child: Icon(
                          work.workCompleted
                              ? (isIOS ? CupertinoIcons.checkmark_alt : Icons.check)
                              : (isIOS ? CupertinoIcons.time : Icons.schedule),
                          size: 20,
                          color: work.workCompleted
                              ? (isIOS ? CupertinoColors.systemGreen : Colors.green)
                              : (isIOS ? CupertinoColors.systemGrey : Colors.grey),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              work.workName,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isIOS ? CupertinoColors.label : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              work.workCompleted ? 'Tamamlandı' : 'Devam Ediyor',
                              style: TextStyle(
                                fontSize: 14,
                                color: work.workCompleted
                                    ? (isIOS ? CupertinoColors.systemGreen : Colors.green)
                                    : (isIOS ? CupertinoColors.systemOrange : Colors.orange),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PlatformIconButton(
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          work.workCompleted
                              ? (isIOS ? CupertinoIcons.checkmark_square_fill : Icons.check_box)
                              : (isIOS ? CupertinoIcons.square : Icons.check_box_outline_blank),
                          color: work.workCompleted
                              ? (isIOS ? CupertinoColors.systemGreen : Colors.green)
                              : (isIOS ? CupertinoColors.systemGrey : Colors.grey),
                        ),
                        onPressed: _toggleWorkCompletionStatus,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Görev detayları
          Text(
            'Detaylar',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isIOS ? CupertinoColors.label : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: isIOS ? 0 : 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: isIOS ? BorderSide(color: CupertinoColors.systemGrey5) : BorderSide.none,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (work.workDesc.isNotEmpty) ...[
                    Text(
                      'Açıklama',
                      style: TextStyle(
                        fontSize: 14,
                        color: isIOS ? CupertinoColors.secondaryLabel : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      work.workDesc,
                      style: TextStyle(
                        fontSize: 15,
                        color: isIOS ? CupertinoColors.label : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Divider(),
                  ],
                  _buildInfoRow(
                    context,
                    icon: isIOS ? CupertinoIcons.calendar : Icons.calendar_today,
                    label: 'Başlangıç Tarihi',
                    value: work.workStartDate,
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    context,
                    icon: isIOS ? CupertinoIcons.calendar_badge_plus : Icons.event,
                    label: 'Bitiş Tarihi',
                    value: work.workEndDate,
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    context,
                    icon: isIOS ? CupertinoIcons.clock : Icons.access_time,
                    label: 'Oluşturma Tarihi',
                    value: work.workCreateDate,
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Atanmış kullanıcılar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Atanmış Kullanıcılar (${work.workUsers.length})',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isIOS ? CupertinoColors.label : Colors.black87,
                ),
              ),
              PlatformIconButton(
                padding: EdgeInsets.zero,
                icon: Icon(
                  isIOS ? CupertinoIcons.person_add : Icons.person_add,
                  color: isIOS ? CupertinoColors.activeBlue : Colors.blue,
                  size: 20,
                ),
                onPressed: _editWork,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (work.workUsers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Center(
                child: Text(
                  'Henüz kullanıcı atanmamış',
                  style: TextStyle(
                    color: isIOS ? CupertinoColors.secondaryLabel : Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            )
          else
            Card(
              elevation: isIOS ? 0 : 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: isIOS ? BorderSide(color: CupertinoColors.systemGrey5) : BorderSide.none,
              ),
              child: ListView.separated(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: work.workUsers.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final user = work.workUsers[index];
                  return ListTile(
                    title: Text(user.userName),
                    subtitle: Text('Atanma: ${user.assignedDate}'),
                    leading: CircleAvatar(
                      backgroundColor: (isIOS ? CupertinoColors.systemGrey : Colors.grey).withOpacity(0.2),
                      child: Text(
                        user.userName.substring(0, 1).toUpperCase(),
                        style: TextStyle(
                          color: isIOS ? CupertinoColors.systemGrey : Colors.grey,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          
          const SizedBox(height: 32),
          
          // İşlem butonları
          Row(
            children: [
              Expanded(
                child: PlatformElevatedButton(
                  onPressed: _editWork,
                  material: (_, __) => MaterialElevatedButtonData(
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                  cupertino: (_, __) => CupertinoElevatedButtonData(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text('Görevi Düzenle'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: PlatformElevatedButton(
                  onPressed: _toggleWorkCompletionStatus,
                  material: (_, __) => MaterialElevatedButtonData(
                    style: ElevatedButton.styleFrom(
                      foregroundColor: work.workCompleted ? Colors.orange : Colors.green,
                      backgroundColor: work.workCompleted 
                          ? Colors.orange.withOpacity(0.1) 
                          : Colors.green.withOpacity(0.1),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                  cupertino: (_, __) => CupertinoElevatedButtonData(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    work.workCompleted
                        ? 'Tamamlanmadı Olarak İşaretle'
                        : 'Tamamlandı Olarak İşaretle',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: PlatformElevatedButton(
                  onPressed: _confirmDeleteWork,
                  material: (_, __) => MaterialElevatedButtonData(
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                  cupertino: (_, __) => CupertinoElevatedButtonData(
                    color: CupertinoColors.destructiveRed,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    'Görevi Sil',
                    style: TextStyle(
                      color: isIOS ? CupertinoColors.white : Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoRow(BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final isIOS = isCupertino(context);
    
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: isIOS ? CupertinoColors.secondaryLabel : Colors.grey[600],
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isIOS ? CupertinoColors.secondaryLabel : Colors.grey[600],
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: isIOS ? CupertinoColors.label : Colors.black87,
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  // Görev durumunu değiştirme
  void _toggleWorkCompletionStatus() async {
    if (_workDetail == null) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final success = await Provider.of<GroupViewModel>(context, listen: false)
          .changeWorkCompletionStatus(
            widget.projectId,
            widget.workId,
            !_workDetail!.workCompleted,  // Mevcut durumun tersini gönder
          );
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        if (success) {
          // Görev durumu değiştiyse detayları yeniden yükle
          await _loadWorkDetail();
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _workDetail!.workCompleted 
                  ? 'Görev tamamlandı olarak işaretlendi' 
                  : 'Görev tamamlanmadı olarak işaretlendi'
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          _showErrorSnackbar('Görev durumu değiştirilemedi');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        _showErrorSnackbar(_formatErrorMessage(e.toString()));
      }
    }
  }
  
  // Görevi düzenleme
  void _editWork() async {
    if (_workDetail == null) return;
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WorkEditView(
          projectId: widget.projectId,
          groupId: widget.groupId,
          workId: widget.workId,
        ),
      ),
    );
    
    // Eğer düzenleme başarılı olduysa detayları yeniden yükle
    if (result == true) {
      _loadWorkDetail();
    }
  }
  
  // Görev silme doğrulama
  void _confirmDeleteWork() {
    if (_workDetail == null) return;
    
    final isIOS = isCupertino(context);
    
    if (isIOS) {
      showCupertinoDialog(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: const Text('Görevi Sil'),
          content: Text('${_workDetail!.workName} görevini silmek istediğinize emin misiniz?'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('İptal'),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.pop(dialogContext);
                _deleteWork();
              },
              child: const Text('Sil'),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Görevi Sil'),
          content: Text('${_workDetail!.workName} görevini silmek istediğinize emin misiniz?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('İptal'),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              onPressed: () {
                Navigator.pop(dialogContext);
                _deleteWork();
              },
              child: const Text('Sil'),
            ),
          ],
        ),
      );
    }
  }
  
  // Görevi silme
  void _deleteWork() async {
    if (_workDetail == null) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final success = await Provider.of<GroupViewModel>(context, listen: false)
          .deleteProject(widget.projectId, widget.workId);
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        if (success) {
          _snackBarService.showSuccess('Görev başarıyla silindi');
          
          // Görev silindikten sonra önceki sayfaya dön
          Navigator.of(context).pop(true);
        } else {
          _showErrorSnackbar('Görev silinemedi');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        _showErrorSnackbar(_formatErrorMessage(e.toString()));
      }
    }
  }

  // Hata mesajı göster
  void _showErrorSnackbar(String errorMessage) {
    if (!mounted) return;
    
    try {
      _snackBarService.showError(_snackBarService.formatErrorMessage(errorMessage));
    } catch (e) {
      _logger.e('SnackBar gösterilirken hata: $e');
    }
  }
} 