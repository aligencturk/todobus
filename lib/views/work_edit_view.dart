import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:provider/provider.dart';
import '../models/group_models.dart';
import '../services/logger_service.dart';
import '../viewmodels/group_viewmodel.dart';
import '../services/snackbar_service.dart';

class WorkEditView extends StatefulWidget {
  final int projectId;
  final int groupId;
  final int workId;
  
  const WorkEditView({
    Key? key,
    required this.projectId,
    required this.groupId,
    required this.workId,
  }) : super(key: key);
  
  @override
  State<WorkEditView> createState() => _WorkEditViewState();
}

class _WorkEditViewState extends State<WorkEditView> {
  final LoggerService _logger = LoggerService();
  final SnackBarService _snackBarService = SnackBarService();
  
  bool _isLoading = true;
  String _errorMessage = '';
  ProjectWork? _workDetail;
  List<ProjectUser> _availableUsers = [];
  
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 7));
  bool _isCompleted = false;
  List<int> _selectedUsers = [];
  
  @override
  void initState() {
    super.initState();
    _loadWorkDetail();
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }
  
  // Tarih ayrıştırma: "DD.MM.YYYY" formatından DateTime'a çevirme
  DateTime _parseDate(String dateStr) {
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
  
  // Tarih formatlama fonksiyonu
  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
  
  Future<void> _loadWorkDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      // Görev detaylarını yükle
      final workDetail = await Provider.of<GroupViewModel>(context, listen: false)
          .getWorkDetail(widget.projectId, widget.workId);
      
      // Proje detaylarını yükle (kullanıcıların listesi için)
      final project = await Provider.of<GroupViewModel>(context, listen: false)
          .getProjectDetail(widget.projectId, widget.groupId);
          
      if (mounted) {
        setState(() {
          _workDetail = workDetail;
          _availableUsers = project?.users ?? [];
          
          // Form elemanlarını doldur
          _nameController.text = workDetail?.workName ?? '';
          _descController.text = workDetail?.workDesc ?? '';
          _startDate = _parseDate(workDetail?.workStartDate ?? _formatDate(DateTime.now()));
          _endDate = _parseDate(workDetail?.workEndDate ?? _formatDate(DateTime.now().add(const Duration(days: 7))));
          _isCompleted = workDetail?.workCompleted ?? false;
          _selectedUsers = workDetail?.workUsers.map((user) => user.userID).toList() ?? [];
          
          _isLoading = false;
        });
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
  
  Future<DateTime?> _pickDate(BuildContext context, DateTime initialDate) async {
    final isIOS = isCupertino(context);
    
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
  
  void _saveChanges() async {
    if (_nameController.text.isEmpty) {
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
            _nameController.text,
            _descController.text,
            _formatDate(_startDate),
            _formatDate(_endDate),
            _isCompleted,
            _selectedUsers,
          );
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        if (success) {
          Navigator.of(context).pop(true); // Başarılı olduğunu belirterek geri dön
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
  
  // Hata mesajı göster
  void _showErrorSnackbar(String errorMessage) {
    if (!mounted) return;
    
    try {
      _snackBarService.showError(_snackBarService.formatErrorMessage(errorMessage));
    } catch (e) {
      _logger.e('SnackBar gösterilirken hata: $e');
    }
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
  
  @override
  Widget build(BuildContext context) {
    final isIOS = isCupertino(context);
    
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: Text(_workDetail?.workName ?? 'Görevi Düzenle'),
        trailingActions: [
          PlatformIconButton(
            icon: Icon(
              isIOS ? CupertinoIcons.checkmark : Icons.check,
            ),
            onPressed: _saveChanges,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? Center(child: PlatformCircularProgressIndicator())
            : _errorMessage.isNotEmpty
                ? _buildErrorView(context)
                : _buildEditForm(context),
      ),
    );
  }
  
  Widget _buildEditForm(BuildContext context) {
    final isIOS = isCupertino(context);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Görev adı
          Text(
            'Görev Adı',
            style: TextStyle(
              fontSize: 14,
              color: isIOS ? CupertinoColors.secondaryLabel : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          if (isIOS)
            CupertinoTextField(
              controller: _nameController,
              placeholder: 'Görev Adı',
              padding: const EdgeInsets.all(12),
            )
          else
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Görev Adı',
                border: OutlineInputBorder(),
              ),
            ),
            
          const SizedBox(height: 24),
          
          // Görev açıklaması
          Text(
            'Görev Açıklaması',
            style: TextStyle(
              fontSize: 14,
              color: isIOS ? CupertinoColors.secondaryLabel : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          if (isIOS)
            CupertinoTextField(
              controller: _descController,
              placeholder: 'Görev Açıklaması',
              padding: const EdgeInsets.all(12),
              maxLines: 4,
            )
          else
            TextField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: 'Görev Açıklaması',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 4,
            ),
            
          const SizedBox(height: 24),
          
          // Tarihler
          Text(
            'Tarihler',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isIOS ? CupertinoColors.label : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          
          // Başlangıç ve bitiş tarihleri
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    final pickedDate = await _pickDate(context, _startDate);
                    if (pickedDate != null) {
                      setState(() {
                        _startDate = pickedDate;
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDate(_startDate),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isIOS ? CupertinoColors.label : Colors.black87,
                              ),
                            ),
                            Icon(
                              isIOS ? CupertinoIcons.calendar : Icons.calendar_today,
                              size: 16,
                              color: isIOS ? CupertinoColors.activeBlue : Colors.blue,
                            ),
                          ],
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
                    final pickedDate = await _pickDate(context, _endDate);
                    if (pickedDate != null) {
                      setState(() {
                        _endDate = pickedDate;
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDate(_endDate),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isIOS ? CupertinoColors.label : Colors.black87,
                              ),
                            ),
                            Icon(
                              isIOS ? CupertinoIcons.calendar : Icons.calendar_today,
                              size: 16,
                              color: isIOS ? CupertinoColors.activeBlue : Colors.blue,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Görev durumu
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Görev Durumu',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isIOS ? CupertinoColors.label : Colors.black87,
                ),
              ),
              Row(
                children: [
                  Text(
                    _isCompleted ? 'Tamamlandı' : 'Devam Ediyor',
                    style: TextStyle(
                      color: _isCompleted
                          ? (isIOS ? CupertinoColors.systemGreen : Colors.green)
                          : (isIOS ? CupertinoColors.systemOrange : Colors.orange),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (isIOS)
                    CupertinoSwitch(
                      value: _isCompleted,
                      onChanged: (value) {
                        setState(() {
                          _isCompleted = value;
                        });
                      },
                    )
                  else
                    Switch(
                      value: _isCompleted,
                      onChanged: (value) {
                        setState(() {
                          _isCompleted = value;
                        });
                      },
                    ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Atanacak kullanıcılar
          Text(
            'Atanacak Kullanıcılar',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isIOS ? CupertinoColors.label : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          if (_availableUsers.isEmpty)
            Center(
              child: Text(
                'Kullanıcı bulunamadı',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: isIOS ? CupertinoColors.systemGrey : Colors.grey,
                ),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _availableUsers.map((user) {
                final isSelected = _selectedUsers.contains(user.userID);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedUsers.remove(user.userID);
                      } else {
                        _selectedUsers.add(user.userID);
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
                    avatar: isSelected
                        ? Icon(
                            isIOS ? CupertinoIcons.checkmark_circle_fill : Icons.check_circle,
                            size: 16,
                            color: isIOS ? CupertinoColors.activeBlue : Colors.blue,
                          )
                        : null,
                  ),
                );
              }).toList(),
            ),
            
          const SizedBox(height: 32),
          
          // Kaydet butonu
          SizedBox(
            width: double.infinity,
            child: PlatformElevatedButton(
              onPressed: _saveChanges,
              material: (_, __) => MaterialElevatedButtonData(
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              cupertino: (_, __) => CupertinoElevatedButtonData(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Değişiklikleri Kaydet'),
            ),
          ),
          
          const SizedBox(height: 16),
        ],
      ),
    );
  }
} 