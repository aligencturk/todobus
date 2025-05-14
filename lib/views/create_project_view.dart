import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:provider/provider.dart';
import '../services/logger_service.dart';
import '../viewmodels/group_viewmodel.dart';
import '../models/group_models.dart';

class CreateProjectView extends StatefulWidget {
  final int groupId;
  final List<GroupUser>? groupUsers;
  
  const CreateProjectView({
    Key? key, 
    required this.groupId,
    this.groupUsers,
  }) : super(key: key);
  
  @override
  _CreateProjectViewState createState() => _CreateProjectViewState();
}

class _CreateProjectViewState extends State<CreateProjectView> {
  final LoggerService _logger = LoggerService();
  final _projectNameController = TextEditingController();
  final _projectDescController = TextEditingController();
  
  List<GroupUser> _availableUsers = [];
  List<Map<String, dynamic>> _selectedUsers = [];
  bool _isLoading = false;
  String _errorMessage = '';
  
  // Proje durumları
  int _selectedStatus = 1;
  List<ProjectStatus> _projectStatuses = [];
  bool _isLoadingStatuses = true;
  
  // Tarih seçimi
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 7));
  
  @override
  void initState() {
    super.initState();
    _loadUsers();
    
    // UI oluşturma işlemi tamamlandıktan sonra API çağrısı yap
    Future.microtask(() {
      _loadProjectStatuses();
    });
  }
  
  @override
  void dispose() {
    _projectNameController.dispose();
    _projectDescController.dispose();
    super.dispose();
  }
  
  // Proje durumlarını yükle
  Future<void> _loadProjectStatuses() async {
    try {
      setState(() {
        _isLoadingStatuses = true;
      });
      
      final statuses = await Provider.of<GroupViewModel>(context, listen: false).getProjectStatuses();
      
      setState(() {
        _projectStatuses = statuses;
        if (statuses.isNotEmpty) {
          _selectedStatus = statuses[0].statusID; // Varsayılan olarak ilk durumu seç
        }
        _isLoadingStatuses = false;
      });
    } catch (e) {
      _logger.e('Proje durumları yüklenirken hata: $e');
      setState(() {
        _isLoadingStatuses = false;
      });
    }
  }
  
  // Kullanıcıları yükle
  void _loadUsers() {
    if (widget.groupUsers != null && widget.groupUsers!.isNotEmpty) {
      setState(() {
        _availableUsers = widget.groupUsers!;
        
        // Varsayılan olarak giriş yapan kullanıcıyı ekle
        for (var user in _availableUsers) {
          if (user.isAdmin) {
            _selectedUsers.add({
              'userID': user.userID,
              'userRole': 1, // Yönetici
            });
            break;
          }
        }
      });
    }
  }
  
  // Proje oluştur
  Future<void> _createProject() async {
    final projectName = _projectNameController.text.trim();
    final projectDesc = _projectDescController.text.trim();
    
    if (projectName.isEmpty) {
      setState(() {
        _errorMessage = 'Proje adı boş olamaz';
      });
      return;
    }
    
    if (_selectedUsers.isEmpty) {
      setState(() {
        _errorMessage = 'En az bir kullanıcı seçilmelidir';
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      final success = await Provider.of<GroupViewModel>(context, listen: false).createProject(
        widget.groupId,
        projectName,
        projectDesc,
        _formatDate(_startDate),
        _formatDate(_endDate),
        _selectedUsers,
        _selectedStatus,
      );
      
      if (success && mounted) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _errorMessage = 'Proje oluşturulamadı';
          _isLoading = false;
        });
      }
    } catch (e) {
      _logger.e('Proje oluşturulurken hata: $e');
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }
  
  // Tarihi formatla: "20.04.2025"
  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
  
  @override
  Widget build(BuildContext context) {
    final isIOS = isCupertino(context);
    
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: const Text('Yeni Proje Oluştur'),
        material: (_, __) => MaterialAppBarData(
          elevation: 2,
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? Center(child: PlatformCircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_errorMessage.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(8.0),
                        margin: const EdgeInsets.only(bottom: 16.0),
                        decoration: BoxDecoration(
                          color: isIOS
                              ? CupertinoColors.systemRed.withOpacity(0.1)
                              : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: Text(
                          _errorMessage,
                          style: TextStyle(
                            color: isIOS
                                ? CupertinoColors.systemRed
                                : Colors.red,
                          ),
                        ),
                      ),
                    _buildFormField(
                      context,
                      label: 'Proje Adı *',
                      controller: _projectNameController,
                      hintText: 'Proje adını girin',
                    ),
                    const SizedBox(height: 16),
                    _buildFormField(
                      context,
                      label: 'Proje Açıklaması',
                      controller: _projectDescController,
                      hintText: 'Proje açıklamasını girin',
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    _buildStatusSelector(context),
                    const SizedBox(height: 16),
                    _buildDateSelectors(context),
                    const SizedBox(height: 24),
                    _buildUserList(context),
                    const SizedBox(height: 24),
                    PlatformElevatedButton(
                      onPressed: _createProject,
                      child: const Text('Proje Oluştur'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
  
  Widget _buildFormField(
    BuildContext context, {
    required String label,
    required TextEditingController controller,
    required String hintText,
    int maxLines = 1,
  }) {
    final isIOS = isCupertino(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isIOS ? CupertinoColors.secondaryLabel : Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        isIOS
            ? CupertinoTextField(
                controller: controller,
                placeholder: hintText,
                padding: const EdgeInsets.all(12),
                style: const TextStyle(fontSize: 16),
                minLines: maxLines,
                maxLines: maxLines,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: CupertinoColors.systemGrey4,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
              )
            : TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: hintText,
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                style: const TextStyle(fontSize: 16),
                minLines: maxLines,
                maxLines: maxLines,
              ),
      ],
    );
  }
  
  Widget _buildStatusSelector(BuildContext context) {
    final isIOS = isCupertino(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Proje Durumu',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isIOS ? CupertinoColors.secondaryLabel : Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        if (_isLoadingStatuses)
          Center(
            child: PlatformCircularProgressIndicator(),
          )
        else if (_projectStatuses.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(
                color: isIOS ? CupertinoColors.systemGrey4 : Colors.grey.shade300,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('Proje durumları yüklenemedi'),
          )
        else
          DropdownButtonFormField<int>(
            value: _selectedStatus,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                borderSide: BorderSide(
                  color: isIOS ? CupertinoColors.systemGrey4 : Colors.grey.shade400,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                borderSide: BorderSide(
                  color: isIOS ? CupertinoColors.systemGrey4 : Colors.grey.shade400,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                borderSide: BorderSide(
                  color: isIOS ? CupertinoTheme.of(context).primaryColor : Theme.of(context).primaryColor,
                  width: 1.5,
                ),
              ),
            ),
            isExpanded: true,
            icon: Icon(isIOS ? CupertinoIcons.chevron_down : Icons.arrow_drop_down, size: 20),
            items: _projectStatuses.map((status) {
              final color = _hexToColor(status.statusColor);
              return DropdownMenuItem<int>(
                value: status.statusID,
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.black.withOpacity(0.2),
                          width: 0.5,
                        )
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      status.statusName,
                      style: TextStyle(
                        fontSize: 15,
                        color: CupertinoTheme.of(context).textTheme.textStyle.color,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedStatus = value;
                });
              }
            },
            dropdownColor: isIOS ? CupertinoTheme.of(context).scaffoldBackgroundColor : null,
            style: TextStyle(
              fontSize: 15,
              color: isIOS ? CupertinoTheme.of(context).textTheme.textStyle.color : null,
            ),
          ),
      ],
    );
  }
  
  // HEX renk kodunu Color nesnesine dönüştür
  Color _hexToColor(String hexColor) {
    hexColor = hexColor.replaceAll('#', '');
    if (hexColor.length == 6) {
      hexColor = 'FF$hexColor';
    }
    return Color(int.parse(hexColor, radix: 16));
  }
  
  Widget _buildDateSelectors(BuildContext context) {
    final isIOS = isCupertino(context);
    
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Başlangıç Tarihi',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isIOS ? CupertinoColors.secondaryLabel : Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => _selectDate(context, true),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isIOS
                          ? CupertinoColors.systemGrey4
                          : Colors.grey.shade300,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDate(_startDate),
                        style: const TextStyle(fontSize: 16),
                      ),
                      Icon(
                        isIOS ? CupertinoIcons.calendar : Icons.calendar_today,
                        size: 18,
                        color: isIOS
                            ? CupertinoColors.secondaryLabel
                            : Colors.grey[700],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bitiş Tarihi',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isIOS ? CupertinoColors.secondaryLabel : Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => _selectDate(context, false),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isIOS
                          ? CupertinoColors.systemGrey4
                          : Colors.grey.shade300,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDate(_endDate),
                        style: const TextStyle(fontSize: 16),
                      ),
                      Icon(
                        isIOS ? CupertinoIcons.calendar : Icons.calendar_today,
                        size: 18,
                        color: isIOS
                            ? CupertinoColors.secondaryLabel
                            : Colors.grey[700],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final isIOS = isCupertino(context);
    final currentDate = isStartDate ? _startDate : _endDate;
    final minDate = isStartDate ? DateTime.now() : _startDate;
    
    if (isIOS) {
      _showCupertinoDatePicker(context, isStartDate, currentDate, minDate);
    } else {
      _showMaterialDatePicker(context, isStartDate, currentDate, minDate);
    }
  }
  
  void _showCupertinoDatePicker(
    BuildContext context,
    bool isStartDate,
    DateTime currentDate,
    DateTime minDate,
  ) {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => Container(
        height: 250,
        color: CupertinoColors.systemBackground,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  child: const Text('İptal'),
                  onPressed: () => Navigator.pop(context),
                ),
                CupertinoButton(
                  child: const Text('Tamam'),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
            Expanded(
              child: CupertinoDatePicker(
                initialDateTime: currentDate,
                minimumDate: minDate,
                mode: CupertinoDatePickerMode.date,
                use24hFormat: true,
                onDateTimeChanged: (date) {
                  setState(() {
                    if (isStartDate) {
                      _startDate = date;
                      // Bitiş tarihi başlangıç tarihinden önce olamaz
                      if (_endDate.isBefore(_startDate)) {
                        _endDate = _startDate.add(const Duration(days: 1));
                      }
                    } else {
                      _endDate = date;
                    }
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _showMaterialDatePicker(
    BuildContext context,
    bool isStartDate,
    DateTime currentDate,
    DateTime minDate,
  ) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: minDate,
      lastDate: DateTime(DateTime.now().year + 5),
    );
    
    if (pickedDate != null && mounted) {
      setState(() {
        if (isStartDate) {
          _startDate = pickedDate;
          // Bitiş tarihi başlangıç tarihinden önce olamaz
          if (_endDate.isBefore(_startDate)) {
            _endDate = _startDate.add(const Duration(days: 1));
          }
        } else {
          _endDate = pickedDate;
        }
      });
    }
  }
  
  Widget _buildUserList(BuildContext context) {
    final isIOS = isCupertino(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Proje Üyeleri',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isIOS ? CupertinoColors.label : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Projede çalışacak üyeleri seçin. (*) işaretli olan kişi yönetici olarak atanacaktır.',
          style: TextStyle(
            fontSize: 14,
            color: isIOS ? CupertinoColors.secondaryLabel : Colors.grey[600],
          ),
        ),
        const SizedBox(height: 16),
        if (_availableUsers.isEmpty)
          Center(
            child: Text(
              'Kullanıcı listesi yüklenemiyor',
              style: TextStyle(
                fontSize: 14,
                color: isIOS ? CupertinoColors.secondaryLabel : Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _availableUsers.length,
            itemBuilder: (context, index) {
              final user = _availableUsers[index];
              
              // Kullanıcının seçilip seçilmediğini kontrol et
              final isSelected = _selectedUsers.any((u) => u['userID'] == user.userID);
              
              // Kullanıcının rolünü al
              int userRole = 2; // Varsayılan: Üye
              if (isSelected) {
                final selectedUser = _selectedUsers.firstWhere((u) => u['userID'] == user.userID);
                userRole = selectedUser['userRole'];
              }
              
              // Seçim yapıldığında çağrılacak
              void onSelectionChanged(bool isSelected) {
                setState(() {
                  if (isSelected) {
                    _selectedUsers.add({
                      'userID': user.userID,
                      'userRole': 2, // Varsayılan: Üye
                    });
                  } else {
                    _selectedUsers.removeWhere(
                      (selectedUser) => selectedUser['userID'] == user.userID,
                    );
                  }
                });
              }
              
              // Rol değiştiğinde çağrılacak
              void onRoleChanged(int role) {
                setState(() {
                  final userIndex = _selectedUsers.indexWhere(
                    (selectedUser) => selectedUser['userID'] == user.userID,
                  );
                  
                  if (userIndex != -1) {
                    _selectedUsers[userIndex]['userRole'] = role;
                  }
                });
              }
              
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: (isSelected && userRole == 1)
                      ? (isIOS ? CupertinoColors.activeBlue : Colors.blue).withOpacity(0.2)
                      : (isIOS ? CupertinoColors.systemGrey : Colors.grey).withOpacity(0.2),
                  child: Text(
                    user.userName.substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      color: (isSelected && userRole == 1)
                          ? (isIOS ? CupertinoColors.activeBlue : Colors.blue)
                          : (isIOS ? CupertinoColors.systemGrey : Colors.grey),
                    ),
                  ),
                ),
                title: Text(user.userName),
                subtitle: Text(user.isAdmin ? 'Grup Yöneticisi' : 'Grup Üyesi'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSelected)
                      PlatformIconButton(
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          userRole == 1
                              ? (isIOS ? CupertinoIcons.star_fill : Icons.star)
                              : (isIOS ? CupertinoIcons.star : Icons.star_border),
                          color: userRole == 1
                              ? (isIOS ? CupertinoColors.activeOrange : Colors.orange)
                              : (isIOS ? CupertinoColors.systemGrey : Colors.grey),
                          size: 20,
                        ),
                        onPressed: () => onRoleChanged(userRole == 1 ? 2 : 1),
                      ),
                    const SizedBox(width: 8),
                    isIOS
                        ? CupertinoSwitch(
                            value: isSelected,
                            onChanged: onSelectionChanged,
                          )
                        : Switch(
                            value: isSelected,
                            onChanged: onSelectionChanged,
                          ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
} 