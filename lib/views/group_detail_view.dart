import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:provider/provider.dart';
import '../models/group_models.dart';
import '../services/api_service.dart';
import '../services/logger_service.dart';
import '../viewmodels/group_viewmodel.dart';

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
  void _editGroup() {
    if (_groupDetail == null) return;
    
    final groupNameController = TextEditingController(text: _groupDetail!.groupName);
    final groupDescController = TextEditingController(text: _groupDetail!.groupDesc);
    
    final isIOS = isCupertino(context);
    
    if (isIOS) {
      showCupertinoDialog(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: const Text('Grubu Düzenle'),
          content: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Grup Adı',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: CupertinoColors.secondaryLabel,
                    ),
                  ),
                  const SizedBox(height: 8),
                  CupertinoTextField(
                    controller: groupNameController,
                    padding: const EdgeInsets.all(10),
                    placeholder: 'Grup Adı',
                    style: const TextStyle(
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Grup Açıklaması',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: CupertinoColors.secondaryLabel,
                    ),
                  ),
                  const SizedBox(height: 8),
                  CupertinoTextField(
                    controller: groupDescController,
                    padding: const EdgeInsets.all(10),
                    placeholder: 'Grup Açıklaması',
                    minLines: 2,
                    maxLines: 3,
                    style: const TextStyle(
                      fontSize: 16,
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
                final newName = groupNameController.text.trim();
                final newDesc = groupDescController.text.trim();
                
                if (newName.isEmpty) {
                  return;
                }
                
                Navigator.pop(context);
                
                try {
                  setState(() {
                    _isLoading = true;
                  });
                  
                  final success = await Provider.of<GroupViewModel>(context, listen: false)
                      .updateGroup(widget.groupId, newName, newDesc);
                  
                  if (success) {
                    _loadGroupDetail();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Grup başarıyla güncellendi')),
                      );
                    }
                  }
                } catch (e) {
                  setState(() {
                    _isLoading = false;
                    _errorMessage = 'Grup güncellenirken hata: $e';
                  });
                }
              },
              isDefaultAction: true,
              child: const Text('Kaydet'),
            ),
          ],
        ),
      );
    } else {
      // Material tasarım için daha esnek bir dialog
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Grubu Düzenle'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: groupNameController,
                  decoration: const InputDecoration(
                    labelText: 'Grup Adı',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: groupDescController,
                  decoration: const InputDecoration(
                    labelText: 'Grup Açıklaması',
                    border: OutlineInputBorder(),
                  ),
                  minLines: 2,
                  maxLines: 3,
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
                final newName = groupNameController.text.trim();
                final newDesc = groupDescController.text.trim();
                
                if (newName.isEmpty) {
                  return;
                }
                
                Navigator.pop(context);
                
                try {
                  setState(() {
                    _isLoading = true;
                  });
                  
                  final success = await Provider.of<GroupViewModel>(context, listen: false)
                      .updateGroup(widget.groupId, newName, newDesc);
                  
                  if (success) {
                    _loadGroupDetail();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Grup başarıyla güncellendi')),
                      );
                    }
                  }
                } catch (e) {
                  setState(() {
                    _isLoading = false;
                    _errorMessage = 'Grup güncellenirken hata: $e';
                  });
                }
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      );
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
    
    // tarih seçici işlevi
    void _openDatePicker() async {
      if (isIOS) {
        showCupertinoModalPopup(
          context: context,
          builder: (_) => Container(
            height: 300,
            color: CupertinoColors.systemBackground.resolveFrom(context),
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
                const Divider(height: 0),
                Expanded(
                  child: CupertinoDatePicker(
                    initialDateTime: selectedDate,
                    minimumDate: now,
                    mode: CupertinoDatePickerMode.date,
                    onDateTimeChanged: (DateTime newDate) {
                      selectedDate = newDate;
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        final pickedDate = await showDatePicker(
          context: context,
          initialDate: selectedDate,
          firstDate: now,
          lastDate: DateTime(now.year + 3),
        );
        
        if (pickedDate != null) {
          setState(() {
            selectedDate = pickedDate;
          });
        }
      }
    }
    
    showPlatformDialog(
      context: context,
      builder: (_) => PlatformAlertDialog(
        title: const Text('Yeni Etkinlik Oluştur'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PlatformTextFormField(
              controller: eventTitleController,
              hintText: 'Etkinlik Başlığı',
              material: (_, __) => MaterialTextFormFieldData(
                decoration: const InputDecoration(
                  labelText: 'Etkinlik Başlığı',
                ),
              ),
              cupertino: (_, __) => CupertinoTextFormFieldData(
                placeholder: 'Etkinlik Başlığı',
              ),
            ),
            const SizedBox(height: 8),
            PlatformTextFormField(
              controller: eventDescController,
              hintText: 'Etkinlik Açıklaması',
              material: (_, __) => MaterialTextFormFieldData(
                decoration: const InputDecoration(
                  labelText: 'Etkinlik Açıklaması',
                ),
                minLines: 2,
                maxLines: 3,
              ),
              cupertino: (_, __) => CupertinoTextFormFieldData(
                placeholder: 'Etkinlik Açıklaması',
                minLines: 2,
                maxLines: 3,
              ),
            ),
            const SizedBox(height: 8),
            PlatformWidget(
              material: (_, __) => ListTile(
                title: const Text('Etkinlik Tarihi'),
                subtitle: Text('${selectedDate.day}/${selectedDate.month}/${selectedDate.year}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: _openDatePicker,
              ),
              cupertino: (_, __) => CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _openDatePicker,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Etkinlik Tarihi'),
                    Text(
                      '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                      style: const TextStyle(color: CupertinoColors.systemGrey),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          PlatformDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          PlatformDialogAction(
            onPressed: () {
              final title = eventTitleController.text.trim();
              final desc = eventDescController.text.trim();
              
              if (title.isEmpty) {
                return;
              }
              
              Navigator.pop(context);
              
              // TODO: Bu kısımda API'yi entegre et (Etkinlik oluşturma API metodu)
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${selectedDate.day}/${selectedDate.month}/${selectedDate.year} tarihli "$title" etkinliği oluşturuldu'),
                ),
              );
            },
            child: const Text('Oluştur'),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final isIOS = isCupertino(context);
    
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: Text(_groupDetail?.groupName ?? 'Grup Detayı'),
        material: (_, __) => MaterialAppBarData(
          actions: <Widget>[
            if (_groupDetail != null && _groupDetail!.users.any((user) => user.isAdmin)) ...[
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: _editGroup,
                tooltip: 'Grubu Düzenle',
              ),
            ],
            IconButton(
              icon: Icon(context.platformIcons.refresh),
              onPressed: _loadGroupDetail,
            ),
          ],
        ),
        cupertino: (_, __) => CupertinoNavigationBarData(
          transitionBetweenRoutes: false,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_groupDetail != null && _groupDetail!.users.any((user) => user.isAdmin)) ...[
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  child: const Icon(CupertinoIcons.pencil),
                  onPressed: _editGroup,
                ),
              ],
              CupertinoButton(
                padding: EdgeInsets.zero,
                child: Icon(context.platformIcons.refresh),
                onPressed: _loadGroupDetail,
              ),
            ],
          ),
        ),
      ),
      body: _buildBody(context),
    );
  }
  
  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return Center(child: PlatformCircularProgressIndicator());
    }
    
    if (_errorMessage.isNotEmpty) {
      return _buildErrorView(context);
    }
    
    if (_groupDetail == null) {
      return Center(
        child: Text(
          'Grup bilgileri bulunamadı',
          style: platformThemeData(
            context,
            material: (data) => data.textTheme.bodyLarge?.copyWith(color: Colors.red),
            cupertino: (data) => data.textTheme.textStyle.copyWith(color: CupertinoColors.systemRed),
          ),
        ),
      );
    }
    
    return Column(
      children: [
        _buildGroupHeader(context),
        _buildSegmentedControl(context),
        Expanded(
          child: _buildSelectedView(context),
        ),
      ],
    );
  }
  
  Widget _buildErrorView(BuildContext context) {
    return Center(
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
  
  Widget _buildSelectedView(BuildContext context) {
    switch (_selectedSegment) {
      case 0:
        return _buildInfoView(context);
      case 1:
        return _buildUsersView(context);
      case 2:
        return _buildProjectsView(context);
      case 3:
        return _buildEventsView(context);
      default:
        return _buildInfoView(context);
    }
  }
  
  Widget _buildInfoView(BuildContext context) {
    final group = _groupDetail!;
    final isIOS = isCupertino(context);
    
    return isIOS
      ? CupertinoListSection.insetGrouped(
          header: const Padding(
            padding: EdgeInsets.only(left: 16.0, bottom: 4),
            child: Text('Grup Bilgileri'),
          ),
          children: [
            CupertinoListTile(
              title: const Text('Paket'),
              additionalInfo: Text(group.packageName),
            ),
            CupertinoListTile(
              title: const Text('Oluşturan'),
              additionalInfo: Text(group.createdBy),
            ),
            CupertinoListTile(
              title: const Text('Oluşturulma Tarihi'),
              additionalInfo: Text(group.createDate),
            ),
            CupertinoListTile(
              title: const Text('Maksimum Kullanıcı'),
              additionalInfo: Text('${group.packMaxUsers}'),
            ),
            CupertinoListTile(
              title: const Text('Maksimum Proje'),
              additionalInfo: Text('${group.packMaxProjects}'),
            ),
            if (!group.isFree)
              CupertinoListTile(
                title: const Text('Fiyat'),
                additionalInfo: Text(group.packPrice),
              ),
          ],
        )
      : ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Grup Bilgileri',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    _buildInfoItem(context, 'Paket', group.packageName),
                    _buildInfoItem(context, 'Oluşturan', group.createdBy),
                    _buildInfoItem(context, 'Oluşturulma Tarihi', group.createDate),
                    _buildInfoItem(context, 'Maksimum Kullanıcı', '${group.packMaxUsers}'),
                    _buildInfoItem(context, 'Maksimum Proje', '${group.packMaxProjects}'),
                    if (!group.isFree)
                      _buildInfoItem(context, 'Fiyat', group.packPrice),
                  ],
                ),
              ),
            ),
          ],
        );
  }
  
  Widget _buildInfoItem(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
  
  Widget _buildUsersView(BuildContext context) {
    final users = _groupDetail!.users;
    final isIOS = isCupertino(context);
    
    if (users.isEmpty) {
      return Center(
        child: Text(
          'Henüz kullanıcı bulunmuyor',
          style: platformThemeData(
            context,
            material: (data) => data.textTheme.bodyMedium?.copyWith(color: Colors.grey),
            cupertino: (data) => data.textTheme.textStyle.copyWith(color: CupertinoColors.secondaryLabel),
          ),
        ),
      );
    }
    
    return isIOS
      ? CupertinoListSection.insetGrouped(
          header: Padding(
            padding: const EdgeInsets.only(left: 16.0, bottom: 4),
            child: Text('${users.length} Kullanıcı'),
          ),
          children: users.map((user) {
            return CupertinoListTile(
              title: Text(user.userName),
              subtitle: Text('Katılım: ${user.joinedDate}'),
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: user.isAdmin 
                    ? CupertinoColors.systemIndigo.withOpacity(0.1)
                    : CupertinoColors.systemGrey5,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    user.isAdmin 
                      ? CupertinoIcons.person_crop_circle_badge_checkmark
                      : CupertinoIcons.person_crop_circle,
                    color: user.isAdmin 
                      ? CupertinoColors.systemIndigo
                      : CupertinoColors.secondaryLabel,
                  ),
                ),
              ),
              trailing: user.isAdmin
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemIndigo.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      user.userRole,
                      style: const TextStyle(
                        fontSize: 12,
                        color: CupertinoColors.systemIndigo,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : Text(
                    user.userRole,
                    style: const TextStyle(
                      fontSize: 12,
                      color: CupertinoColors.secondaryLabel,
                    ),
                  ),
            );
          }).toList(),
        )
      : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(user.userName),
                subtitle: Text('Katılım: ${user.joinedDate}'),
                leading: CircleAvatar(
                  backgroundColor: user.isAdmin 
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).colorScheme.surfaceVariant,
                  child: Icon(
                    user.isAdmin ? Icons.admin_panel_settings : Icons.person,
                    color: user.isAdmin 
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                trailing: user.isAdmin
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        user.userRole,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  : Text(user.userRole),
              ),
            );
          },
        );
  }
  
  Widget _buildProjectsView(BuildContext context) {
    final projects = _groupDetail!.projects;
    final isIOS = isCupertino(context);
    
    if (projects.isEmpty) {
      return Center(
        child: Text(
          'Henüz proje bulunmuyor',
          style: platformThemeData(
            context,
            material: (data) => data.textTheme.bodyMedium?.copyWith(color: Colors.grey),
            cupertino: (data) => data.textTheme.textStyle.copyWith(color: CupertinoColors.secondaryLabel),
          ),
        ),
      );
    }
    
    return isIOS
      ? CupertinoListSection.insetGrouped(
          header: Padding(
            padding: const EdgeInsets.only(left: 16.0, bottom: 4),
            child: Text('${projects.length} Proje'),
          ),
          children: projects.map((project) {
            return CupertinoListTile(
              title: Text(project.projectName),
              subtitle: Text('Durumu: ${project.projectStatus}'),
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: CupertinoColors.systemBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Icon(
                    CupertinoIcons.collections,
                    color: CupertinoColors.systemBlue,
                  ),
                ),
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  project.projectStatus,
                  style: const TextStyle(
                    fontSize: 12,
                    color: CupertinoColors.systemBlue,
                  ),
                ),
              ),
            );
          }).toList(),
        )
      : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: projects.length,
          itemBuilder: (context, index) {
            final project = projects[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(project.projectName),
                subtitle: Text('Durumu: ${project.projectStatus}'),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.folder,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    project.projectStatus,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
            );
          },
        );
  }
  
  Widget _buildEventsView(BuildContext context) {
    final events = _groupDetail!.events;
    final isIOS = isCupertino(context);
    
    // Etkinlik Oluşturma butonu
    final createEventButton = isIOS
        ? GestureDetector(
            onTap: _createEvent,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: CupertinoColors.systemBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: CupertinoColors.systemBlue.withOpacity(0.3)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    CupertinoIcons.add_circled,
                    color: CupertinoColors.systemBlue,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Yeni Etkinlik Oluştur',
                    style: TextStyle(
                      color: CupertinoColors.systemBlue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          )
        : ElevatedButton.icon(
            onPressed: _createEvent,
            icon: const Icon(Icons.add),
            label: const Text('Yeni Etkinlik Oluştur'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            ),
          );
    
    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Henüz etkinlik bulunmuyor',
              style: platformThemeData(
                context,
                material: (data) => data.textTheme.bodyMedium?.copyWith(color: Colors.grey),
                cupertino: (data) => data.textTheme.textStyle.copyWith(color: CupertinoColors.secondaryLabel),
              ),
            ),
            const SizedBox(height: 16),
            createEventButton,
          ],
        ),
      );
    }
    
    // Şu anki zaman
    final now = DateTime.now();
    
    // Geçmiş ve gelecek etkinlikleri ayrıştır
    final pastEvents = events.where((event) {
      try {
        final eventDate = DateTime.parse(event.eventDate.replaceAll('.', '-'));
        return eventDate.isBefore(now);
      } catch (_) {
        return false;
      }
    }).toList();
    
    final upcomingEvents = events.where((event) {
      try {
        final eventDate = DateTime.parse(event.eventDate.replaceAll('.', '-'));
        return eventDate.isAfter(now) || eventDate.isAtSameMomentAs(now);
      } catch (_) {
        return true; // Tarih ayrıştırılamazsa gelecek etkinliklere ekle
      }
    }).toList();
    
    upcomingEvents.sort((a, b) {
      try {
        final dateA = DateTime.parse(a.eventDate.replaceAll('.', '-'));
        final dateB = DateTime.parse(b.eventDate.replaceAll('.', '-'));
        return dateA.compareTo(dateB);
      } catch (_) {
        return 0;
      }
    });
    
    pastEvents.sort((a, b) {
      try {
        final dateA = DateTime.parse(a.eventDate.replaceAll('.', '-'));
        final dateB = DateTime.parse(b.eventDate.replaceAll('.', '-'));
        return dateB.compareTo(dateA); // Geçmiş etkinlikler için ters sıralama
      } catch (_) {
        return 0;
      }
    });
    
    if (isIOS) {
      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 0),
            child: createEventButton,
          ),
          if (upcomingEvents.isNotEmpty)
            CupertinoListSection.insetGrouped(
              header: Padding(
                padding: const EdgeInsets.only(left: 16.0, bottom: 4, top: 8),
                child: Text('Yaklaşan Etkinlikler (${upcomingEvents.length})'),
              ),
              children: upcomingEvents.map((event) => _buildEventTile(context, event, true)).toList(),
            ),
          if (pastEvents.isNotEmpty)
            CupertinoListSection.insetGrouped(
              header: Padding(
                padding: const EdgeInsets.only(left: 16.0, bottom: 4, top: 8),
                child: Text('Geçmiş Etkinlikler (${pastEvents.length})'),
              ),
              children: pastEvents.map((event) => _buildEventTile(context, event, false)).toList(),
            ),
        ],
      );
    } else {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: createEventButton,
          ),
          if (upcomingEvents.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Yaklaşan Etkinlikler (${upcomingEvents.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ...upcomingEvents.map((event) => _buildEventCard(context, event, true)).toList(),
            const SizedBox(height: 16),
          ],
          if (pastEvents.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Geçmiş Etkinlikler (${pastEvents.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ...pastEvents.map((event) => _buildEventCard(context, event, false)).toList(),
          ],
        ],
      );
    }
  }
  
  Widget _buildEventTile(BuildContext context, GroupEvent event, bool isUpcoming) {
    return CupertinoListTile(
      title: Text(event.eventTitle),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (event.eventDesc.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              event.eventDesc,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                fontSize: 13,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                CupertinoIcons.person_alt_circle,
                size: 12,
                color: CupertinoColors.secondaryLabel,
              ),
              const SizedBox(width: 4),
              Text(
                event.userFullname,
                style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                  fontSize: 12,
                  color: CupertinoColors.secondaryLabel,
                ),
              ),
            ],
          ),
        ],
      ),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isUpcoming
            ? CupertinoColors.systemIndigo.withOpacity(0.1)
            : CupertinoColors.systemGrey5,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Icon(
            CupertinoIcons.calendar,
            color: isUpcoming
              ? CupertinoColors.systemIndigo
              : CupertinoColors.secondaryLabel,
          ),
        ),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: isUpcoming
            ? CupertinoColors.systemOrange.withOpacity(0.1)
            : CupertinoColors.systemGrey5,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          event.eventDate,
          style: TextStyle(
            fontSize: 12,
            color: isUpcoming
              ? CupertinoColors.systemOrange
              : CupertinoColors.secondaryLabel,
          ),
        ),
      ),
    );
  }
  
  Widget _buildEventCard(BuildContext context, GroupEvent event, bool isUpcoming) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isUpcoming
                      ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                      : Theme.of(context).colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.event,
                    color: isUpcoming
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.eventTitle,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (event.eventDesc.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          event.eventDesc,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isUpcoming
                      ? Theme.of(context).colorScheme.secondary.withOpacity(0.1)
                      : Theme.of(context).colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    event.eventDate,
                    style: TextStyle(
                      fontSize: 12,
                      color: isUpcoming
                        ? Theme.of(context).colorScheme.secondary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 52, top: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.person,
                    size: 14,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    event.userFullname,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Spacer(),
                  Text(
                    'Oluşturulma: ${event.createDate}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
} 