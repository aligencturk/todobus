import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/group_models.dart';
import '../services/api_service.dart';
import '../services/logger_service.dart';
import '../viewmodels/group_viewmodel.dart';
import '../views/edit_group_view.dart';

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
  int _selectedSegment = 0; // 0: Bilgiler, 1: Kullanıcılar, 2: Projeler, 3: Etkinlikler
  
  @override
  void initState() {
    super.initState();
    _loadGroupDetail();
  }
  
  Future<void> _loadGroupDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      final groupDetail = await _apiService.getGroupDetail(widget.groupId);
      setState(() {
        _groupDetail = groupDetail;
        _isLoading = false;
      });
      _logger.i('Grup detayları yüklendi: ${groupDetail.groupName}');
    } catch (e) {
      setState(() {
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
    
    if (result == true && mounted) {
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
                                      setState(() {});
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
                  setState(() {
                    _isLoading = true;
                  });
                  
                  // Burada etkinlik oluşturma API çağrısı yapılacak
                  _logger.i('Etkinlik oluşturuluyor: $title');
                  
                  // API çağrısı tamamlandığında
                  await Future.delayed(const Duration(seconds: 1)); // API çağrısı simülasyonu
                  
                  // Başarılı ise
                  _loadGroupDetail(); // Grup detayını yeniden yükle
                  
                  if (mounted) {
                    final messenger = ScaffoldMessenger.of(context);
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Etkinlik başarıyla oluşturuldu')),
                    );
                  }
                } catch (e) {
                  setState(() {
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
                  setState(() {
                    _isLoading = true;
                  });
                  
                  // Burada etkinlik oluşturma API çağrısı yapılacak
                  _logger.i('Etkinlik oluşturuluyor: $title');
                  
                  // API çağrısı tamamlandığında
                  await Future.delayed(const Duration(seconds: 1)); // API çağrısı simülasyonu
                  
                  // Başarılı ise
                  _loadGroupDetail(); // Grup detayını yeniden yükle
                  
                  if (mounted) {
                    final messenger = ScaffoldMessenger.of(context);
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Etkinlik başarıyla oluşturuldu')),
                    );
                  }
                } catch (e) {
                  setState(() {
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
    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Hata: $_errorMessage',
                style: platformThemeData(
                  context,
                  material: (data) => data.textTheme.bodyLarge?.copyWith(color: Colors.red),
                  cupertino: (data) => data.textTheme.textStyle.copyWith(color: CupertinoColors.systemRed),
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
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text('Bilgiler'),
        ),
        1: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text('Üyeler'),
        ),
        2: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text('Projeler'),
        ),
        3: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text('Etkinlikler'),
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
                  onPressed: _showInviteUserDialog,
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
              onPressed: () {
                Navigator.pop(dialogContext);
                _removeUser(user.userID);
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
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Kullanıcı çıkarılırken hata: $e';
        });
      }
    }
  }
  
  void _showInviteUserDialog() {
    final emailController = TextEditingController();
    final isIOS = isCupertino(context);
    int selectedRole = 2; // Varsayılan: Üye
    String selectedInviteType = 'email'; // Varsayılan: Email
    
    if (isIOS) {
      showCupertinoModalPopup(
        context: context,
        builder: (_) => StatefulBuilder(
          builder: (context, setState) {
            return CupertinoActionSheet(
              title: const Text('Kullanıcı Davet Et'),
              message: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'E-posta Adresi',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: CupertinoColors.secondaryLabel,
                      ),
                    ),
                    const SizedBox(height: 8),
                    CupertinoTextField(
                      controller: emailController,
                      placeholder: 'E-posta adresi',
                      keyboardType: TextInputType.emailAddress,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: CupertinoColors.systemGrey4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Kullanıcı Rolü',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: CupertinoColors.secondaryLabel,
                      ),
                    ),
                    const SizedBox(height: 8),
                    CupertinoSlidingSegmentedControl<int>(
                      groupValue: selectedRole,
                      children: const {
                        1: Text('Yönetici'),
                        2: Text('Üye'),
                      },
                      onValueChanged: (value) {
                        if (value != null) {
                          setState(() {
                            selectedRole = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Davet Yöntemi',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: CupertinoColors.secondaryLabel,
                      ),
                    ),
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
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              actions: [
                CupertinoActionSheetAction(
                  onPressed: () {
                    Navigator.pop(context);
                    _sendInvitation(
                      emailController.text.trim(), 
                      selectedRole, 
                      selectedInviteType
                    );
                  },
                  child: const Text('Davet Gönder'),
                ),
              ],
              cancelButton: CupertinoActionSheetAction(
                onPressed: () => Navigator.pop(context),
                child: const Text('İptal'),
              ),
            );
          }
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (_) => StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Kullanıcı Davet Et'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: emailController,
                      decoration: const InputDecoration(
                        labelText: 'E-posta Adresi',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Kullanıcı Rolü',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment<int>(
                          value: 1,
                          label: Text('Yönetici'),
                        ),
                        ButtonSegment<int>(
                          value: 2,
                          label: Text('Üye'),
                        ),
                      ],
                      selected: {selectedRole},
                      onSelectionChanged: (Set<int> selection) {
                        setState(() {
                          selectedRole = selection.first;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Davet Yöntemi',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment<String>(
                          value: 'email',
                          label: Text('E-posta'),
                        ),
                        ButtonSegment<String>(
                          value: 'qr',
                          label: Text('QR Kod'),
                        ),
                      ],
                      selected: {selectedInviteType},
                      onSelectionChanged: (Set<String> selection) {
                        setState(() {
                          selectedInviteType = selection.first;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('İptal'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _sendInvitation(
                      emailController.text.trim(), 
                      selectedRole, 
                      selectedInviteType
                    );
                  },
                  child: const Text('Davet Gönder'),
                ),
              ],
            );
          }
        ),
      );
    }
  }
  
  Future<void> _sendInvitation(String email, int role, String inviteType) async {
    if (email.isEmpty && inviteType == 'email') {
      // Sadece email davetinde email zorunlu
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        const SnackBar(content: Text('Lütfen e-posta adresi girin')),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final result = await Provider.of<GroupViewModel>(context, listen: false)
          .inviteUserToGroup(widget.groupId, email, role, inviteType);
      
      setState(() {
        _isLoading = false;
      });
      
      if (result['success'] == true) {
        if (inviteType == 'qr' && result['inviteUrl'] != null) {
          // QR Kodu göster
          _showQRCode(result['inviteUrl']);
        } else {
          // Email daveti başarılı mesajı göster
          final messenger = ScaffoldMessenger.of(context);
          messenger.showSnackBar(
            const SnackBar(content: Text('Davet başarıyla gönderildi')),
          );
        }
      } else {
        final messenger = ScaffoldMessenger.of(context);
        messenger.showSnackBar(
          SnackBar(content: Text('Davet gönderilemedi: ${result['error'] ?? "Bilinmeyen hata"}')),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(content: Text('Davet gönderilirken hata: $e')),
      );
    }
  }
  
  void _showQRCode(String inviteUrl) {
    final isIOS = isCupertino(context);
    
    if (isIOS) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Davet QR Kodu'),
          content: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Bu QR kodu kullarak gruba davet edebilirsiniz',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                Container(
                  width: 200,
                  height: 200,
                  color: CupertinoColors.white,
                  child: QrImageView(
                    data: inviteUrl,
                    version: QrVersions.auto,
                    size: 200,
                    backgroundColor: CupertinoColors.white,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () {
                    // Link kopyalama işlevi eklenebilir
                  },
                  child: Text(
                    inviteUrl,
                    style: const TextStyle(
                      fontSize: 10, 
                      color: CupertinoColors.activeBlue,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          actions: [
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
          title: const Text('Davet QR Kodu'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Bu QR kodu kullarak gruba davet edebilirsiniz',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  width: 200,
                  height: 200,
                  color: Colors.white,
                  child: QrImageView(
                    data: inviteUrl,
                    version: QrVersions.auto,
                    size: 200,
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () {
                    // Link kopyalama işlevi eklenebilir
                  },
                  child: Text(
                    inviteUrl,
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).primaryColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          actions: [
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
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Projeler (${group.projects.length})',
            style: platformThemeData(
              context,
              material: (data) => data.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              cupertino: (data) => data.textTheme.navTitleTextStyle,
            ),
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
              trailing: Icon(
                isCupertino(context) ? CupertinoIcons.chevron_right : Icons.chevron_right,
              ),
              onTap: () {
                // Proje detayına gitme işlevi eklenecek
              },
            ),
          )).toList(),
        ],
      ),
    );
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
} 