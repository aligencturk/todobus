import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:provider/provider.dart';
import '../models/group_models.dart';
import '../services/logger_service.dart';
import '../services/snackbar_service.dart';
import '../viewmodels/group_viewmodel.dart';

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
  
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 7));
  List<int> _selectedUsers = [];
  bool _isLoading = false;
  List<ProjectUser>? _projectUsers;
  
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
        _snackBarService.showError('Proje kullanıcıları yüklenemedi');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _snackBarService.showError('Kullanıcılar yüklenemedi: $e');
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
      _snackBarService.showError('Görev adı boş olamaz');
      return;
    }
    
    if (_selectedUsers.isEmpty) {
      _snackBarService.showError('En az bir kullanıcı seçmelisiniz');
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
          _snackBarService.showSuccess('Görev başarıyla eklendi');
          Navigator.of(context).pop(true); // Başarılı olduğunu bildir
        } else {
          _snackBarService.showError('Görev eklenemedi');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        _snackBarService.showError('Görev eklenirken hata: $e');
        _logger.e('Görev eklenirken hata: $e');
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final isIOS = isCupertino(context);
    
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: const Text('Yeni Görev'),
        material: (_, __) => MaterialAppBarData(
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _isLoading ? null : _addWork,
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
                  onPressed: _addWork,
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
            ],
          ),
        ),
      ),
    );
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
} 