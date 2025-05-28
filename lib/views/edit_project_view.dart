import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:provider/provider.dart';
import '../models/group_models.dart';
import '../services/logger_service.dart';
import '../viewmodels/group_viewmodel.dart';

class EditProjectView extends StatefulWidget {
  final int groupId;
  final int projectId;
  final String projectName;
  final String projectDesc;
  final int projectStatusId;
  final String startDate;
  final String endDate;
  
  const EditProjectView({
    Key? key, 
    required this.groupId,
    required this.projectId,
    required this.projectName,
    required this.projectDesc,
    required this.projectStatusId,
    required this.startDate,
    required this.endDate,
  }) : super(key: key);
  
  @override
  _EditProjectViewState createState() => _EditProjectViewState();
}

class _EditProjectViewState extends State<EditProjectView> {
  final LoggerService _logger = LoggerService();
  final TextEditingController _projectNameController = TextEditingController();
  final TextEditingController _projectDescController = TextEditingController();
  
  int _selectedStatus = 1;
  bool _isLoading = false;
  String _errorMessage = '';
  List<ProjectStatus> _projectStatuses = [];
  bool _isLoadingStatuses = true;
  
  // Tarih seçimi
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 7));
  
  @override
  void initState() {
    super.initState();
    _initializeData();
    
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
        _isLoadingStatuses = false;
      });
    } catch (e) {
      _logger.e('Proje durumları yüklenirken hata: $e');
      setState(() {
        _isLoadingStatuses = false;
      });
    }
  }
  
  // Verileri ilklendir
  void _initializeData() {
    _projectNameController.text = widget.projectName;
    _projectDescController.text = widget.projectDesc;
    _selectedStatus = widget.projectStatusId;
    
    // Tarih formatını ayrıştır ("20.04.2025" -> DateTime)
    try {
      final startDateParts = widget.startDate.split('.');
      if (startDateParts.length == 3) {
        _startDate = DateTime(
          int.parse(startDateParts[2]), // Yıl
          int.parse(startDateParts[1]), // Ay
          int.parse(startDateParts[0]), // Gün
        );
      }
      
      final endDateParts = widget.endDate.split('.');
      if (endDateParts.length == 3) {
        _endDate = DateTime(
          int.parse(endDateParts[2]), // Yıl
          int.parse(endDateParts[1]), // Ay
          int.parse(endDateParts[0]), // Gün
        );
      }
    } catch (e) {
      _logger.e('Tarih ayrıştırma hatası: $e');
    }
  }
  
  // Proje güncelle
  Future<void> _updateProject() async {
    final projectName = _projectNameController.text.trim();
    final projectDesc = _projectDescController.text.trim();
    
    if (projectName.isEmpty) {
      setState(() {
        _errorMessage = 'Proje adı boş olamaz';
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      final success = await Provider.of<GroupViewModel>(context, listen: false).updateProject(
        widget.groupId,
        widget.projectId,
        _selectedStatus,
        projectName,
        projectDesc,
        _formatDate(_startDate),
        _formatDate(_endDate),
        [],
      );
      
      if (success && mounted) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _errorMessage = 'Proje güncellenemedi';
          _isLoading = false;
        });
      }
    } catch (e) {
      _logger.e('Proje güncellenirken hata: $e');
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
        title: const Text('Proje Düzenle'),
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
                    PlatformElevatedButton(
                      onPressed: _updateProject,
                      child: const Text('Projeyi Güncelle'),
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
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: isIOS ? CupertinoColors.systemGrey4 : Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: isIOS
                ? GestureDetector(
                    onTap: () {
                      _showStatusPicker(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          // Seçilen durumun renk dairesi
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: _hexToColor(_getSelectedStatusColor()),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Seçilen durum adı
                          Expanded(
                            child: Text(
                              _getSelectedStatusName(),
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                          // Dropdown ikonu
                          const Icon(
                            CupertinoIcons.chevron_down,
                            size: 18,
                            color: CupertinoColors.systemGrey,
                          ),
                        ],
                      ),
                    ),
                  )
                : DropdownButtonFormField<int>(
                    value: _selectedStatus,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: InputBorder.none,
                      isCollapsed: false,
                    ),
                    icon: const Icon(Icons.arrow_drop_down),
                    iconSize: 28,
                    elevation: 2,
                    isExpanded: true,
                    menuMaxHeight: 300,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                    items: _projectStatuses.map((status) {
                      final color = _hexToColor(status.statusColor);
                      return DropdownMenuItem<int>(
                        value: status.statusID,
                        child: Row(
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                status.statusName,
                                style: const TextStyle(fontSize: 16),
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
                  ),
          ),
      ],
    );
  }
  
  // Seçili durum rengini döndür
  String _getSelectedStatusColor() {
    final status = _projectStatuses.firstWhere(
      (s) => s.statusID == _selectedStatus,
      orElse: () => _projectStatuses.first,
    );
    return status.statusColor;
  }
  
  // Seçili durum adını döndür
  String _getSelectedStatusName() {
    final status = _projectStatuses.firstWhere(
      (s) => s.statusID == _selectedStatus,
      orElse: () => _projectStatuses.first,
    );
    return status.statusName;
  }
  
  // iOS için durum seçici
  void _showStatusPicker(BuildContext context) {
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
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Expanded(
              child: CupertinoPicker(
                scrollController: FixedExtentScrollController(
                  initialItem: _projectStatuses.indexWhere((s) => s.statusID == _selectedStatus),
                ),
                itemExtent: 40,
                onSelectedItemChanged: (index) {
                  setState(() {
                    _selectedStatus = _projectStatuses[index].statusID;
                  });
                },
                children: _projectStatuses.map((status) {
                  final color = _hexToColor(status.statusColor);
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        status.statusName,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
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
} 