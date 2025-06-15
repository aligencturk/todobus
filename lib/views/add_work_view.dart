import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:provider/provider.dart';
import '../models/group_models.dart';
import '../services/logger_service.dart';
import '../services/snackbar_service.dart';
import '../viewmodels/group_viewmodel.dart';

class BulkTask {
  String name;
  String description;
  List<int> assignedUsers;
  
  BulkTask({
    required this.name,
    this.description = '',
    required this.assignedUsers,
  });
}

class AddWorkView extends StatefulWidget {
  final int projectId;
  final int groupId;
  final List<ProjectUser>? projectUsers;
  
  const AddWorkView({
    Key? key,
    required this.projectId,
    required this.groupId,
    this.projectUsers,
  }) : super(key: key);
  
  @override
  _AddWorkViewState createState() => _AddWorkViewState();
}

class _AddWorkViewState extends State<AddWorkView> {
  final LoggerService _logger = LoggerService();
  final SnackBarService _snackBarService = SnackBarService();
  
  // Tekli görev için
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  
  // Toplu görev için
  final TextEditingController _bulkTaskController = TextEditingController();
  List<BulkTask> _bulkTasks = [];
  List<int> _commonAssignedUsers = [];
  
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 7));
  List<int> _selectedUsers = [];
  bool _isLoading = false;
  List<ProjectUser>? _projectUsers;
  bool _isBulkMode = false; // Yeni: toplu/tekli mod toggle
  
  @override
  void initState() {
    super.initState();
    _projectUsers = widget.projectUsers;
    if (_projectUsers == null) {
      _loadProjectUsers();
    }
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _bulkTaskController.dispose();
    super.dispose();
  }
  
  Future<void> _loadProjectUsers() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      final projectDetail = await Provider.of<GroupViewModel>(context, listen: false)
          .getProjectDetail(widget.projectId, widget.groupId);
      
      if (projectDetail != null) {
        setState(() {
          _projectUsers = projectDetail.users;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Proje kullanıcıları yüklenemedi'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kullanıcılar yüklenemedi: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      _logger.e('Proje kullanıcıları yüklenirken hata: $e');
    }
  }
  
  // Tarih formatlama fonksiyonu
  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
  
  void _addWork() async {
    final name = _nameController.text.trim();
    final description = _descController.text.trim();
    
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Görev adı boş olamaz'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    
    if (_selectedUsers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('En az bir kullanıcı seçmelisiniz'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final success = await Provider.of<GroupViewModel>(context, listen: false)
          .addProjectWork(
            widget.projectId,
            name,
            description,
            _formatDate(_startDate),
            _formatDate(_endDate),
            _selectedUsers,
          );
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        if (success) {
          // Başarılı olduğunda direkt pop ve parent'ta mesaj göster
          Navigator.of(context).pop({
            'success': true,
            'message': 'Görev başarıyla eklendi',
            'isBulk': false,
            'count': 1,
          });
        } else {
          Navigator.of(context).pop({
            'success': false,
            'message': 'Görev eklenemedi',
            'isBulk': false,
            'count': 0,
            'type': 'error',
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        _logger.e('Görev eklenirken hata: $e');
        Navigator.of(context).pop({
          'success': false,
          'message': 'Görev eklenirken hata: $e',
          'isBulk': false,
          'count': 0,
          'type': 'error',
        });
      }
    }
  }
  
  void _addBulkTask() {
    final taskName = _bulkTaskController.text.trim();
    if (taskName.isNotEmpty) {
      setState(() {
        _bulkTasks.add(BulkTask(
          name: taskName,
          assignedUsers: List.from(_commonAssignedUsers),
        ));
        _bulkTaskController.clear();
      });
    }
  }
  
  void _removeBulkTask(int index) {
    setState(() {
      _bulkTasks.removeAt(index);
    });
  }
  
  void _clearAllBulkTasks() {
    setState(() {
      _bulkTasks.clear();
      _commonAssignedUsers.clear();
    });
  }
  
  void _addBulkWorks() async {
    if (_bulkTasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('En az bir görev eklemelisiniz'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    
    // Atanmamış görev kontrolü
    final unassignedTasks = _bulkTasks.where((task) => task.assignedUsers.isEmpty).toList();
    if (unassignedTasks.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Tüm görevlerin atanmış kullanıcıları olmalı'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      int successCount = 0;
      int failCount = 0;
      
      for (final task in _bulkTasks) {
        final success = await Provider.of<GroupViewModel>(context, listen: false)
            .addProjectWork(
              widget.projectId,
              task.name,
              task.description,
              _formatDate(_startDate),
              _formatDate(_endDate),
              task.assignedUsers,
            );
        
        if (success) {
          successCount++;
        } else {
          failCount++;
        }
      }
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        if (failCount == 0) {
          // Başarılı olduğunda direkt pop ve parent'ta mesaj göster
          Navigator.of(context).pop({
            'success': true,
            'message': 'Tüm görevler başarıyla eklendi ($successCount görev)',
            'isBulk': true,
            'count': successCount,
          });
        } else if (successCount > 0) {
          Navigator.of(context).pop({
            'success': false,
            'message': '$successCount görev eklendi, $failCount görev eklenemedi',
            'isBulk': true,
            'count': successCount,
            'type': 'info',
          });
        } else {
          Navigator.of(context).pop({
            'success': false,
            'message': 'Hiçbir görev eklenemedi',
            'isBulk': true,
            'count': 0,
            'type': 'error',
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        _logger.e('Toplu görev eklenirken hata: $e');
        Navigator.of(context).pop({
          'success': false,
          'message': 'Görevler eklenirken hata: $e',
          'isBulk': true,
          'count': 0,
          'type': 'error',
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final isIOS = isCupertino(context);
    
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: Text(_isBulkMode ? 'Toplu Görev Ekle' : 'Yeni Görev'),
        material: (_, __) => MaterialAppBarData(
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _isLoading ? null : (_isBulkMode ? _addBulkWorks : _addWork),
            ),
          ],
        ),
        cupertino: (_, __) => CupertinoNavigationBarData(
          brightness: Brightness.light,
          backgroundColor: CupertinoColors.systemGroupedBackground,
          border: const Border(),
          trailing: _isLoading
              ? const CupertinoActivityIndicator()
              : CupertinoButton(
                  padding: EdgeInsets.zero,
                  child: const Text('Kaydet'),
                  onPressed: _isBulkMode ? _addBulkWorks : _addWork,
                ),
        ),
      ),
      body: _isLoading && _projectUsers == null
          ? const Center(child: CupertinoActivityIndicator())
          : _buildBody(context),
    );
  }
  
  Widget _buildBody(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: CupertinoScrollbar(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildModeToggle(),
              const SizedBox(height: 20),
              if (_isBulkMode) ..._buildBulkMode() else ..._buildSingleMode(),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildModeToggle() {
    final isIOS = isCupertino(context);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isIOS ? CupertinoColors.white : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        boxShadow: isIOS ? [
          BoxShadow(
            color: CupertinoColors.systemGrey5.withOpacity(0.5),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ] : null,
      ),
      child: Row(
        children: [
          Icon(
            _isBulkMode 
                ? (isIOS ? CupertinoIcons.list_bullet : Icons.list)
                : (isIOS ? CupertinoIcons.doc : Icons.description),
            color: isIOS ? CupertinoColors.activeBlue : Colors.blue,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isBulkMode ? 'Toplu Görev Ekleme' : 'Tekli Görev Ekleme',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isIOS ? CupertinoColors.label : Colors.black87,
                  ),
                ),
                Text(
                  _isBulkMode 
                      ? 'Birden fazla görev aynı anda ekleyin'
                      : 'Tek görev detaylı olarak ekleyin',
                  style: TextStyle(
                    fontSize: 13,
                    color: isIOS ? CupertinoColors.secondaryLabel : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          if (isIOS)
            CupertinoSwitch(
              value: _isBulkMode,
              onChanged: (value) {
                setState(() {
                  _isBulkMode = value;
                  if (_isBulkMode) {
                    // Tekli moddan toplu moda geçerken ortak kullanıcıları kopyala
                    _commonAssignedUsers = List.from(_selectedUsers);
                  }
                });
              },
            )
          else
            Switch(
              value: _isBulkMode,
              onChanged: (value) {
                setState(() {
                  _isBulkMode = value;
                  if (_isBulkMode) {
                    _commonAssignedUsers = List.from(_selectedUsers);
                  }
                });
              },
            ),
        ],
      ),
    );
  }
  
  List<Widget> _buildSingleMode() {
    return [
      _buildNameField(),
      const SizedBox(height: 16),
      _buildDescriptionField(),
      const SizedBox(height: 20),
      _buildDateSection(),
      const SizedBox(height: 20),
      _buildAssigneeSection(),
      const SizedBox(height: 30),
      _buildSubmitButton(),
      const SizedBox(height: 30),
    ];
  }
  
  List<Widget> _buildBulkMode() {
    return [
      _buildBulkTaskInput(),
      const SizedBox(height: 16),
      _buildCommonAssigneeSection(),
      const SizedBox(height: 20),
      _buildDateSection(),
      const SizedBox(height: 20),
      _buildBulkTasksList(),
      const SizedBox(height: 20),
      _buildBulkActions(),
      const SizedBox(height: 30),
    ];
  }
  
  Widget _buildNameField() {
    final isIOS = isCupertino(context);
    
    return Container(
      decoration: isIOS
          ? BoxDecoration(
              color: CupertinoColors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: CupertinoColors.systemGrey5.withOpacity(0.5),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            )
          : null,
      padding: isIOS ? const EdgeInsets.all(12) : EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isIOS)
            Text(
              'Görev Adı',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
          const SizedBox(height: 8),
          if (isIOS)
            CupertinoTextField(
              controller: _nameController,
              placeholder: 'Görev adını girin',
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey6,
                borderRadius: BorderRadius.circular(8),
              ),
              style: const TextStyle(
                fontSize: 16,
              ),
            )
          else
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Görev Adı',
                hintText: 'Görev adını girin',
                border: OutlineInputBorder(),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildDescriptionField() {
    final isIOS = isCupertino(context);
    
    return Container(
      decoration: isIOS
          ? BoxDecoration(
              color: CupertinoColors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: CupertinoColors.systemGrey5.withOpacity(0.5),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            )
          : null,
      padding: isIOS ? const EdgeInsets.all(12) : EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isIOS)
            Text(
              'Açıklama',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
          const SizedBox(height: 8),
          if (isIOS)
            CupertinoTextField(
              controller: _descController,
              placeholder: 'Görev açıklamasını girin (opsiyonel)',
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey6,
                borderRadius: BorderRadius.circular(8),
              ),
              style: const TextStyle(
                fontSize: 16,
              ),
              maxLines: 4,
              minLines: 3,
            )
          else
            TextField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: 'Açıklama',
                hintText: 'Görev açıklamasını girin (opsiyonel)',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
              minLines: 3,
            ),
        ],
      ),
    );
  }
  
  Widget _buildDateSection() {
    final isIOS = isCupertino(context);
    
    return Container(
      decoration: isIOS
          ? BoxDecoration(
              color: CupertinoColors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: CupertinoColors.systemGrey5.withOpacity(0.5),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            )
          : null,
      padding: isIOS ? const EdgeInsets.all(12) : EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isIOS)
            Text(
              'Zaman Aralığı',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: _buildDateField(
                    label: 'Başlangıç',
                    value: _startDate,
                    onTap: () => _showDatePicker(isStartDate: true),
                  ),
                ),
                VerticalDivider(
                  width: 20,
                  thickness: 1,
                  color: isIOS ? CupertinoColors.systemGrey5 : Colors.grey[300],
                ),
                Expanded(
                  child: _buildDateField(
                    label: 'Bitiş',
                    value: _endDate,
                    onTap: () => _showDatePicker(isStartDate: false),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDateField({
    required String label, 
    required DateTime value, 
    required VoidCallback onTap
  }) {
    final isIOS = isCupertino(context);
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: isIOS ? Colors.transparent : Colors.grey[50],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isIOS ? CupertinoColors.secondaryLabel : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDate(value),
                  style: TextStyle(
                    fontSize: 16,
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
    );
  }
  
  void _showDatePicker({required bool isStartDate}) {
    final isIOS = isCupertino(context);
    
    if (isIOS) {
      showCupertinoModalPopup(
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CupertinoButton(
                        child: const Text('İptal'),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      CupertinoButton(
                        child: const Text('Tamam'),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  Expanded(
                    child: CupertinoDatePicker(
                      initialDateTime: isStartDate ? _startDate : _endDate,
                      mode: CupertinoDatePickerMode.date,
                      onDateTimeChanged: (DateTime newDate) {
                        setState(() {
                          if (isStartDate) {
                            _startDate = newDate;
                            // Bitiş tarihi başlangıçtan önce ise güncelle
                            if (_endDate.isBefore(_startDate)) {
                              _endDate = _startDate.add(const Duration(days: 1));
                            }
                          } else {
                            _endDate = newDate;
                          }
                        });
                      },
                      minimumDate: isStartDate ? null : _startDate,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } else {
      showDatePicker(
        context: context,
        initialDate: isStartDate ? _startDate : _endDate,
        firstDate: isStartDate ? DateTime(2000) : _startDate,
        lastDate: DateTime(2100),
      ).then((pickedDate) {
        if (pickedDate != null) {
          setState(() {
            if (isStartDate) {
              _startDate = pickedDate;
              // Bitiş tarihi başlangıçtan önce ise güncelle
              if (_endDate.isBefore(_startDate)) {
                _endDate = _startDate.add(const Duration(days: 1));
              }
            } else {
              _endDate = pickedDate;
            }
          });
        }
      });
    }
  }
  
  Widget _buildAssigneeSection() {
    final isIOS = isCupertino(context);
    final users = _projectUsers;
    
    if (users == null || users.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Container(
      decoration: isIOS
          ? BoxDecoration(
              color: CupertinoColors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: CupertinoColors.systemGrey5.withOpacity(0.5),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            )
          : null,
      padding: isIOS ? const EdgeInsets.all(12) : EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isIOS)
            Text(
              'Görev Atama',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
          const SizedBox(height: 8),
          Text(
            'Görevi atayacağınız kullanıcıları seçin',
            style: TextStyle(
              fontSize: 13,
              color: isIOS ? CupertinoColors.secondaryLabel : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: users.map((user) {
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
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isIOS ? CupertinoColors.activeBlue : Colors.blue).withOpacity(0.1)
                        : isIOS ? CupertinoColors.systemGrey6 : Colors.grey[200],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? (isIOS ? CupertinoColors.activeBlue : Colors.blue)
                          : isIOS ? CupertinoColors.systemGrey5 : Colors.grey[400]!,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSelected
                            ? (isIOS ? CupertinoIcons.checkmark_circle_fill : Icons.check_circle)
                            : (isIOS ? CupertinoIcons.circle : Icons.circle_outlined),
                        size: 16,
                        color: isSelected
                            ? (isIOS ? CupertinoColors.activeBlue : Colors.blue)
                            : isIOS ? CupertinoColors.systemGrey : Colors.grey[600],
                      ),
                      const SizedBox(width: 6),
                      Text(
                        user.userName,
                        style: TextStyle(
                          color: isSelected
                              ? (isIOS ? CupertinoColors.activeBlue : Colors.blue)
                              : isIOS ? CupertinoColors.label : Colors.black87,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSubmitButton() {
    final isIOS = isCupertino(context);
    
    return SizedBox(
      width: double.infinity,
      child: isIOS
          ? CupertinoButton.filled(
              onPressed: _isLoading ? null : _addWork,
              child: _isLoading
                  ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                  : const Text('Görevi Ekle'),
            )
          : ElevatedButton(
              onPressed: _isLoading ? null : _addWork,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Görevi Ekle'),
            ),
    );
  }
  
  Widget _buildBulkTaskInput() {
    final isIOS = isCupertino(context);
    
    return Container(
      decoration: isIOS
          ? BoxDecoration(
              color: CupertinoColors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: CupertinoColors.systemGrey5.withOpacity(0.5),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            )
          : null,
      padding: isIOS ? const EdgeInsets.all(12) : EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isIOS)
            Text(
              'Hızlı Görev Ekleme',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: isIOS
                    ? CupertinoTextField(
                        controller: _bulkTaskController,
                        placeholder: 'Görev adını yazın ve artı butonuna basın',
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemGrey6,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        style: const TextStyle(fontSize: 16),
                        onSubmitted: (_) => _addBulkTask(),
                      )
                    : TextField(
                        controller: _bulkTaskController,
                        decoration: const InputDecoration(
                          hintText: 'Görev adını yazın ve artı butonuna basın',
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _addBulkTask(),
                      ),
              ),
              const SizedBox(width: 8),
              if (isIOS)
                CupertinoButton(
                  padding: const EdgeInsets.all(8),
                  color: CupertinoColors.activeBlue,
                  borderRadius: BorderRadius.circular(8),
                  onPressed: _addBulkTask,
                  child: const Icon(
                    CupertinoIcons.add,
                    color: CupertinoColors.white,
                    size: 20,
                  ),
                )
              else
                ElevatedButton(
                  onPressed: _addBulkTask,
                  child: const Icon(Icons.add),
                ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildCommonAssigneeSection() {
    final isIOS = isCupertino(context);
    final users = _projectUsers;
    
    if (users == null || users.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Container(
      decoration: isIOS
          ? BoxDecoration(
              color: CupertinoColors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: CupertinoColors.systemGrey5.withOpacity(0.5),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            )
          : null,
      padding: isIOS ? const EdgeInsets.all(12) : EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isIOS)
                Text(
                  'Ortak Atama',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: CupertinoColors.secondaryLabel,
                  ),
                ),
              if (!isIOS)
                Text(
                  'Ortak Atama',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  setState(() {
                    if (_commonAssignedUsers.length == users.length) {
                      _commonAssignedUsers.clear();
                    } else {
                      _commonAssignedUsers = users.map((u) => u.userID).toList();
                    }
                    // Mevcut görevlere de uygula
                    for (var task in _bulkTasks) {
                      task.assignedUsers = List.from(_commonAssignedUsers);
                    }
                  });
                },
                child: Text(
                  _commonAssignedUsers.length == users.length ? 'Hiçbirini Seçme' : 'Hepsini Seç',
                  style: TextStyle(
                    fontSize: 12,
                    color: isIOS ? CupertinoColors.activeBlue : Colors.blue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Tüm görevlere otomatik atanacak kullanıcılar',
            style: TextStyle(
              fontSize: 13,
              color: isIOS ? CupertinoColors.secondaryLabel : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: users.map((user) {
              final isSelected = _commonAssignedUsers.contains(user.userID);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _commonAssignedUsers.remove(user.userID);
                    } else {
                      _commonAssignedUsers.add(user.userID);
                    }
                    // Mevcut görevlere de uygula
                    for (var task in _bulkTasks) {
                      if (isSelected) {
                        task.assignedUsers.remove(user.userID);
                      } else {
                        if (!task.assignedUsers.contains(user.userID)) {
                          task.assignedUsers.add(user.userID);
                        }
                      }
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isIOS ? CupertinoColors.activeBlue : Colors.blue).withOpacity(0.1)
                        : isIOS ? CupertinoColors.systemGrey6 : Colors.grey[200],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? (isIOS ? CupertinoColors.activeBlue : Colors.blue)
                          : isIOS ? CupertinoColors.systemGrey5 : Colors.grey[400]!,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    user.userName,
                    style: TextStyle(
                      color: isSelected
                          ? (isIOS ? CupertinoColors.activeBlue : Colors.blue)
                          : isIOS ? CupertinoColors.label : Colors.black87,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildBulkTasksList() {
    final isIOS = isCupertino(context);
    
    if (_bulkTasks.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isIOS ? CupertinoColors.systemGrey6 : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isIOS ? CupertinoColors.systemGrey5 : Colors.grey[300]!,
            style: BorderStyle.solid,
            width: 1,
          ),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(
                isIOS ? CupertinoIcons.list_bullet : Icons.list,
                size: 48,
                color: isIOS ? CupertinoColors.systemGrey3 : Colors.grey[400],
              ),
              const SizedBox(height: 8),
              Text(
                'Henüz görev eklenmedi',
                style: TextStyle(
                  color: isIOS ? CupertinoColors.systemGrey : Colors.grey[600],
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Yukarıdaki alandan görev ekleyin',
                style: TextStyle(
                  color: isIOS ? CupertinoColors.systemGrey2 : Colors.grey[500],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return Container(
      decoration: isIOS
          ? BoxDecoration(
              color: CupertinoColors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: CupertinoColors.systemGrey5.withOpacity(0.5),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Text(
                  'Eklenecek Görevler (${_bulkTasks.length})',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isIOS ? CupertinoColors.secondaryLabel : Colors.grey[600],
                  ),
                ),
                const Spacer(),
                if (_bulkTasks.isNotEmpty)
                  TextButton(
                    onPressed: _clearAllBulkTasks,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                    ),
                    child: Text(
                      'Tümünü Sil',
                      style: TextStyle(
                        fontSize: 12,
                        color: isIOS ? CupertinoColors.systemRed : Colors.red,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _bulkTasks.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              color: isIOS ? CupertinoColors.systemGrey5 : Colors.grey[300],
            ),
            itemBuilder: (context, index) {
              final task = _bulkTasks[index];
              final users = _projectUsers ?? [];
              final assignedUserNames = users
                  .where((user) => task.assignedUsers.contains(user.userID))
                  .map((user) => user.userName)
                  .toList();
              
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: (isIOS ? CupertinoColors.activeBlue : Colors.blue).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isIOS ? CupertinoColors.activeBlue : Colors.blue,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.name,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: isIOS ? CupertinoColors.label : Colors.black87,
                            ),
                          ),
                          if (assignedUserNames.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Atananlar: ${assignedUserNames.join(', ')}',
                              style: TextStyle(
                                fontSize: 13,
                                color: isIOS ? CupertinoColors.secondaryLabel : Colors.grey[600],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _removeBulkTask(index),
                      icon: Icon(
                        isIOS ? CupertinoIcons.trash : Icons.delete_outline,
                        color: isIOS ? CupertinoColors.systemRed : Colors.red,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildBulkActions() {
    final isIOS = isCupertino(context);
    
    return Row(
      children: [
        Expanded(
          child: isIOS
              ? CupertinoButton.filled(
                  onPressed: _isLoading || _bulkTasks.isEmpty ? null : _addBulkWorks,
                  child: _isLoading
                      ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                      : Text('${_bulkTasks.length} Görevi Ekle'),
                )
              : ElevatedButton(
                  onPressed: _isLoading || _bulkTasks.isEmpty ? null : _addBulkWorks,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text('${_bulkTasks.length} Görevi Ekle'),
                ),
        ),
      ],
    );
  }
} 