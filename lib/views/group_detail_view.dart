import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../models/group_models.dart';
import '../services/api_service.dart';
import '../services/logger_service.dart';
import '../viewmodels/group_viewmodel.dart';
import '../views/edit_group_view.dart';
import '../views/project_detail_view.dart';
import '../views/create_project_view.dart';

class GroupDetailView extends StatefulWidget {
  final int groupId;
  
  const GroupDetailView({Key? key, required this.groupId}) : super(key: key);
  
  @override
  _GroupDetailViewState createState() => _GroupDetailViewState();
}

class _GroupDetailViewState extends State<GroupDetailView> {
  final ApiService _apiService = ApiService();
  final LoggerService _logger = LoggerService();
  
  GroupDetail? _groupDetail;
  bool _isLoading = true;
  String _errorMessage = '';
  int _selectedSegment = 0; // 0: Bilgiler, 1: Kullanıcılar, 2: Projeler, 3: Etkinlikler, 4: Raporlar
  List<GroupLog> _groupLogs = [];
  bool _isLoadingLogs = false;
  bool _isDisposed = false;
  
  @override
  void initState() {
    super.initState();
    _loadGroupDetail();
  }
  
  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
  
  // Güvenli setState
  void _safeSetState(VoidCallback fn) {
    if (!_isDisposed && mounted) {
      setState(fn);
    }
  }
  
  Future<void> _loadGroupDetail() async {
    _safeSetState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      final groupDetail = await _apiService.group.getGroupDetail(widget.groupId);
      _safeSetState(() {
        _groupDetail = groupDetail;
        _isLoading = false;
      });
      _logger.i('Grup detayları yüklendi: ${groupDetail.groupName}');
    } catch (e) {
      _safeSetState(() {
        _errorMessage = 'Grup detayları yüklenemedi: $e';
        _isLoading = false;
      });
      _logger.e('Grup detayları yüklenirken hata: $e');
    }
  }
  
  // Grup düzenleme işlevi
  Future<void> _editGroup() async {
    if (_groupDetail == null) return;
    
    final result = await Navigator.of(context).push(
      platformPageRoute(
        context: context,
        builder: (context) => EditGroupView(
          groupId: widget.groupId,
          groupName: _groupDetail!.groupName,
          groupDesc: _groupDetail!.groupDesc,
        ),
      ),
    );
    
    if (result == true && mounted && !_isDisposed) {
      await _loadGroupDetail();
      try {
        final messenger = ScaffoldMessenger.of(context);
        messenger.showSnackBar(
          const SnackBar(content: Text('Grup başarıyla güncellendi')),
        );
      } catch (e) {
        _logger.e('ScaffoldMessenger hatası: $e');
      }
    }
  }

  // Etkinlik oluşturma işlevi
  void _createEvent() {
    if (_groupDetail == null) return;
    
    final eventTitleController = TextEditingController();
    final eventDescController = TextEditingController();
    
    final isIOS = isCupertino(context);
    final now = DateTime.now();
    DateTime selectedDate = now;
    
    if (isIOS) {
      showCupertinoDialog(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: const Text('Yeni Etkinlik Oluştur'),
          content: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Etkinlik Adı',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: CupertinoColors.secondaryLabel,
                    ),
                  ),
                  const SizedBox(height: 8),
                  CupertinoTextField(
                    controller: eventTitleController,
                    padding: const EdgeInsets.all(10),
                    placeholder: 'Etkinlik Adı',
                    style: const TextStyle(
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Etkinlik Açıklaması',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: CupertinoColors.secondaryLabel,
                    ),
                  ),
                  const SizedBox(height: 8),
                  CupertinoTextField(
                    controller: eventDescController,
                    padding: const EdgeInsets.all(10),
                    placeholder: 'Etkinlik Açıklaması',
                    minLines: 2,
                    maxLines: 3,
                    style: const TextStyle(
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Etkinlik Tarihi',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: CupertinoColors.secondaryLabel,
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () {
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
                                      _safeSetState(() {});
                                      Navigator.pop(context);
                                    },
                                  ),
                                ],
                              ),
                              Expanded(
                                child: CupertinoDatePicker(
                                  initialDateTime: selectedDate,
                                  minimumDate: now,
                                  mode: CupertinoDatePickerMode.date,
                                  use24hFormat: true,
                                  onDateTimeChanged: (date) {
                                    selectedDate = date;
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        border: Border.all(color: CupertinoColors.systemGrey4),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${selectedDate.day}.${selectedDate.month}.${selectedDate.year}',
                            style: const TextStyle(fontSize: 16),
                          ),
                          const Icon(
                            CupertinoIcons.calendar,
                            color: CupertinoColors.activeBlue,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal'),
            ),
            CupertinoDialogAction(
              onPressed: () async {
                final title = eventTitleController.text.trim();
                final desc = eventDescController.text.trim();
                
                if (title.isEmpty) {
                  return;
                }
                
                Navigator.pop(context);
                
                try {
                  _safeSetState(() {
                    _isLoading = true;
                  });
                  
                  // Burada etkinlik oluşturma API çağrısı yapılacak
                  _logger.i('Etkinlik oluşturuluyor: $title');
                  
                  // API çağrısı tamamlandığında
                  await Future.delayed(const Duration(seconds: 1)); // API çağrısı simülasyonu
                  
                  // Başarılı ise
                  if (!_isDisposed && mounted) {
                    _loadGroupDetail(); // Grup detayını yeniden yükle
                  }
                  
                  if (mounted && !_isDisposed) {
                    final messenger = ScaffoldMessenger.of(context);
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Etkinlik başarıyla oluşturuldu')),
                    );
                  }
                } catch (e) {
                  _safeSetState(() {
                    _isLoading = false;
                    _errorMessage = 'Etkinlik oluşturulurken hata: $e';
                  });
                }
              },
              isDefaultAction: true,
              child: const Text('Oluştur'),
            ),
          ],
        ),
      );
    } else {
      // Material tasarım için diyalog
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Yeni Etkinlik Oluştur'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: eventTitleController,
                  decoration: const InputDecoration(
                    labelText: 'Etkinlik Adı',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: eventDescController,
                  decoration: const InputDecoration(
                    labelText: 'Etkinlik Açıklaması',
                    border: OutlineInputBorder(),
                  ),
                  minLines: 2,
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: now,
                      lastDate: DateTime(now.year + 5),
                    );
                    if (date != null) {
                      setState(() {
                        selectedDate = date;
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Etkinlik Tarihi',
                      border: OutlineInputBorder(),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${selectedDate.day}.${selectedDate.month}.${selectedDate.year}'),
                        const Icon(Icons.calendar_today),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal'),
            ),
            TextButton(
              onPressed: () async {
                final title = eventTitleController.text.trim();
                final desc = eventDescController.text.trim();
                
                if (title.isEmpty) {
                  return;
                }
                
                Navigator.pop(context);
                
                try {
                  _safeSetState(() {
                    _isLoading = true;
                  });
                  
                  // Burada etkinlik oluşturma API çağrısı yapılacak
                  _logger.i('Etkinlik oluşturuluyor: $title');
                  
                  // API çağrısı tamamlandığında
                  await Future.delayed(const Duration(seconds: 1)); // API çağrısı simülasyonu
                  
                  // Başarılı ise
                  if (!_isDisposed && mounted) {
                    _loadGroupDetail(); // Grup detayını yeniden yükle
                  }
                  
                  if (mounted && !_isDisposed) {
                    final messenger = ScaffoldMessenger.of(context);
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Etkinlik başarıyla oluşturuldu')),
                    );
                  }
                } catch (e) {
                  _safeSetState(() {
                    _isLoading = false;
                    _errorMessage = 'Etkinlik oluşturulurken hata: $e';
                  });
                }
              },
              child: const Text('Oluştur'),
            ),
          ],
        ),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: Text(_groupDetail?.groupName ?? 'Grup Detayı'),
        trailingActions: _groupDetail != null && _groupDetail!.users.any((user) => user.isAdmin)
            ? [
                PlatformIconButton(
                  icon: Icon(
                    isCupertino(context) ? CupertinoIcons.pencil : Icons.edit,
                  ),
                  onPressed: _editGroup,
                ),
              ]
            : null,
      ),
      body: SafeArea(
        child: _isLoading
            ? Center(child: PlatformCircularProgressIndicator())
            : _errorMessage.isNotEmpty
                ? _buildErrorView(context)
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildGroupHeader(context),
                        _buildSegmentedControl(context),
                        _buildSelectedContent(context),
                      ],
                    ),
                  ),
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
                onPressed: _loadGroupDetail,
                child: const Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Hata mesajlarını temizleme
  String _formatErrorMessage(String error) {
    // Uzun hata mesajlarını kısaltma
    if (error.length > 100) {
      error = '${error.substring(0, 100)}...';
    }
    
    // "Exception: " text'ini kaldırma
    if (error.startsWith('Exception: ')) {
      error = error.substring('Exception: '.length);
    }
    
    return error;
  }

  Widget _buildGroupHeader(BuildContext context) {
    final group = _groupDetail!;
    final isIOS = isCupertino(context);
    
    return Container(
      padding: const EdgeInsets.all(16.0),
      color: isIOS 
        ? (group.users.any((user) => user.isAdmin) 
            ? CupertinoColors.activeBlue.withOpacity(0.1) 
            : CupertinoColors.systemBackground)
        : (group.users.any((user) => user.isAdmin) 
            ? Theme.of(context).colorScheme.primaryContainer 
            : Theme.of(context).colorScheme.surface),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.groupName,
                      style: platformThemeData(
                        context,
                        material: (data) => data.textTheme.titleLarge,
                        cupertino: (data) => data.textTheme.navLargeTitleTextStyle.copyWith(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (group.groupDesc.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        group.groupDesc,
                        style: platformThemeData(
                          context,
                          material: (data) => data.textTheme.bodyMedium,
                          cupertino: (data) => data.textTheme.textStyle,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: group.isFree
                    ? isIOS 
                        ? CupertinoColors.activeGreen.withOpacity(0.1)
                        : Colors.green.withOpacity(0.1)
                    : isIOS 
                        ? CupertinoColors.systemOrange.withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  group.packageName,
                  style: TextStyle(
                    fontSize: 12,
                    color: group.isFree
                      ? isIOS 
                          ? CupertinoColors.activeGreen
                          : Colors.green
                      : isIOS 
                          ? CupertinoColors.systemOrange
                          : Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                isIOS ? CupertinoIcons.person : Icons.person,
                size: 14,
                color: isIOS ? CupertinoColors.secondaryLabel : Colors.grey[600],
              ),
              const SizedBox(width: 4),
              Text(
                '${group.totalUsers} Kullanıcı',
                style: platformThemeData(
                  context,
                  material: (data) => data.textTheme.bodySmall,
                  cupertino: (data) => data.textTheme.tabLabelTextStyle.copyWith(
                    color: CupertinoColors.secondaryLabel,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Icon(
                isIOS ? CupertinoIcons.collections : Icons.collections_bookmark,
                size: 14,
                color: isIOS ? CupertinoColors.secondaryLabel : Colors.grey[600],
              ),
              const SizedBox(width: 4),
              Text(
                '${group.projects.length} Proje',
                style: platformThemeData(
                  context,
                  material: (data) => data.textTheme.bodySmall,
                  cupertino: (data) => data.textTheme.tabLabelTextStyle.copyWith(
                    color: CupertinoColors.secondaryLabel,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildSegmentedControl(BuildContext context) {
    final isIOS = isCupertino(context);
    
    if (isIOS) {
      final Map<int, Widget> segments = {
        0: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 1),
          child: Text('Bilgiler'),
        ),
        1: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 1),
          child: Text('Üyeler'),
        ),
        2: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 1),
          child: Text('Projeler'),
        ),
        3: const Padding(
          padding: EdgeInsets.symmetric(horizontal:1),
          child: Text('Etkinlikler'),
        ),
        4: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 1),
          child: Text('Raporlar'),
        ),
      };
      
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: CupertinoSlidingSegmentedControl<int>(
          groupValue: _selectedSegment,
          onValueChanged: (value) {
            if (value != null) {
              setState(() {
                _selectedSegment = value;
              });
              
              // Raporlar sekmesi seçildiğinde logları yükle
              if (value == 4 && _groupLogs.isEmpty && !_isLoadingLogs) {
                // Build bittikten sonra çağır
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _loadGroupLogs();
                });
              }
            }
          },
          children: segments,
        ),
      );
    } else {
      // Material design için TabBar oluşturulabilir
      return Container(
        height: 50,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).dividerColor,
              width: 1,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildMaterialTab(context, 'Bilgiler', 0),
            _buildMaterialTab(context, 'Üyeler', 1),
            _buildMaterialTab(context, 'Projeler', 2),
            _buildMaterialTab(context, 'Etkinlikler', 3),
            _buildMaterialTab(context, 'Raporlar', 4),
          ],
        ),
      );
    }
  }
  
  Widget _buildMaterialTab(BuildContext context, String title, int index) {
    return InkWell(
      onTap: () {
        setState(() {
          _selectedSegment = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: _selectedSegment == index 
                ? Theme.of(context).colorScheme.primary 
                : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              color: _selectedSegment == index 
                ? Theme.of(context).colorScheme.primary 
                : Theme.of(context).textTheme.bodyMedium?.color,
              fontWeight: _selectedSegment == index 
                ? FontWeight.bold 
                : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildSelectedContent(BuildContext context) {
    switch (_selectedSegment) {
      case 0:
        return _buildInfoTab(context);
      case 1:
        return _buildMembersTab(context);
      case 2:
        return _buildProjectsTab(context);
      case 3:
        return _buildEventsTab(context);
      case 4:
        return _buildReportsTab(context);
      default:
        return _buildInfoTab(context);
    }
  }
  
  Widget _buildInfoTab(BuildContext context) {
    final group = _groupDetail!;
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Grup Bilgileri',
            style: platformThemeData(
              context,
              material: (data) => data.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              cupertino: (data) => data.textTheme.navTitleTextStyle,
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: Icon(
              isCupertino(context) ? CupertinoIcons.person_2 : Icons.people,
              color: isCupertino(context) ? CupertinoColors.activeBlue : Colors.blue,
            ),
            title: const Text('Üye Sayısı'),
            trailing: Text(
              '${group.totalUsers}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(),
          ListTile(
            leading: Icon(
              isCupertino(context) ? CupertinoIcons.folder : Icons.folder,
              color: isCupertino(context) ? CupertinoColors.systemIndigo : Colors.indigo,
            ),
            title: const Text('Proje Sayısı'),
            trailing: Text(
              '${group.projects.length}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(),
          ListTile(
            leading: Icon(
              isCupertino(context) ? CupertinoIcons.calendar : Icons.event,
              color: isCupertino(context) ? CupertinoColors.systemOrange : Colors.orange,
            ),
            title: const Text('Etkinlik Sayısı'),
            trailing: Text(
              '${group.events.length}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(),
          ListTile(
            leading: Icon(
              isCupertino(context) ? CupertinoIcons.tag : Icons.label,
              color: isCupertino(context) ? CupertinoColors.systemGreen : Colors.green,
            ),
            title: const Text('Paket Türü'),
            trailing: Text(
              group.packageName,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: group.isFree 
                  ? isCupertino(context) ? CupertinoColors.activeGreen : Colors.green
                  : isCupertino(context) ? CupertinoColors.systemOrange : Colors.orange,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Hızlı İşlemler',
            style: platformThemeData(
              context,
              material: (data) => data.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              cupertino: (data) => data.textTheme.navTitleTextStyle,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildQuickActionButton(
                icon: isCupertino(context) ? CupertinoIcons.calendar_badge_plus : Icons.event_available,
                color: isCupertino(context) ? CupertinoColors.activeBlue : Colors.blue,
                label: 'Etkinlik Ekle',
                onTap: _createEvent,
              ),
              if (group.users.any((user) => user.isAdmin))
                _buildQuickActionButton(
                  icon: isCupertino(context) ? CupertinoIcons.person_badge_plus : Icons.person_add,
                  color: isCupertino(context) ? CupertinoColors.systemGreen : Colors.green,
                  label: 'Üye Ekle',
                  onTap: () {
                    // Üye ekleme işlevi eklenecek
                  },
                ),
              _buildQuickActionButton(
                icon: isCupertino(context) ? CupertinoIcons.chat_bubble_2 : Icons.chat,
                color: isCupertino(context) ? CupertinoColors.systemOrange : Colors.orange,
                label: 'Grup Sohbeti',
                onTap: () {
                  // Grup sohbeti açma işlevi eklenecek
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildQuickActionButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMembersTab(BuildContext context) {
    final group = _groupDetail!;
    final isIOS = isCupertino(context);
    final hasAdminRights = group.users.any((user) => user.isAdmin);
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Grup Üyeleri (${group.users.length})',
                style: platformThemeData(
                  context,
                  material: (data) => data.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  cupertino: (data) => data.textTheme.navTitleTextStyle,
                ),
              ),
              if (group.isAddUser && hasAdminRights)
                PlatformIconButton(
                  icon: Icon(
                    isIOS ? CupertinoIcons.person_add : Icons.person_add,
                    color: isIOS ? CupertinoColors.activeBlue : Colors.blue,
                  ),
                  onPressed: _inviteUser,
                ),
            ],
          ),
          const SizedBox(height: 16),
          ...group.users.map((user) => Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: user.isAdmin 
                    ? (isIOS ? CupertinoColors.activeBlue : Colors.blue).withOpacity(0.2) 
                    : (isIOS ? CupertinoColors.systemGrey : Colors.grey).withOpacity(0.2),
                child: Text(
                  user.userName.substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    color: user.isAdmin 
                        ? (isIOS ? CupertinoColors.activeBlue : Colors.blue)
                        : (isIOS ? CupertinoColors.systemGrey : Colors.grey),
                  ),
                ),
              ),
              title: Text(user.userName),
              subtitle: Text(user.isAdmin ? 'Yönetici' : 'Üye'),
              trailing: hasAdminRights && !user.isAdmin 
                ? PlatformIconButton(
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      isIOS ? CupertinoIcons.trash : Icons.delete_outline,
                      color: isIOS ? CupertinoColors.destructiveRed : Colors.red,
                      size: 20,
                    ),
                    onPressed: () => _confirmRemoveUser(user),
                  )
                : (user.isAdmin 
                  ? Icon(
                      isIOS ? CupertinoIcons.shield : Icons.shield,
                      color: isIOS ? CupertinoColors.activeBlue : Colors.blue,
                    )
                  : null),
            ),
          )).toList(),
        ],
      ),
    );
  }
  
  void _confirmRemoveUser(GroupUser user) {
    final isIOS = isCupertino(context);
    
    if (isIOS) {
      showCupertinoDialog(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: const Text('Kullanıcıyı Çıkar'),
          content: Text('${user.userName} kullanıcısını gruptan çıkarmak istediğinize emin misiniz?'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('İptal'),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.pop(dialogContext);
                _removeUser(user.userID);
              },
              child: const Text('Çıkar'),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Kullanıcıyı Çıkar'),
          content: Text('${user.userName} kullanıcısını gruptan çıkarmak istediğinize emin misiniz?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('İptal'),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              onPressed: () async {
                Navigator.pop(dialogContext);
                await _removeUser(user.userID);
              },
              child: const Text('Çıkar'),
            ),
          ],
        ),
      );
    }
  }
  
  Future<void> _removeUser(int userID) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final success = await Provider.of<GroupViewModel>(context, listen: false)
          .removeUserFromGroup(widget.groupId, userID);
      
      if (mounted) {
        if (success) {
          await _loadGroupDetail();
          try {
            final messenger = ScaffoldMessenger.of(context);
            messenger.showSnackBar(
              const SnackBar(content: Text('Kullanıcı başarıyla çıkarıldı')),
            );
          } catch (e) {
            _logger.e('ScaffoldMessenger hatası: $e');
          }
        } else {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Kullanıcı çıkarılamadı.';
          });
          
          _showErrorSnackbar('Kullanıcı çıkarma işlemi başarısız oldu. Lütfen daha sonra tekrar deneyin.');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
        
        _showErrorSnackbar(_formatErrorMessage(e.toString()));
      }
    }
  }
  
  // Kullanıcı davet et
  Future<void> _inviteUser() async {
    if (_groupDetail == null) return;
    
    final emailController = TextEditingController();
    int selectedRole = 1; // 1 = Normal kullanıcı, 2 = Admin
    String selectedInviteType = 'email'; // email veya qr
    
    final isIOS = isCupertino(context);
    
    if (isIOS) {
      showCupertinoDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) {
            return CupertinoAlertDialog(
              title: const Text('Kullanıcı Davet Et'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  CupertinoTextField(
                    controller: emailController,
                    placeholder: 'E-posta Adresi',
                    keyboardType: TextInputType.emailAddress,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: CupertinoColors.systemGrey4),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  const SizedBox(height: 15),
                  const Text('Kullanıcı Rolü'),
                  const SizedBox(height: 8),
                  CupertinoSlidingSegmentedControl<int>(
                    groupValue: selectedRole,
                    children: const {
                      1: Text('Üye'),
                      2: Text('Admin'),
                    },
                    onValueChanged: (value) {
                      if (value != null) {
                        // Burada Stateful Builder'ın setState'ini kullanıyoruz
                        // bu yüzden safe kontrolü yapmıyoruz
                        setState(() {
                          selectedRole = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 15),
                  const Text('Davet Yöntemi'),
                  const SizedBox(height: 8),
                  CupertinoSlidingSegmentedControl<String>(
                    groupValue: selectedInviteType,
                    children: const {
                      'email': Text('E-posta'),
                      'qr': Text('QR Kod'),
                    },
                    onValueChanged: (value) {
                      if (value != null) {
                        setState(() {
                          selectedInviteType = value;
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                CupertinoDialogAction(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('İptal'),
                ),
                CupertinoDialogAction(
                  isDefaultAction: true,
                  onPressed: () async {
                    final email = emailController.text.trim();
                    
                    // Her iki davet türü için de e-posta alanı zorunlu
                    if (email.isEmpty) {
                      // E-posta adresi boş ise uyarı göster
                      _showErrorSnackbar('E-posta adresi boş bırakılamaz');
                      return;
                    }
                    
                    Navigator.pop(context);
                    
                    if (selectedInviteType == 'qr') {
                      // QR kod davetini başlat
                      await _createQRInvite(email, selectedRole);
                    } else {
                      // Email davetini başlat
                      await _sendInvite(email, selectedRole, 'email');
                    }
                  },
                  child: const Text('Davet Et'),
                ),
              ],
            );
          },
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Kullanıcı Davet Et'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'E-posta Adresi',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 15),
                  const Text('Kullanıcı Rolü'),
                  const SizedBox(height: 8),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment<int>(value: 1, label: Text('Üye')),
                      ButtonSegment<int>(value: 2, label: Text('Admin')),
                    ],
                    selected: {selectedRole},
                    onSelectionChanged: (newSelection) {
                      // Burada Stateful Builder'ın setState'ini kullanıyoruz
                      setState(() {
                        selectedRole = newSelection.first;
                      });
                    },
                  ),
                  const SizedBox(height: 15),
                  const Text('Davet Yöntemi'),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment<String>(value: 'email', label: Text('E-posta')),
                      ButtonSegment<String>(value: 'qr', label: Text('QR Kod')),
                    ],
                    selected: {selectedInviteType},
                    onSelectionChanged: (newSelection) {
                      setState(() {
                        selectedInviteType = newSelection.first;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('İptal'),
                ),
                TextButton(
                  onPressed: () async {
                    final email = emailController.text.trim();
                    
                    // Her iki davet türü için de e-posta alanı zorunlu
                    if (email.isEmpty) {
                      // E-posta adresi boş ise uyarı göster
                      _showErrorSnackbar('E-posta adresi boş bırakılamaz');
                      return;
                    }
                    
                    Navigator.pop(context);
                    
                    if (selectedInviteType == 'qr') {
                      // QR kod davetini başlat
                      await _createQRInvite(email, selectedRole);
                    } else {
                      // Email davetini başlat 
                      await _sendInvite(email, selectedRole, 'email');
                    }
                  },
                  child: const Text('Davet Et'),
                ),
              ],
            );
          },
        ),
      );
    }
  }
  
  Future<void> _createQRInvite(String email, int role) async {
    if (_groupDetail == null) return;
    
    _safeSetState(() {
      _isLoading = true;
    });
    
    try {
      final viewModel = Provider.of<GroupViewModel>(context, listen: false);
      // QR kod için de geçerli bir email adresi gönderiyoruz
      final result = await viewModel.inviteUserToGroup(
        widget.groupId, 
        email, // API zorunlu kıldığı için email parametresini gönderiyoruz
        role, 
        'qr' // davet tipi: qr
      );
      
      _safeSetState(() {
        _isLoading = false;
      });
      
      if (!_isDisposed && mounted) {
        // Davet başarılı ise
        if (result['success'] == true && result['inviteUrl'].isNotEmpty) {
          // QR kod diyalogunu göster
          _showQRInviteDialog(result['inviteUrl'], role);
        } else {
          _safeSetState(() {
            _errorMessage = 'QR kodu oluşturulamadı';
          });
          
          _showErrorSnackbar('QR kodu oluşturma işlemi başarısız oldu. Lütfen daha sonra tekrar deneyin.');
        }
      }
    } catch (e) {
      if (!_isDisposed && mounted) {
        _safeSetState(() {
          _isLoading = false;
          _errorMessage = 'QR kod oluşturulurken hata: $e';
        });
        
        _showErrorSnackbar(_formatErrorMessage(e.toString()));
      }
    }
  }
  
  void _showQRInviteDialog(String inviteUrl, int role) {
    if (!mounted || _isDisposed) return;
    
    final isIOS = isCupertino(context);
    final roleText = role == 2 ? 'Üye' : 'Yönetici';
    
    if (isIOS) {
      showCupertinoModalPopup(
        context: context,
        builder: (context) => CupertinoPageScaffold(
          navigationBar: CupertinoNavigationBar(
            middle: const Text('Davet QR Kodu'),
            leading: CupertinoButton(
              padding: EdgeInsets.zero,
              child: const Text('Kapat'),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 10),
                  Text(
                    'Bu QR kodu kullanarak gruba davet edebilirsiniz',
                    style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: CupertinoColors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: CupertinoColors.systemGrey.withOpacity(0.2),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: QrImageView(
                      data: inviteUrl,
                      version: QrVersions.auto,
                      size: 250,
                      backgroundColor: Colors.white,
                      foregroundColor: CupertinoColors.black,
                      errorCorrectionLevel: QrErrorCorrectLevel.H,
                      // Embedded image'i geçici olarak kaldıralım, assets sorunu çözülene kadar
                      // embeddedImage: const AssetImage('assets/app_icon.png'),
                      // embeddedImageStyle: const QrEmbeddedImageStyle(
                      //   size: Size(40, 40),
                      // ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          CupertinoIcons.info,
                          color: CupertinoColors.systemBlue,
                          size: 20,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Kullanıcı rolü: $roleText\nBu QR kod ile katılan kullanıcılar $roleText olarak eklenecektir.',
                          style: const TextStyle(
                            fontSize: 14,
                            color: CupertinoColors.systemBlue,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        color: CupertinoColors.activeBlue,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(CupertinoIcons.doc_on_doc, size: 18),
                            SizedBox(width: 8),
                            Text('Kopyala', style: TextStyle(color: CupertinoColors.white)),
                          ],
                        ),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: inviteUrl)).then((_) {
                            if (!_isDisposed && mounted) {
                              _safeSetState(() {});
                              final scaffoldMessengerState = ScaffoldMessenger.maybeOf(context);
                              if (scaffoldMessengerState != null) {
                                scaffoldMessengerState.showSnackBar(
                                  const SnackBar(content: Text('QR verisi panoya kopyalandı')),
                                );
                              }
                              Navigator.pop(context);
                            }
                          });
                        },
                      ),
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        color: CupertinoColors.activeGreen,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(CupertinoIcons.share, size: 18),
                            SizedBox(width: 8),
                            Text('Paylaş', style: TextStyle(color: CupertinoColors.white)),
                          ],
                        ),
                        onPressed: () {
                          // Share_plus paketi ile paylaşım işlevi
                          Share.share(
                            '${_groupDetail!.groupName} grubuna bu davet bağlantısı ile katılabilirsiniz: $inviteUrl',
                            subject: '${_groupDetail!.groupName} Grup Daveti'
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Davet QR Kodu'),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 10),
                    Text(
                      'Bu QR kodu kullanarak gruba davet edebilirsiniz',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: QrImageView(
                        data: inviteUrl,
                        version: QrVersions.auto,
                        size: 250,
                        backgroundColor: Colors.white,
                        errorCorrectionLevel: QrErrorCorrectLevel.H,
                        // Embedded image'i geçici olarak kaldıralım, assets sorunu çözülene kadar
                        // embeddedImage: const AssetImage('assets/app_icon.png'),
                        // embeddedImageStyle: const QrEmbeddedImageStyle(
                        //   size: Size(40, 40),
                        // ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: Colors.blue,
                            size: 20,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Kullanıcı rolü: $roleText\nBu QR kod ile katılan kullanıcılar $roleText olarak eklenecektir.',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.blue,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                          icon: const Icon(Icons.copy, size: 18),
                          label: const Text('Kopyala', style: TextStyle(color: Colors.white)),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: inviteUrl)).then((_) {
                              if (!_isDisposed && mounted) {
                                _safeSetState(() {});
                                final scaffoldMessengerState = ScaffoldMessenger.maybeOf(context);
                                if (scaffoldMessengerState != null) {
                                  scaffoldMessengerState.showSnackBar(
                                    const SnackBar(content: Text('QR verisi panoya kopyalandı')),
                                  );
                                }
                                Navigator.pop(context);
                              }
                            });
                          },
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                          icon: const Icon(Icons.share, size: 18),
                          label: const Text('Paylaş', style: TextStyle(color: Colors.white)),
                          onPressed: () {
                            // Share_plus paketi ile paylaşım işlevi
                            Share.share(
                              '${_groupDetail!.groupName} grubuna bu davet bağlantısı ile katılabilirsiniz: $inviteUrl',
                              subject: '${_groupDetail!.groupName} Grup Daveti'
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
  }
  
  // Davet gönder
  Future<void> _sendInvite(String email, int role, String inviteType) async {
    if (_groupDetail == null) return;
    
    _safeSetState(() {
      _isLoading = true;
    });
    
    try {
      final viewModel = Provider.of<GroupViewModel>(context, listen: false);
      final result = await viewModel.inviteUserToGroup(
        widget.groupId, 
        email, 
        role, 
        inviteType // davet tipi: email veya qr
      );
      
      if (!_isDisposed && mounted) {
        // Davet başarılı ise
        if (result['success'] == true) {
          // Grup verilerini güncelle
          await _loadGroupDetail();
          
          // Davet URL'ini göster (QR kodu için)
          if (result['inviteUrl'] != null && result['inviteUrl'].isNotEmpty) {
            _showInviteUrlDialog(result['inviteUrl']);
          } else {
            final messenger = ScaffoldMessenger.of(context);
            messenger.showSnackBar(
              SnackBar(content: Text('Davet başarıyla gönderildi: $email')),
            );
          }
        } else {
          _safeSetState(() {
            _isLoading = false;
            _errorMessage = 'Davet gönderilemedi: ${result['error']}';
          });
          
          _showErrorSnackbar(_errorMessage);
        }
      }
    } catch (e) {
      if (!_isDisposed && mounted) {
        _safeSetState(() {
          _isLoading = false;
          _errorMessage = 'Davet gönderilirken hata: $e';
        });
        
        _showErrorSnackbar(_formatErrorMessage(e.toString()));
      }
    }
  }
  
  // Hata mesajı snackbar göster
  void _showErrorSnackbar(String message) {
    if (!mounted || _isDisposed) return;
    
    final isIOS = isCupertino(context);
    final errorColor = isIOS ? CupertinoColors.systemRed : Colors.red;
    
    try {
      // ScaffoldMessenger.of çağrılmadan önce geçerli bir Scaffold olduğundan emin olalım
      final scaffoldMessengerState = ScaffoldMessenger.maybeOf(context);
      if (scaffoldMessengerState == null) {
        _logger.w('ScaffoldMessenger bulunamadı, SnackBar gösterilemiyor');
        return;
      }
      
      scaffoldMessengerState.showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: errorColor,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      _logger.e('SnackBar gösterirken hata: $e');
    }
  }
  
  // Davet URL'ini dialog ile göster
  void _showInviteUrlDialog(String inviteUrl) {
    if (!mounted || _isDisposed) return;
    
    final isIOS = isCupertino(context);
    
    if (isIOS) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Davet URL\'i'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              const Text('Bu URL\'i paylaşarak kullanıcıları davet edebilirsiniz'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey6,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  inviteUrl,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: inviteUrl)).then((_) {
                  if (!_isDisposed && mounted) {
                    _safeSetState(() {});
                    final scaffoldMessengerState = ScaffoldMessenger.maybeOf(context);
                    if (scaffoldMessengerState != null) {
                      scaffoldMessengerState.showSnackBar(
                        const SnackBar(content: Text('URL panoya kopyalandı')),
                      );
                    }
                    Navigator.pop(context);
                  }
                });
              },
              child: const Text('Kopyala', style: TextStyle(color: CupertinoColors.white)),
            ),
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: const Text('Kapat'),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Davet URL\'i'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Bu URL\'i paylaşarak kullanıcıları davet edebilirsiniz'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  inviteUrl,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: inviteUrl)).then((_) {
                  if (!_isDisposed && mounted) {
                    _safeSetState(() {});
                    final scaffoldMessengerState = ScaffoldMessenger.maybeOf(context);
                    if (scaffoldMessengerState != null) {
                      scaffoldMessengerState.showSnackBar(
                        const SnackBar(content: Text('URL panoya kopyalandı')),
                      );
                    }
                    Navigator.pop(context);
                  }
                });
              },
              child: const Text('Kopyala', style: TextStyle(color: Colors.white)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Kapat'),
            ),
          ],
        ),
      );
    }
  }
  
  Widget _buildProjectsTab(BuildContext context) {
    final group = _groupDetail!;
    final hasAdminRights = group.users.any((user) => user.isAdmin);
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Projeler (${group.projects.length})',
                style: platformThemeData(
                  context,
                  material: (data) => data.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  cupertino: (data) => data.textTheme.navTitleTextStyle,
                ),
              ),
              if (group.isAddProject) // Proje ekleme yetkisi varsa
                PlatformIconButton(
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    isCupertino(context) ? CupertinoIcons.add : Icons.add,
                    color: isCupertino(context) ? CupertinoColors.activeBlue : Colors.blue,
                  ),
                  onPressed: _createProject,
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (group.projects.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32.0),
                child: Column(
                  children: [
                    Icon(
                      isCupertino(context) ? CupertinoIcons.folder : Icons.folder_outlined,
                      size: 48,
                      color: isCupertino(context) ? CupertinoColors.systemGrey : Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Henüz proje bulunmuyor',
                      style: TextStyle(
                        color: isCupertino(context) ? CupertinoColors.systemGrey : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ...group.projects.map((project) => Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: ListTile(
              leading: Icon(
                isCupertino(context) ? CupertinoIcons.folder_fill : Icons.folder,
                color: isCupertino(context) ? CupertinoColors.activeBlue : Colors.blue,
              ),
              title: Text(project.projectName),
              subtitle: Text('${project.projectStatusID} görev'),
              trailing: hasAdminRights 
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PlatformIconButton(
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          isCupertino(context) ? CupertinoIcons.delete : Icons.delete_outline,
                          color: isCupertino(context) ? CupertinoColors.systemRed : Colors.red,
                          size: 20,
                        ),
                        onPressed: () => _confirmDeleteProject(project.projectID),
                      ),
                      Icon(
                        isCupertino(context) ? CupertinoIcons.chevron_right : Icons.chevron_right,
                      ),
                    ],
                  )
                : Icon(
                    isCupertino(context) ? CupertinoIcons.chevron_right : Icons.chevron_right,
                  ),
              onTap: () {
                // Proje detayına gitme işlevi
                Navigator.of(context).push(
                  platformPageRoute(
                    context: context,
                    builder: (context) => ProjectDetailView(
                      projectId: project.projectID,
                      groupId: widget.groupId,
                    ),
                  ),
                );
              },
            ),
          )).toList(),
        ],
      ),
    );
  }
  
  // Proje oluşturma işlevi
  void _createProject() async {
    if (_groupDetail == null) return;
    
    final result = await Navigator.of(context).push(
      platformPageRoute(
        context: context,
        builder: (context) => CreateProjectView(
          groupId: widget.groupId,
          groupUsers: _groupDetail!.users,
        ),
      ),
    );
    
    if (result == true && mounted) {
      await _loadGroupDetail();
      try {
        final messenger = ScaffoldMessenger.of(context);
        messenger.showSnackBar(
          const SnackBar(content: Text('Proje başarıyla oluşturuldu')),
        );
      } catch (e) {
        _logger.e('ScaffoldMessenger hatası: $e');
      }
    }
  }
  
  Widget _buildEventsTab(BuildContext context) {
    final group = _groupDetail!;
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Etkinlikler (${group.events.length})',
            style: platformThemeData(
              context,
              material: (data) => data.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              cupertino: (data) => data.textTheme.navTitleTextStyle,
            ),
          ),
          const SizedBox(height: 16),
          if (group.events.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32.0),
                child: Column(
                  children: [
                    Icon(
                      isCupertino(context) ? CupertinoIcons.calendar : Icons.event_note_outlined,
                      size: 48,
                      color: isCupertino(context) ? CupertinoColors.systemGrey : Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Henüz etkinlik bulunmuyor',
                      style: TextStyle(
                        color: isCupertino(context) ? CupertinoColors.systemGrey : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ...group.events.map((event) => Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Card(
              elevation: isCupertino(context) ? 0 : 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: isCupertino(context) 
                  ? BorderSide(color: CupertinoColors.systemGrey5) 
                  : BorderSide.none,
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isCupertino(context) ? CupertinoIcons.calendar : Icons.event,
                          color: isCupertino(context) ? CupertinoColors.systemOrange : Colors.orange,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          event.eventTitle,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    if (event.eventDesc.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        event.eventDesc,
                        style: TextStyle(
                          color: isCupertino(context) ? CupertinoColors.secondaryLabel : Colors.grey[700],
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          isCupertino(context) ? CupertinoIcons.time : Icons.access_time,
                          size: 14,
                          color: isCupertino(context) ? CupertinoColors.secondaryLabel : Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Tarih: ${event.eventDate}', // Tarih formatı düzenlenebilir
                          style: TextStyle(
                            fontSize: 12,
                            color: isCupertino(context) ? CupertinoColors.secondaryLabel : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          )).toList(),
        ],
      ),
    );
  }
  
  // Grup loglarını (raporlarını) yükle
  Future<void> _loadGroupLogs() async {
    if (_isLoadingLogs || _groupDetail == null) return;
    
    _safeSetState(() {
      _isLoadingLogs = true;
    });
    
    try {
      final viewModel = Provider.of<GroupViewModel>(context, listen: false);
      final logs = await viewModel.getGroupReports(
        widget.groupId, 
        _groupDetail!.users.any((user) => user.isAdmin),
      );
      
      if (!_isDisposed && mounted) {
        _safeSetState(() {
          _groupLogs = logs;
          _isLoadingLogs = false;
        });
      }
    } catch (e) {
      if (!_isDisposed && mounted) {
        _safeSetState(() {
          _errorMessage = 'Grup etkinlikleri yüklenemedi: $e';
          _isLoadingLogs = false;
        });
      }
    }
  }

  // Raporlar tab'i
  Widget _buildReportsTab(BuildContext context) {
    final isIOS = isCupertino(context);
    
    if (_isLoadingLogs) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_groupLogs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32.0),
          child: Column(
            children: [
              Icon(
                isIOS ? CupertinoIcons.doc_text_search : Icons.assignment_late,
                size: 48,
                color: isIOS ? CupertinoColors.systemGrey : Colors.grey,
              ),
              const SizedBox(height: 16),
              Text(
                'Henüz log kaydı bulunmuyor',
                style: TextStyle(
                  color: isIOS ? CupertinoColors.systemGrey : Colors.grey,
                ),
              ),
              const SizedBox(height: 24),
              PlatformElevatedButton(
                onPressed: _loadGroupLogs,
                child: const Text('Yenile'),
              ),
            ],
          ),
        ),
      );
    }
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Grup Raporları (${_groupLogs.length})',
                style: platformThemeData(
                  context,
                  material: (data) => data.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  cupertino: (data) => data.textTheme.navTitleTextStyle,
                ),
              ),
              PlatformIconButton(
                padding: EdgeInsets.zero,
                icon: Icon(
                  isIOS ? CupertinoIcons.refresh : Icons.refresh,
                  size: 20,
                ),
                onPressed: _loadGroupLogs,
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _groupLogs.length,
            itemBuilder: (context, index) {
              final log = _groupLogs[index];
              return _buildLogItem(context, log);
            },
          ),
        ],
      ),
    );
  }
  
  // Log öğesi
  Widget _buildLogItem(BuildContext context, GroupLog log) {
    final isIOS = isCupertino(context);
    
    // Log tipine göre ikon ve renk belirle
    IconData logIcon;
    Color logColor;
    
    if (log.logName.contains('Tamamlandı')) {
      logIcon = isIOS ? CupertinoIcons.checkmark_circle : Icons.check_circle;
      logColor = isIOS ? CupertinoColors.activeGreen : Colors.green;
    } else if (log.logName.contains('Tamamlanmadı')) {
      logIcon = isIOS ? CupertinoIcons.xmark_circle : Icons.cancel;
      logColor = isIOS ? CupertinoColors.systemRed : Colors.red;
    } else if (log.logName.contains('Açıldı')) {
      logIcon = isIOS ? CupertinoIcons.add_circled : Icons.add_circle;
      logColor = isIOS ? CupertinoColors.activeBlue : Colors.blue;
    } else {
      logIcon = isIOS ? CupertinoIcons.doc_text : Icons.article;
      logColor = isIOS ? CupertinoColors.systemGrey : Colors.grey;
    }
    
    return Card(
      elevation: isIOS ? 0 : 1,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isIOS 
          ? BorderSide(color: CupertinoColors.systemGrey5) 
          : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  logIcon,
                  color: logColor,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    log.logName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: logColor,
                    ),
                  ),
                ),
                Text(
                  log.createDate,
                  style: TextStyle(
                    fontSize: 12,
                    color: isIOS ? CupertinoColors.secondaryLabel : Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              log.logDesc,
              style: TextStyle(
                fontSize: 13,
                color: isIOS ? CupertinoColors.label : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  isIOS ? CupertinoIcons.folder : Icons.folder,
                  size: 12,
                  color: isIOS ? CupertinoColors.secondaryLabel : Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  'Proje ID: ${log.projectID}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isIOS ? CupertinoColors.secondaryLabel : Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  isIOS ? CupertinoIcons.doc_text : Icons.assignment,
                  size: 12,
                  color: isIOS ? CupertinoColors.secondaryLabel : Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  'Görev ID: ${log.workID}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isIOS ? CupertinoColors.secondaryLabel : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Proje silme işlemi
  Future<void> _confirmDeleteProject(int projectID) async {
    final isIOS = isCupertino(context);
    
    if (isIOS) {
      showCupertinoDialog(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: const Text('Projeyi Sil'),
          content: const Text('Bu projeyi silmek istediğinize emin misiniz? Bu işlem geri alınamaz ve projede yer alan tüm görevler ve veriler silinecektir.'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('İptal'),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () async {
                // Dialog'u kapatalım, daha sonra silme işlemini yapalım
                Navigator.pop(dialogContext);
                
                // Ana sayfa bağlamında SnackBar göstermek için silme işlemini ana sayfada çalıştıralım
                // Bu sayede Scaffold Context hatası önlenmiş olur
                if (mounted) {
                  await _deleteProject(projectID);
                }
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
          title: const Text('Projeyi Sil'),
          content: const Text('Bu projeyi silmek istediğinize emin misiniz? Bu işlem geri alınamaz ve projede yer alan tüm görevler ve veriler silinecektir.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('İptal'),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              onPressed: () async {
                // Dialog'u kapatalım, daha sonra silme işlemini yapalım
                Navigator.pop(dialogContext);
                
                // Ana sayfa bağlamında SnackBar göstermek için silme işlemini ana sayfada çalıştıralım
                if (mounted) {
                  await _deleteProject(projectID);
                }
              },
              child: const Text('Sil'),
            ),
          ],
        ),
      );
    }
  }
  
  // Proje silme işlemini gerçekleştir
  Future<void> _deleteProject(int projectID) async {
    if (!mounted || _isDisposed) return;
    
    _safeSetState(() {
      _isLoading = true;
    });
    
    try {
      // Proje silme API çağrısı
      final result = await _apiService.project.deleteProject(projectID, widget.groupId);
      
      if (!_isDisposed && mounted) {
        _safeSetState(() {
          _isLoading = false;
        });
        
        // Detayları yenile
        await _loadGroupDetail();
        
        // SnackBar gösterimi için daha güvenli bir yaklaşım
        if (!_isDisposed && mounted) {
          // Ana sayfada bir Scaffold var ve onu kullanabiliriz
          try {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Proje başarıyla silindi')),
            );
          } catch (e) {
            _logger.w('SnackBar gösterilemiyor: $e');
          }
        }
      }
    } catch (e) {
      if (!_isDisposed && mounted) {
        _safeSetState(() {
          _isLoading = false;
          _errorMessage = _formatErrorMessage(e.toString());
        });
        
        // Hata durumunu logla
        _logger.e('Proje silme hatası: $_errorMessage');
      }
    }
  }

  // Güvenli hata mesajı göster
  void _showSafeErrorMessage(String message) {
    if (!mounted || _isDisposed) return;
    
    _logger.w('Hata mesajı: $message');
    
    // Toast mesajı göstermeyi deneyebiliriz, ya da UI'da bir banner/text gösterebiliriz
    // Şimdilik sadece log ile yetinelim ve kullanıcıya görsel feedback verelim
    
    // Toast mesajı için fluttertoast paketini kullanabilirsiniz
    
    // Alternatif olarak, ana sayfaya bir hata banner'ı ekleyebiliriz
    _safeSetState(() {
      _errorMessage = message;
    });
  }

  // QR kodunu göster
  void _showQrCode() {
    if (_groupDetail == null) return;
    
    final isIOS = isCupertino(context);
    
    // QR kodu oluştur
    final qrData = 'group:${widget.groupId}';
    
    if (isIOS) {
      showCupertinoModalPopup(
        context: context,
        builder: (context) => CupertinoActionSheet(
          title: const Text('Grup QR Kodu'),
          message: Column(
            children: [
              const Text('Başkalarının bu grubu taramasına izin verecek QR kodu:'),
              const SizedBox(height: 20),
              Container(
                color: CupertinoColors.white,
                padding: const EdgeInsets.all(16),
                child: QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: 200,
                  backgroundColor: Colors.white,
                ),
              ),
            ],
          ),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: qrData)).then((_) {
                  if (!_isDisposed && mounted) {
                    _safeSetState(() {});
                    final scaffoldMessengerState = ScaffoldMessenger.maybeOf(context);
                    if (scaffoldMessengerState != null) {
                      scaffoldMessengerState.showSnackBar(
                        const SnackBar(content: Text('QR verisi panoya kopyalandı')),
                      );
                    }
                    Navigator.pop(context);
                  }
                });
              },
              child: const Text('QR Verisini Kopyala'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Kapat'),
          ),
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Grup QR Kodu'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Başkalarının bu grubu taramasına izin verecek QR kodu:'),
                const SizedBox(height: 20),
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: QrImageView(
                    data: qrData,
                    version: QrVersions.auto,
                    size: 200,
                    backgroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: qrData)).then((_) {
                  if (!_isDisposed && mounted) {
                    _safeSetState(() {});
                    final scaffoldMessengerState = ScaffoldMessenger.maybeOf(context);
                    if (scaffoldMessengerState != null) {
                      scaffoldMessengerState.showSnackBar(
                        const SnackBar(content: Text('QR verisi panoya kopyalandı')),
                      );
                    }
                    Navigator.pop(context);
                  }
                });
              },
              child: const Text('Kopyala', style: TextStyle(color: Colors.white)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Kapat'),
            ),
          ],
        ),
      );
    }
  }
} 