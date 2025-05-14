import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:provider/provider.dart';
import '../models/group_models.dart';
import '../services/logger_service.dart';
import '../viewmodels/group_viewmodel.dart';
import '../services/snackbar_service.dart';

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
    
    final work = _workDetail!;
    final isIOS = isCupertino(context);
    final TextEditingController nameController = TextEditingController(text: work.workName);
    final TextEditingController descController = TextEditingController(text: work.workDesc);
    
    // Tarih ayrıştırma: "DD.MM.YYYY" formatından DateTime'a çevirme
    DateTime parseDate(String dateStr) {
      final parts = dateStr.split('.');
      if (parts.length == 3) {
        return DateTime(
          int.parse(parts[2]), // Yıl
          int.parse(parts[1]), // Ay
          int.parse(parts[0]), // Gün
        );
      }
      return DateTime.now();
    }
    
    DateTime startDate = parseDate(work.workStartDate);
    DateTime endDate = parseDate(work.workEndDate);
    bool isCompleted = work.workCompleted;
    
    // Kullanıcıların listesi - proje viewmodel'den alınacak
    List<int> selectedUsers = work.workUsers.map((user) => user.userID).toList();
    final project = await Provider.of<GroupViewModel>(context, listen: false)
        .getProjectDetail(widget.projectId, widget.groupId);
    
    final availableUsers = project?.users ?? [];
    
    // Tarih formatlama fonksiyonu
    String formatDate(DateTime date) {
      return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
    }
    
    // Tarih seçici
    Future<DateTime?> _pickDate(BuildContext context, DateTime initialDate) async {
      if (isIOS) {
        DateTime? selectedDate;
        await showCupertinoModalPopup(
          context: context,
          builder: (BuildContext context) {
            return Container(
              height: 216,
              padding: const EdgeInsets.only(top: 6.0),
              margin: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              color: CupertinoColors.systemBackground.resolveFrom(context),
              child: SafeArea(
                top: false,
                child: CupertinoDatePicker(
                  initialDateTime: initialDate,
                  mode: CupertinoDatePickerMode.date,
                  onDateTimeChanged: (DateTime newDate) {
                    selectedDate = newDate;
                  },
                ),
              ),
            );
          },
        );
        return selectedDate;
      } else {
        return await showDatePicker(
          context: context,
          initialDate: initialDate,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
      }
    }
    
    // Dialog içeriği
    Widget dialogContent = StatefulBuilder(
      builder: (BuildContext context, StateSetter setState) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Görevi Düzenle',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isIOS ? CupertinoColors.label : Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              if (isIOS)
                CupertinoTextField(
                  controller: nameController,
                  placeholder: 'Görev Adı',
                  padding: const EdgeInsets.all(12),
                )
              else
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Görev Adı',
                    border: OutlineInputBorder(),
                  ),
                ),
              const SizedBox(height: 12),
              if (isIOS)
                CupertinoTextField(
                  controller: descController,
                  placeholder: 'Görev Açıklaması',
                  padding: const EdgeInsets.all(12),
                  maxLines: 3,
                )
              else
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: 'Görev Açıklaması',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final pickedDate = await _pickDate(context, startDate);
                        if (pickedDate != null) {
                          setState(() {
                            startDate = pickedDate;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isIOS ? CupertinoColors.systemGrey4 : Colors.grey,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Başlangıç Tarihi',
                              style: TextStyle(
                                fontSize: 12,
                                color: isIOS ? CupertinoColors.secondaryLabel : Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              formatDate(startDate),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isIOS ? CupertinoColors.label : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final pickedDate = await _pickDate(context, endDate);
                        if (pickedDate != null) {
                          setState(() {
                            endDate = pickedDate;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isIOS ? CupertinoColors.systemGrey4 : Colors.grey,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bitiş Tarihi',
                              style: TextStyle(
                                fontSize: 12,
                                color: isIOS ? CupertinoColors.secondaryLabel : Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              formatDate(endDate),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isIOS ? CupertinoColors.label : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    'Tamamlandı',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isIOS ? CupertinoColors.label : Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 16),
                  if (isIOS)
                    CupertinoSwitch(
                      value: isCompleted,
                      onChanged: (value) {
                        setState(() {
                          isCompleted = value;
                        });
                      },
                    )
                  else
                    Switch(
                      value: isCompleted,
                      onChanged: (value) {
                        setState(() {
                          isCompleted = value;
                        });
                      },
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Atanacak Kullanıcılar',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isIOS ? CupertinoColors.label : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: availableUsers.map((user) {
                  final isSelected = selectedUsers.contains(user.userID);
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          selectedUsers.remove(user.userID);
                        } else {
                          selectedUsers.add(user.userID);
                        }
                      });
                    },
                    child: Chip(
                      label: Text(user.userName),
                      backgroundColor: isSelected
                          ? (isIOS ? CupertinoColors.activeBlue : Colors.blue).withOpacity(0.2)
                          : isIOS ? CupertinoColors.systemGrey6 : Colors.grey[200],
                      labelStyle: TextStyle(
                        color: isSelected
                            ? (isIOS ? CupertinoColors.activeBlue : Colors.blue)
                            : isIOS ? CupertinoColors.label : Colors.black87,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
    
    if (isIOS) {
      showCupertinoDialog(
        context: context,
        builder: (BuildContext context) {
          return CupertinoAlertDialog(
            content: Material(
              color: Colors.transparent,
              child: dialogContent,
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('İptal'),
              ),
              CupertinoDialogAction(
                onPressed: () {
                  _updateWork(
                    nameController.text,
                    descController.text,
                    formatDate(startDate),
                    formatDate(endDate),
                    isCompleted,
                    selectedUsers,
                  );
                  Navigator.of(context).pop();
                },
                isDefaultAction: true,
                child: const Text('Güncelle'),
              ),
            ],
          );
        },
      );
    } else {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            content: dialogContent,
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('İptal'),
              ),
              TextButton(
                onPressed: () {
                  _updateWork(
                    nameController.text,
                    descController.text,
                    formatDate(startDate),
                    formatDate(endDate),
                    isCompleted,
                    selectedUsers,
                  );
                  Navigator.of(context).pop();
                },
                child: const Text('Güncelle'),
              ),
            ],
          );
        },
      );
    }
  }
  
  // Görevi güncelleme
  void _updateWork(
    String name,
    String description,
    String startDate,
    String endDate,
    bool isCompleted,
    List<int> users,
  ) async {
    if (name.isEmpty) {
      _showErrorSnackbar('Görev adı boş olamaz');
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final success = await Provider.of<GroupViewModel>(context, listen: false)
          .updateProjectWork(
            widget.projectId,
            widget.workId,
            name,
            description,
            startDate,
            endDate,
            isCompleted,
            users,
          );
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        if (success) {
          // Görevi yeniden yükle
          await _loadWorkDetail();
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Görev başarıyla güncellendi')),
          );
        } else {
          _showErrorSnackbar('Görev güncellenemedi');
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