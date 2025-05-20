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
import '../viewmodels/report_viewmodel.dart';
import '../views/edit_group_view.dart';
import '../views/project_detail_view.dart';
import '../views/create_project_view.dart';
import '../views/event_detail_view.dart';
import '../views/create_event_view.dart';
import '../views/report_detail_view.dart';
import '../services/storage_service.dart';

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
  List<GroupReport> _groupReports = [];
  bool _isLoadingLogs = false;
  bool _isLoadingReports = false;
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
      _showSnackBar('Grup başarıyla güncellendi');
    }
  }

  // Etkinlik detayına gitme işlevi
  void _navigateToEventDetail(GroupEvent event) {
    Navigator.of(context).push(
      platformPageRoute(
        context: context,
        builder: (context) => EventDetailPage(
          groupId: widget.groupId,
          eventTitle: event.eventTitle,
          eventDescription: event.eventDesc,
          eventDate: event.eventDate,
          eventUser: event.userFullname,
        ),
      ),
    );
  }

  // Etkinlik oluşturma sayfasına gitme işlevi
  void _navigateToCreateEventView() {
    Navigator.of(context).push(
      platformPageRoute(
        context: context,
        builder: (context) => CreateEventView(
          initialGroupID: widget.groupId,
          initialDate: DateTime.now(),
        ),
      ),
    ).then((result) {
      if (result == true && mounted) {
        _loadGroupDetail(); // Grup detaylarını yenile
        _showSnackBar('Etkinlik başarıyla oluşturuldu');
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final bool hasAdminRights = _groupDetail?.users.any((user) => user.isAdmin) ?? false;
    
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: Text(_groupDetail?.groupName ?? 'Grup Detayı'),
        trailingActions: hasAdminRights
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
    if (_groupDetail == null) return const SizedBox();
    
    final group = _groupDetail!;
    final isIOS = isCupertino(context);
    final bool isAdmin = group.users.any((user) => user.isAdmin);
    final Color headerColor = isIOS 
        ? (isAdmin ? CupertinoColors.activeBlue.withOpacity(0.1) : CupertinoColors.systemBackground)
        : (isAdmin ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.surface);
    final TextStyle labelStyle = platformThemeData(
      context,
      material: (data) => data.textTheme.bodySmall ?? const TextStyle(),
      cupertino: (data) => data.textTheme.tabLabelTextStyle.copyWith(
        color: CupertinoColors.secondaryLabel,
      ),
    );
    
    return Container(
      padding: const EdgeInsets.all(16.0),
      color: headerColor,
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
              _buildPackageIndicator(context, group.isFree, group.packageName),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildIconWithText(
                context: context, 
                icon: isIOS ? CupertinoIcons.person : Icons.person, 
                text: '${group.totalUsers} Kullanıcı',
                style: labelStyle
              ),
              const SizedBox(width: 16),
              _buildIconWithText(
                context: context, 
                icon: isIOS ? CupertinoIcons.collections : Icons.collections_bookmark, 
                text: '${group.projects.length} Proje',
                style: labelStyle
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPackageIndicator(BuildContext context, bool isFree, String packageName) {
    final isIOS = isCupertino(context);
    final Color bgColor = isFree
        ? isIOS ? CupertinoColors.activeGreen.withOpacity(0.1) : Colors.green.withOpacity(0.1)
        : isIOS ? CupertinoColors.systemOrange.withOpacity(0.1) : Colors.orange.withOpacity(0.1);
    final Color textColor = isFree
        ? isIOS ? CupertinoColors.activeGreen : Colors.green
        : isIOS ? CupertinoColors.systemOrange : Colors.orange;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        packageName,
        style: TextStyle(
          fontSize: 12,
          color: textColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildIconWithText({
    required BuildContext context, 
    required IconData icon, 
    required String text,
    TextStyle? style
  }) {
    final Color iconColor = isCupertino(context) 
        ? CupertinoColors.secondaryLabel 
        : Colors.grey[600] ?? Colors.grey;
    final double iconSize = 16;
    
    return Row(
      children: [
        Icon(icon, size: iconSize, color: iconColor),
        const SizedBox(width: 4),
        Text(text, style: style),
      ],
    );
  }
 


  
  Widget _buildSegmentedControl(BuildContext context) {
    final isIOS = isCupertino(context);

    if (isIOS) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: CupertinoSlidingSegmentedControl<int>(
          groupValue: _selectedSegment,
          children: const {
            0: Text('Bilgiler'),
            1: Text('Üyeler'),
            2: Text('Projeler'),
            3: Text('Etkinlikler'),
            4: Text('Raporlar'),
          },
          onValueChanged: (value) {
            if (value != null) {
              _safeSetState(() {
                _selectedSegment = value;
              });
              
              // Raporlar sekmesi seçildiğinde raporları yükle
              if (value == 4 && _groupReports.isEmpty) {
                _loadReports();
              }
            }
          },
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.all(12.0),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment<int>(value: 0, label: Text('Bilgiler')),
              ButtonSegment<int>(value: 1, label: Text('Üyeler')),
              ButtonSegment<int>(value: 2, label: Text('Projeler')),
              ButtonSegment<int>(value: 3, label: Text('Etkinlikler')),
              ButtonSegment<int>(value: 4, label: Text('Raporlar')),
            ],
            selected: {_selectedSegment},
            onSelectionChanged: (newSelection) {
              _safeSetState(() {
                _selectedSegment = newSelection.first;
              });
              
              // Raporlar sekmesi seçildiğinde raporları yükle
              if (newSelection.first == 4 && _groupReports.isEmpty) {
                _loadReports();
              }
            },
          ),
        ),
      );
    }
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
    if (_groupDetail == null) return const SizedBox();
    
    final group = _groupDetail!;
    final isIOS = isCupertino(context);
    final isAdmin = group.users.any((user) => user.isAdmin);
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(context, 'Grup Bilgileri'),
          const SizedBox(height: 12),
          
          // Bilgi kartları
          _buildInfoCard(
            context, 
            'Üye Sayısı', 
            '${group.totalUsers}', 
            isIOS ? CupertinoIcons.person_2_fill : Icons.people,
            isIOS ? CupertinoColors.activeBlue : Colors.blue
          ),
          const Divider(),
          _buildInfoCard(
            context, 
            'Proje Sayısı', 
            '${group.projects.length}', 
            isIOS ? CupertinoIcons.folder_fill : Icons.folder,
            isIOS ? CupertinoColors.systemIndigo : Colors.indigo
          ),
          const Divider(),
          _buildInfoCard(
            context, 
            'Etkinlik Sayısı', 
            '${group.events.length}', 
            isIOS ? CupertinoIcons.calendar : Icons.event_note,
            isIOS ? CupertinoColors.systemOrange : Colors.orange
          ),
          const Divider(),
          _buildInfoCard(
            context, 
            'Paket Türü', 
            group.packageName, 
            isIOS ? CupertinoIcons.tag_fill : Icons.local_offer,
            isIOS ? CupertinoColors.systemGreen : Colors.green,
            valueColor: group.isFree 
                ? (isIOS ? CupertinoColors.activeGreen : Colors.green)
                : (isIOS ? CupertinoColors.systemOrange : Colors.orange)
          ),
          
         
        ],
      ),
    );
  }
  
  // Info kartı widget'ı
  Widget _buildInfoCard(
    BuildContext context, 
    String title, 
    String value, 
    IconData iconData, 
    Color iconColor,
    {Color? valueColor}
  ) {
    final double iconSize = 24.0;
    
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Icon(iconData, color: iconColor, size: iconSize),
        ),
      ),
      title: Text(title),
      trailing: Text(
        value,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: valueColor,
        ),
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
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    isIOS ? CupertinoIcons.person_badge_plus : Icons.person_add_alt,
                    color: isIOS ? CupertinoColors.activeBlue : Colors.blue,
                    size: 22,
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
                backgroundImage: user.profilePhoto != null && user.profilePhoto.isNotEmpty
                    ? NetworkImage(user.profilePhoto)
                    : null,
                child: user.profilePhoto == null || user.profilePhoto.isEmpty
                    ? Text(
                        user.userName.substring(0, 1).toUpperCase(),
                        style: TextStyle(
                          color: user.isAdmin 
                              ? (isIOS ? CupertinoColors.activeBlue : Colors.blue)
                              : (isIOS ? CupertinoColors.systemGrey : Colors.grey),
                        ),
                      )
                    : null,
              ),
              title: Text(user.userName),
              subtitle: Text(user.isAdmin ? 'Yönetici' : 'Üye'),
              trailing: Container(
                width: 40,
                alignment: Alignment.center,
                child: hasAdminRights && !user.isAdmin 
                  ? PlatformIconButton(
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        isIOS ? CupertinoIcons.delete : Icons.delete_outline,
                        color: isIOS ? CupertinoColors.destructiveRed : Colors.red,
                        size: 20,
                      ),
                      onPressed: () => _confirmRemoveUser(user),
                    )
                  : (user.isAdmin 
                    ? Icon(
                        isIOS ? CupertinoIcons.shield_fill : Icons.shield,
                        color: isIOS ? CupertinoColors.activeBlue : Colors.blue,
                        size: 20,
                      )
                    : SizedBox(width: 20)),
              ),
            ),
          )).toList(),
          const SizedBox(height: 20),
          PlatformElevatedButton(
            onPressed: _confirmLeaveGroup,
            color: isIOS ? CupertinoColors.destructiveRed : Colors.red,
            material: (_, __) => MaterialElevatedButtonData(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              child: Text(
                'Gruptan Ayrıl',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isIOS ? CupertinoColors.white : Colors.white,
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
  
  // Kullanıcı çıkarma onayı
  void _confirmRemoveUser(GroupUser user) {
    final isIOS = isCupertino(context);
    final String title = 'Kullanıcıyı Çıkar';
    final String content = '${user.userName} kullanıcısını gruptan çıkarmak istediğinize emin misiniz?';
    
    showPlatformDialog(
      context: context,
      builder: (dialogContext) => isIOS
        ? CupertinoAlertDialog(
            title: Text(title),
            content: Text(content),
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
          )
        : AlertDialog(
            title: Text(title),
            content: Text(content),
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
  
  Future<void> _removeUser(int userID) async {
    _safeSetState(() => _isLoading = true);
    
    try {
      final success = await Provider.of<GroupViewModel>(context, listen: false)
          .removeUserFromGroup(widget.groupId, userID);
      
      if (mounted) {
        if (success) {
          await _loadGroupDetail();
          _showSnackBar('Kullanıcı başarıyla çıkarıldı');
        } else {
          _safeSetState(() {
            _isLoading = false;
            _errorMessage = 'Kullanıcı çıkarılamadı.';
          });
          _showErrorSnackbar('Kullanıcı çıkarma işlemi başarısız oldu. Lütfen daha sonra tekrar deneyin.');
        }
      }
    } catch (e) {
      if (mounted) {
        _safeSetState(() {
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
                      1: Text('Yönetici'),
                      2: Text('Üye'),
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
                      ButtonSegment<int>(value: 1, label: Text('Yönetici')),
                      ButtonSegment<int>(value: 2, label: Text('Üye')),
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
    final roleText = role == 2 ? 'Yönetici' : 'Üye';
    
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
    final isIOS = isCupertino(context);
    
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
                    isIOS ? CupertinoIcons.add_circled : Icons.add_circle_outline,
                    color: isIOS ? CupertinoColors.activeBlue : Colors.blue,
                    size: 22,
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
                      isIOS ? CupertinoIcons.folder : Icons.folder_outlined,
                      size: 48,
                      color: isIOS ? CupertinoColors.systemGrey : Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Henüz proje bulunmuyor',
                      style: TextStyle(
                        color: isIOS ? CupertinoColors.systemGrey : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ...group.projects.map((project) => Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: (isIOS ? CupertinoColors.activeBlue : Colors.blue).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Icon(
                    isIOS ? CupertinoIcons.folder_fill : Icons.folder,
                    color: isIOS ? CupertinoColors.activeBlue : Colors.blue,
                    size: 20,
                  ),
                ),
              ),
              title: Text(project.projectName),
              trailing: Container(
                width: 60,
                alignment: Alignment.centerRight,
                child: hasAdminRights 
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PlatformIconButton(
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            isIOS ? CupertinoIcons.delete : Icons.delete_outline,
                            color: isIOS ? CupertinoColors.systemRed : Colors.red,
                            size: 20,
                          ),
                          onPressed: () => _confirmDeleteProject(project.projectID),
                        ),
                        Icon(
                          isIOS ? CupertinoIcons.chevron_right : Icons.chevron_right,
                          size: 16,
                        ),
                      ],
                    )
                  : Icon(
                      isIOS ? CupertinoIcons.chevron_right : Icons.chevron_right,
                      size: 16,
                    ),
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
      _showSnackBar('Proje başarıyla oluşturuldu');
    }
  }
  
  Widget _buildEventsTab(BuildContext context) {
    final group = _groupDetail!;
    final isIOS = isCupertino(context);
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Etkinlikler (${group.events.length})',
                style: platformThemeData(
                  context,
                  material: (data) => data.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  cupertino: (data) => data.textTheme.navTitleTextStyle,
                ),
              ),
              PlatformIconButton(
                padding: EdgeInsets.zero,
                icon: Icon(
                  isIOS ? CupertinoIcons.add_circled : Icons.add_circle_outline,
                  color: isIOS ? CupertinoColors.activeBlue : Colors.blue,
                  size: 22,
                ),
                onPressed: _navigateToCreateEventView,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (group.events.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32.0),
                child: Column(
                  children: [
                    Icon(
                      isIOS ? CupertinoIcons.calendar : Icons.event_note_outlined,
                      size: 48,
                      color: isIOS ? CupertinoColors.systemGrey : Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Henüz etkinlik bulunmuyor',
                      style: TextStyle(
                        color: isIOS ? CupertinoColors.systemGrey : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 16),
                    PlatformElevatedButton(
                      onPressed: _navigateToCreateEventView,
                      child: const Text('Etkinlik Ekle'),
                    ),
                  ],
                ),
              ),
            ),
          ...group.events.map((event) => Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: GestureDetector(
              onTap: () => _navigateToEventDetail(event),
              child: Card(
                elevation: isIOS ? 0 : 1,
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
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: (isIOS ? CupertinoColors.systemOrange : Colors.orange).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              isIOS ? CupertinoIcons.calendar : Icons.event_note,
                              color: isIOS ? CupertinoColors.systemOrange : Colors.orange,
                              size: 16,
                            ),
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
                            color: isIOS ? CupertinoColors.secondaryLabel : Colors.grey[700],
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isIOS ? CupertinoIcons.time : Icons.access_time,
                                size: 14,
                                color: isIOS ? CupertinoColors.secondaryLabel : Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Tarih: ${event.eventDate}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isIOS ? CupertinoColors.secondaryLabel : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          Icon(
                            isIOS ? CupertinoIcons.chevron_right : Icons.arrow_forward_ios,
                            size: 16,
                            color: isIOS ? CupertinoColors.secondaryLabel : Colors.grey[600],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )).toList(),
        ],
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


  // Log öğesi
  Widget _buildLogItem(BuildContext context, GroupLog log) {
    final isIOS = isCupertino(context);
    
    // Log tipine göre ikon ve renk belirle
    IconData logIcon;
    Color logColor;
    
    if (log.logName.contains('Tamamlandı')) {
      logIcon = isIOS ? CupertinoIcons.checkmark_circle_fill : Icons.check_circle;
      logColor = isIOS ? CupertinoColors.activeGreen : Colors.green;
    } else if (log.logName.contains('Tamamlanmadı')) {
      logIcon = isIOS ? CupertinoIcons.xmark_circle_fill : Icons.cancel;
      logColor = isIOS ? CupertinoColors.systemRed : Colors.red;
    } else if (log.logName.contains('Açıldı')) {
      logIcon = isIOS ? CupertinoIcons.add_circled_solid : Icons.add_circle;
      logColor = isIOS ? CupertinoColors.activeBlue : Colors.blue;
    } else {
      logIcon = isIOS ? CupertinoIcons.doc_text_fill : Icons.article;
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
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: logColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    logIcon,
                    color: logColor,
                    size: 16,
                  ),
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
            const SizedBox(height: 8),
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
                const SizedBox(width: 12),
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

 

  // Hata mesajı snackbar göster
  void _showErrorSnackbar(String message) {
    _showSnackBar(message, isError: true);
  }

  // SnackBar gösterim yardımcı metodu
  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted || _isDisposed) return;
    
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError 
              ? (isCupertino(context) ? CupertinoColors.systemRed : Colors.red)
              : null,
        ),
      );
    } catch (e) {
      _logger.e('ScaffoldMessenger hatası: $e');
    }
  }

  // Bölüm başlığı widget'ı
  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: platformThemeData(
        context,
        material: (data) => data.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        cupertino: (data) => data.textTheme.navTitleTextStyle,
      ),
    );
  }

  // Gruptan ayrılma onayı
  void _confirmLeaveGroup() {
    final isIOS = isCupertino(context);
    final String title = 'Gruptan Ayrıl';
    final String content = 'Bu gruptan ayrılmak istediğinize emin misiniz?';
    
    showPlatformDialog(
      context: context,
      builder: (dialogContext) => isIOS
        ? CupertinoAlertDialog(
            title: Text(title),
            content: Text(content),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('İptal'),
              ),
              CupertinoDialogAction(
                isDestructiveAction: true,
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _leaveGroup();
                },
                child: const Text('Ayrıl'),
              ),
            ],
          )
        : AlertDialog(
            title: Text(title),
            content: Text(content),
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
                  _leaveGroup();
                },
                child: const Text('Ayrıl'),
              ),
            ],
          ),
    );
  }

  // Gruptan ayrılma işlemi
  Future<void> _leaveGroup() async {
    // StorageService'den kullanıcı ID'sini al
    final storageService = StorageService();
    final userId = storageService.getUserId();
    
    if (userId == null) {
      _showErrorSnackbar('Kullanıcı bilgileriniz alınamadı. Lütfen tekrar giriş yapın.');
      return;
    }
    
    _safeSetState(() => _isLoading = true);
    
    try {
      // İşlemi başlatmadan önce sayfayı tamamen durdur
      _isDisposed = true;
      
      final success = await Provider.of<GroupViewModel>(context, listen: false)
          .removeUserFromGroup(widget.groupId, userId);
      
      // mounted kontrolü gerekiyor ama isDisposed kontrolü yapmıyoruz
      if (mounted) {
        if (success) {
          _showSnackBar('Gruptan başarıyla ayrıldınız');
          
          // Doğrudan ana sayfaya veya gruplar listesi sayfasına dön
          Navigator.of(context).popUntil((route) {
            final routeName = route.settings.name;
            // Ana sayfayı veya gruplar listesi sayfasını bul
            return route.isFirst || (routeName != null && routeName.contains('GroupsView'));
          });
        } else {
          // Başarısız olursa sayfaya geri dönüş yap, _isDisposed'u sıfırla
          _safeSetState(() {
            _isDisposed = false;
            _isLoading = false;
            _errorMessage = 'Gruptan ayrılma işlemi başarısız oldu.';
          });
          
          _showErrorSnackbar('Gruptan ayrılma işlemi başarısız oldu. Lütfen daha sonra tekrar deneyin.');
        }
      }
    } catch (e) {
      // Hata durumunda eğer hala mounted ise
      if (mounted) {
        // Başarısız olursa sayfaya geri dönüş yap, _isDisposed'u sıfırla
        _safeSetState(() {
          _isDisposed = false;
          _isLoading = false;
          _errorMessage = e.toString();
        });
        
        _showErrorSnackbar(_formatErrorMessage(e.toString()));
      }
    }
  }

  // Grup raporlarını yükle
  Future<void> _loadReports() async {
    _safeSetState(() {
      _isLoadingReports = true;
    });
    
    try {
      final reports = await _apiService.report.getGroupReports(widget.groupId);
      _safeSetState(() {
        _groupReports = reports;
        _isLoadingReports = false;
      });
      _logger.i('Grup raporları yüklendi: ${reports.length} adet');
    } catch (e) {
      _safeSetState(() {
        _isLoadingReports = false;
        _errorMessage = 'Raporlar yüklenemedi: $e';
      });
      _logger.e('Raporlar yüklenirken hata: $e');
    }
  }

  // Raporlar sekmesi
  Widget _buildReportsTab(BuildContext context) {
    final isIOS = isCupertino(context);
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Raporlar (${_groupReports.length})',
                style: platformThemeData(
                  context,
                  material: (data) => data.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  cupertino: (data) => data.textTheme.navTitleTextStyle,
                ),
              ),
              PlatformIconButton(
                padding: EdgeInsets.zero,
                icon: Icon(
                  isIOS ? CupertinoIcons.add_circled : Icons.add_circle_outline,
                  color: isIOS ? CupertinoColors.activeBlue : Colors.blue,
                  size: 22,
                ),
                onPressed: _createReport,
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          if (_isLoadingReports)
            Center(
              child: PlatformCircularProgressIndicator(),
            )
          else if (_groupReports.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32.0),
                child: Column(
                  children: [
                    Icon(
                      isIOS ? CupertinoIcons.doc_text : Icons.description_outlined,
                      size: 48,
                      color: isIOS ? CupertinoColors.systemGrey : Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Henüz rapor bulunmuyor',
                      style: TextStyle(
                        color: isIOS ? CupertinoColors.systemGrey : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 16),
                    PlatformElevatedButton(
                      onPressed: _createReport,
                      child: const Text('Rapor Ekle'),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _groupReports.length,
              itemBuilder: (context, index) {
                final report = _groupReports[index];
                return Card(
                  elevation: isIOS ? 0 : 1,
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: isIOS 
                      ? BorderSide(color: CupertinoColors.systemGrey5) 
                      : BorderSide.none,
                  ),
                  child: InkWell(
                    onTap: () => _navigateToReportDetail(report),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  image: report.userProfilePhoto.isNotEmpty
                                    ? DecorationImage(
                                        image: NetworkImage(report.userProfilePhoto),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                                  color: report.userProfilePhoto.isEmpty
                                    ? (isIOS ? CupertinoColors.systemIndigo : Colors.indigo).withOpacity(0.1)
                                    : null,
                                ),
                                child: report.userProfilePhoto.isEmpty
                                  ? Center(
                                      child: Text(
                                        report.userFullname.substring(0, 1).toUpperCase(),
                                        style: TextStyle(
                                          color: isIOS ? CupertinoColors.systemIndigo : Colors.indigo,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    )
                                  : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      report.reportTitle,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      report.userFullname,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: isIOS ? CupertinoColors.secondaryLabel : Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (report.reportDesc.isNotEmpty) ...[
                            Text(
                              report.reportDesc,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                color: isIOS ? CupertinoColors.label : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Rapor Tarihi: ${report.reportDate}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isIOS ? CupertinoColors.secondaryLabel : Colors.grey[600],
                                ),
                              ),
                              Icon(
                                isIOS ? CupertinoIcons.chevron_right : Icons.arrow_forward_ios,
                                size: 16,
                                color: isIOS ? CupertinoColors.secondaryLabel : Colors.grey[600],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // Rapor detayına gitme
  void _navigateToReportDetail(GroupReport report) {
    Navigator.of(context).push(
      platformPageRoute(
        context: context,
        builder: (context) => ChangeNotifierProvider(
          create: (context) => ReportViewModel(),
          child: ReportDetailView(
            reportId: report.reportID,
            groupId: widget.groupId,
          ),
        ),
      ),
    ).then((result) {
      if (result == true && mounted) {
        _loadReports(); // Raporları yenile
      }
    });
  }

  // Rapor oluşturma
  void _createReport() {
    if (_groupDetail == null) return;
    
    final reportTitleController = TextEditingController();
    final reportDescController = TextEditingController();
    final reportDateController = TextEditingController();
    final currentDate = DateTime.now();
    final formattedDate = '${currentDate.day}.${currentDate.month}.${currentDate.year}';
    reportDateController.text = formattedDate;
    
    int selectedProjectID = 0; // 0 = Gruba ait genel rapor
    final projectItems = [
      {'id': 0, 'name': 'Genel (Gruba ait)'},
      ..._groupDetail!.projects.map((p) => {'id': p.projectID, 'name': p.projectName}).toList(),
    ];
    
    final isIOS = isCupertino(context);
    
    if (isIOS) {
      showCupertinoDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) {
            return CupertinoAlertDialog(
              title: const Text('Rapor Oluştur'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  CupertinoTextField(
                    controller: reportTitleController,
                    placeholder: 'Rapor Başlığı',
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: CupertinoColors.systemGrey4),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  const SizedBox(height: 10),
                  CupertinoTextField(
                    controller: reportDateController,
                    placeholder: 'Rapor Tarihi (GG.AA.YYYY)',
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: CupertinoColors.systemGrey4),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: CupertinoColors.systemGrey4),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            projectItems.firstWhere((p) => p['id'] == selectedProjectID)['name'] as String,
                            style: const TextStyle(color: CupertinoColors.label),
                          ),
                          const Icon(CupertinoIcons.chevron_down),
                        ],
                      ),
                      onPressed: () {
                        showCupertinoModalPopup(
                          context: context,
                          builder: (context) => CupertinoActionSheet(
                            title: const Text('Proje Seç'),
                            actions: projectItems.map((project) => 
                              CupertinoActionSheetAction(
                                onPressed: () {
                                  setState(() {
                                    selectedProjectID = project['id'] as int;
                                  });
                                  Navigator.pop(context);
                                },
                                child: Text(project['name'] as String),
                              )
                            ).toList(),
                            cancelButton: CupertinoActionSheetAction(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('İptal'),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  CupertinoTextField(
                    controller: reportDescController,
                    placeholder: 'Rapor İçeriği...',
                    padding: const EdgeInsets.all(12),
                    minLines: 5,
                    maxLines: 10,
                    decoration: BoxDecoration(
                      border: Border.all(color: CupertinoColors.systemGrey4),
                      borderRadius: BorderRadius.circular(5),
                    ),
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
                    final title = reportTitleController.text.trim();
                    final desc = reportDescController.text.trim();
                    final date = reportDateController.text.trim();
                    
                    if (title.isEmpty) {
                      _showErrorSnackbar('Rapor başlığı boş bırakılamaz');
                      return;
                    }
                    
                    if (desc.isEmpty) {
                      _showErrorSnackbar('Rapor içeriği boş bırakılamaz');
                      return;
                    }
                    
                    Navigator.pop(context);
                    
                    await _submitReport(
                      title: title,
                      desc: desc,
                      date: date,
                      projectID: selectedProjectID,
                    );
                  },
                  child: const Text('Oluştur'),
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
              title: const Text('Rapor Oluştur'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: reportTitleController,
                      decoration: const InputDecoration(
                        labelText: 'Rapor Başlığı',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: reportDateController,
                      decoration: const InputDecoration(
                        labelText: 'Rapor Tarihi (GG.AA.YYYY)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                      decoration: const InputDecoration(
                        labelText: 'Proje',
                        border: OutlineInputBorder(),
                      ),
                      value: selectedProjectID,
                      items: projectItems.map((project) => 
                        DropdownMenuItem(
                          value: project['id'] as int,
                          child: Text(project['name'] as String),
                        )
                      ).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            selectedProjectID = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: reportDescController,
                      decoration: const InputDecoration(
                        labelText: 'Rapor İçeriği',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      minLines: 5,
                      maxLines: 10,
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
                    final title = reportTitleController.text.trim();
                    final desc = reportDescController.text.trim();
                    final date = reportDateController.text.trim();
                    
                    if (title.isEmpty) {
                      _showErrorSnackbar('Rapor başlığı boş bırakılamaz');
                      return;
                    }
                    
                    if (desc.isEmpty) {
                      _showErrorSnackbar('Rapor içeriği boş bırakılamaz');
                      return;
                    }
                    
                    Navigator.pop(context);
                    
                    await _submitReport(
                      title: title,
                      desc: desc,
                      date: date,
                      projectID: selectedProjectID,
                    );
                  },
                  child: const Text('Oluştur'),
                ),
              ],
            );
          },
        ),
      );
    }
  }

  // Rapor gönderme işlemi
  Future<void> _submitReport({
    required String title, 
    required String desc, 
    required String date,
    required int projectID,
  }) async {
    _safeSetState(() => _isLoading = true);
    
    try {
      final success = await _apiService.report.createReport(
        groupID: widget.groupId,
        projectID: projectID,
        reportTitle: title, 
        reportDesc: desc,
        reportDate: date,
      );
      
      if (success) {
        // Raporları yenile
        await _loadReports();
        _showSnackBar('Rapor başarıyla oluşturuldu');
      } else {
        _showErrorSnackbar('Rapor oluşturulamadı');
      }
      
      _safeSetState(() => _isLoading = false);
    } catch (e) {
      _safeSetState(() {
        _isLoading = false;
        _errorMessage = 'Rapor oluşturulurken hata: $e';
      });
      _showErrorSnackbar(_formatErrorMessage(e.toString()));
    }
  }
} 