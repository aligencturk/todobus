import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:provider/provider.dart';
import 'package:todobus/viewmodels/profile_viewmodel.dart';
import 'dart:io' show Platform;
import 'dart:math' as math;
import '../services/storage_service.dart';
import '../services/logger_service.dart';
import '../services/snackbar_service.dart';
import '../services/user_service.dart';
import '../services/notification_service.dart';
import '../services/version_check_service.dart';
import '../services/ai_assistant_service.dart';
import '../viewmodels/group_viewmodel.dart';
import '../viewmodels/dashboard_viewmodel.dart';
import '../viewmodels/event_viewmodel.dart';
import '../models/group_models.dart';
import '../widgets/ai_chat_widget.dart';
import '../main_app.dart';
import 'login_view.dart';
import 'profile_view.dart';
import 'group_detail_view.dart';
import 'project_detail_view.dart';
import 'work_detail_view.dart';
import 'event_detail_view.dart';
import 'notifications_view.dart';

// Dashboard widget'ları için enum tanımı
enum DashboardWidgetType {
  welcomeSection,
  infoCards,
  recentGroups,
  projects,
  upcomingEvents,
  myTasks,
}

// Dashboard widget'larının görüntü adları
Map<DashboardWidgetType, String> dashboardWidgetNames = {
  DashboardWidgetType.welcomeSection: 'Karşılama Bölümü',
  DashboardWidgetType.infoCards: 'Bilgi Kartları',
  DashboardWidgetType.recentGroups: 'Son Aktif Gruplar',
  DashboardWidgetType.projects: 'Projelerim',
  DashboardWidgetType.upcomingEvents: 'Yaklaşan Etkinlikler',
  DashboardWidgetType.myTasks: 'Görevlerim',
};

class DashboardView extends StatefulWidget {
  const DashboardView({Key? key}) : super(key: key);

  @override
  _DashboardViewState createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> with TickerProviderStateMixin {
  final StorageService _storageService = StorageService();
  final LoggerService _logger = LoggerService();
  final SnackBarService _snackBarService = SnackBarService();
  final UserService _userService = UserService();
  final NotificationService _notificationService = NotificationService.instance;
  final VersionCheckService _versionCheckService = VersionCheckService();
  final AIAssistantService _aiAssistantService = AIAssistantService.instance;
  
  List<GroupLog> _recentLogs = [];
  bool _isLoadingLogs = false;
  int _unreadNotifications = 0;
  
  List<Map<String, dynamic>> _userProjects = [];
  
  // Tamamlanan görevlerin animasyonlu çıkış için geçici listesi ve animasyon kontrolleri
  Map<int, _TaskCompletionAnimationState> _completingTasksMap = {};
  final Duration _taskCompletionAnimationDuration = const Duration(milliseconds: 800);
  
  // Konfeti parçacıkları için rastgele renkler
  final List<Color> _confettiColors = [
    Colors.red, 
    Colors.blue, 
    Colors.green, 
    Colors.yellow, 
    Colors.purple, 
    Colors.orange,
    Colors.teal,
    Colors.pink
  ];
  
  // Dashboard widget'larının sırası
  List<DashboardWidgetType> _widgetOrder = [];
  // Varsayılan widget sırası
  final List<DashboardWidgetType> _defaultWidgetOrder = [
    DashboardWidgetType.welcomeSection,
    DashboardWidgetType.infoCards,
    DashboardWidgetType.recentGroups,
    DashboardWidgetType.projects,
    DashboardWidgetType.upcomingEvents,
    DashboardWidgetType.myTasks,
  ];

  @override
  void initState() {
    super.initState();
    
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        final dashboardViewModel = Provider.of<DashboardViewModel>(context, listen: false);
        final groupViewModel = Provider.of<GroupViewModel>(context, listen: false);
        final profileViewModel = Provider.of<ProfileViewModel>(context, listen: false);
        final eventViewModel = Provider.of<EventViewModel>(context, listen: false);
        
        // Kullanıcı arayüzünü hızlıca render etmek için boş durumla güncelle
        if (mounted) {
          setState(() {});
        }

        // Widget sırasını yükle
        await _loadWidgetOrder();

        // Tüm veri yüklemelerini paralel olarak başlat
        final userFuture = _loadUserData(profileViewModel);
        final statusesFuture = groupViewModel.getProjectStatuses();
        final eventsFuture = eventViewModel.loadEvents();
        final dashboardFuture = dashboardViewModel.loadDashboardData();
        final groupsFuture = groupViewModel.loadGroups();
        final notificationsFuture = _checkNotifications();
        
        // Statuses'i bekleyen groupsFuture dışında paralel çalıştır
        await Future.wait([
          userFuture,
          statusesFuture,
          eventsFuture,
          dashboardFuture,
          notificationsFuture
        ]);
        
        // Kullanıcı verilerine bağlı işlemler
        if (mounted && profileViewModel.user != null) {
          // FCM topic'leri için işlemi arka planda yap, UI'ı bloklama
          _notificationService.subscribeToUserTopic(profileViewModel.user!.userID)
            .then((_) {
              if (mounted) {
                _logger.i('Kullanıcı FCM topic\'ine abone edildi: ${profileViewModel.user!.userID}');
              }
            })
            .catchError((e) {
              if (mounted) {
                _logger.e('FCM topic abone işleminde hata: $e');
              }
            });
        }
        
        // Version check'i arka planda çalıştır - mounted kontrolü ile
        if (mounted) {
          _versionCheckService.checkForUpdates(context).catchError((e) {
            if (mounted) {
              _logger.e('Version check hatası: $e');
            }
          });
        }
        
        // Grup verilerini bekle
        await groupsFuture;
        
        if (mounted) {
          // Gruplar yüklendikten sonra projeleri yükle ve UI'ı güncelle
          _loadUserProjects(groupViewModel);
          
          // AI Assistant'a kullanıcı verilerini gönder
          _updateAIAssistantData(profileViewModel, groupViewModel, dashboardViewModel);
          
          // FCM topic aboneliklerini arka planda işle
          if (profileViewModel.user != null) {
            final groups = groupViewModel.groups;
            final groupIds = groups.map((group) => group.groupID).toList();
            
            // Kullanıcıyı kendi topic'ine abone et
            _notificationService.subscribeToUserTopic(profileViewModel.user!.userID).then((success) {
              if (mounted && success) {
                _logger.i('Kullanıcı FCM topic\'ine abone edildi');
              }
            }).catchError((e) {
              if (mounted) {
                _logger.e('FCM topic aboneliğinde hata: $e');
              }
            });
            

          }
          
          _logger.i('Dashboard açıldı: Tüm veriler yüklendi');
        }
      }
    });
  }

  @override
  void dispose() {
    // Tüm aktif animasyonları temizle
    for (final animState in _completingTasksMap.values) {
      animState.dispose();
    }
    _completingTasksMap.clear();
    super.dispose();
  }
  
  // Widget sırasını yükleme
  Future<void> _loadWidgetOrder() async {
    final order = await _storageService.getDashboardWidgetOrder();
    if (order.isNotEmpty) {
      setState(() {
        _widgetOrder = order;
      });
      _logger.i('Widget sırası yüklendi: ${order.map((e) => e.toString()).join(', ')}');
    } else {
      setState(() {
        _widgetOrder = List.from(_defaultWidgetOrder);
      });
      _logger.i('Varsayılan widget sırası kullanılıyor');
    }
  }
  
  // Widget sırasını kaydetme
  Future<void> _saveWidgetOrder() async {
    await _storageService.saveDashboardWidgetOrder(_widgetOrder);
    _logger.i('Widget sırası kaydedildi: ${_widgetOrder.map((e) => e.toString()).join(', ')}');
  }
  
  // Widget sırasını değiştirme (ayarlar ekranından çağrılır)
  void _changeWidgetOrder(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final item = _widgetOrder.removeAt(oldIndex);
      _widgetOrder.insert(newIndex, item);
    });
    _saveWidgetOrder();
  }
  
  // Widget sırasını sıfırlama
  void _resetWidgetOrder() {
    setState(() {
      _widgetOrder = List.from(_defaultWidgetOrder);
    });
    _saveWidgetOrder();
    _snackBarService.showSuccess('Widget sırası sıfırlandı');
  }
  
  // Widget sırasını düzenleme ekranını göster
  void _showWidgetOrderingScreen() {
    final bool isIOS = Platform.isIOS;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: isIOS ? CupertinoColors.systemBackground : Theme.of(context).colorScheme.background,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Widget Sıralaması',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isIOS ? CupertinoTheme.of(context).textTheme.textStyle.color : Theme.of(context).textTheme.titleLarge?.color,
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      _resetWidgetOrder();
                      if (mounted) {
                        Navigator.pop(context);
                      }
                    },
                    child: Text(
                      'Sıfırla',
                      style: TextStyle(
                        color: isIOS ? CupertinoColors.destructiveRed : Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Ana sayfada görünen widget\'ların sırasını değiştirmek için aşağıdaki öğeleri sürükleyip bırakın.',
                style: TextStyle(
                  fontSize: 14,
                  color: isIOS ? CupertinoColors.secondaryLabel : Colors.grey[600],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ReorderableListView.builder(
                itemCount: _widgetOrder.length,
                onReorder: (oldIndex, newIndex) {
                  _changeWidgetOrder(oldIndex, newIndex);
                },
                itemBuilder: (context, index) {
                  final widgetType = _widgetOrder[index];
                  final widgetName = dashboardWidgetNames[widgetType] ?? 'Bilinmeyen Widget';
                  
                  return Container(
                    key: ValueKey(widgetType),
                    margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                    decoration: BoxDecoration(
                      color: isIOS ? CupertinoColors.tertiarySystemBackground : Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isIOS ? CupertinoColors.separator : Colors.grey[300]!,
                        width: 0.5,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      leading: Icon(
                        _getIconForWidgetType(widgetType),
                        color: isIOS ? CupertinoColors.activeBlue : Theme.of(context).primaryColor,
                      ),
                      title: Text(
                        widgetName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: isIOS ? CupertinoTheme.of(context).textTheme.textStyle.color : Theme.of(context).textTheme.titleMedium?.color,
                        ),
                      ),
                      trailing: Icon(
                        isIOS ? CupertinoIcons.line_horizontal_3 : Icons.drag_handle,
                        color: isIOS ? CupertinoColors.secondaryLabel : Colors.grey[600],
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: PlatformElevatedButton(
                onPressed: () {
                  if (mounted) {
                    Navigator.pop(context);
                  }
                },
                child: const Text('Tamam'),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Widget türüne göre ikon döndürme
  IconData _getIconForWidgetType(DashboardWidgetType type) {
    final bool isIOS = Platform.isIOS;
    
    switch (type) {
      case DashboardWidgetType.welcomeSection:
        return isIOS ? CupertinoIcons.person_crop_circle : Icons.person;
      case DashboardWidgetType.infoCards:
        return isIOS ? CupertinoIcons.square_grid_2x2 : Icons.dashboard;
      case DashboardWidgetType.recentGroups:
        return isIOS ? CupertinoIcons.group : Icons.group;
      case DashboardWidgetType.projects:
        return isIOS ? CupertinoIcons.square_stack_3d_down_right : Icons.folder;
      case DashboardWidgetType.upcomingEvents:
        return isIOS ? CupertinoIcons.calendar : Icons.event;
      case DashboardWidgetType.myTasks:
        return isIOS ? CupertinoIcons.square_list : Icons.task;
    }
  }
  
  // AI Assistant'a kullanıcı verilerini güncelle
  void _updateAIAssistantData(
    ProfileViewModel profileViewModel, 
    GroupViewModel groupViewModel, 
    DashboardViewModel dashboardViewModel
  ) {
    try {
      _aiAssistantService.updateUserData(
        user: profileViewModel.user,
        groups: groupViewModel.groups,
        tasks: dashboardViewModel.userTasks,
        projects: _userProjects,
      );
      _logger.i('AI Assistant kullanıcı verileri güncellendi');
    } catch (e) {
      _logger.e('AI Assistant veri güncelleme hatası: $e');
    }
  }

  // Kullanıcı verilerini yükleme
  Future<void> _loadUserData(ProfileViewModel profileViewModel) async {
    try {
      _logger.i('Kullanıcı bilgileri yükleniyor...');
      final userResponse = await _userService.getUser();
      if (mounted && userResponse.success && userResponse.data != null) {
        profileViewModel.setUser(userResponse.data!.user);
        _logger.i('Kullanıcı bilgileri başarıyla yüklendi');
      } else if (mounted) {
        _logger.e('Kullanıcı bilgileri yüklenemedi: ${userResponse.errorMessage}');
      }
    } catch (e) {
      if (mounted) {
        _logger.e('Kullanıcı bilgileri alınırken hata: $e');
      }
    }
  }
  
  // Bildirimleri kontrol et - daha hızlı ve optimize edilmiş
  Future<void> _checkNotifications() async {
    try {
      await _notificationService.fetchNotifications();
      if (mounted) {
        setState(() {
          _unreadNotifications = _notificationService.unreadCount;
        });
      }
    } catch (e) {
      if (mounted) {
        _logger.e('Bildirimler yüklenirken hata: $e');
      }
    }
  }

  Future<void> _logout() async {
    await _storageService.clearUserData();
    _logger.i('Kullanıcı çıkış yaptı');
    
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        platformPageRoute(
          context: context,
          builder: (context) => const LoginView(),
        ),
        (Route<dynamic> route) => false,
      );
    }
  }

  void _goToProfile() {
    if (mounted) {
      Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (context) => const ProfileView(),
        ),
      );
    }
  }

  // AI Assistant'ı göster
  void _showAIAssistant() {
    if (!mounted) return;
    
    // Kullanıcı verilerini AI Assistant'a güncelle
    final profileViewModel = Provider.of<ProfileViewModel>(context, listen: false);
    final groupViewModel = Provider.of<GroupViewModel>(context, listen: false);
    final dashboardViewModel = Provider.of<DashboardViewModel>(context, listen: false);
    
    _updateAIAssistantData(profileViewModel, groupViewModel, dashboardViewModel);
    
    // Chat ekranını tam sayfa olarak göster
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => const AIChatWidget(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupViewModel = Provider.of<GroupViewModel>(context);
    final dashboardViewModel = Provider.of<DashboardViewModel>(context);
    final eventViewModel = Provider.of<EventViewModel>(context);
    final bool isIOS = Platform.isIOS;

    return PlatformScaffold(
      backgroundColor: isIOS ? CupertinoColors.systemGroupedBackground : Theme.of(context).colorScheme.background,
      appBar: PlatformAppBar(
        title: const Text('Ana Sayfa'),
        material: (_, __) => MaterialAppBarData(
          leading: IconButton(
            onPressed: _showWidgetOrderingScreen,
            icon: Icon(
              Icons.sort,
              color: Theme.of(context).colorScheme.onSecondary,
            ),
            tooltip: 'Widget Düzeni',
          ),
          actions: <Widget>[
            IconButton(
              icon: Stack(
                children: [
                  const Icon(Icons.notifications),
                  if (_unreadNotifications > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(1),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 12,
                          minHeight: 12,
                        ),
                        child: Text(
                          _unreadNotifications > 9 ? '9+' : _unreadNotifications.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              onPressed: () {
                if (mounted) {
                  Navigator.of(context).push(
                    CupertinoPageRoute(
                      builder: (context) => const NotificationsView(),
                    ),
                  ).then((_) {
                    if (mounted) {
                      _checkNotifications();
                    }
                  });
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.person_outline),
              onPressed: _goToProfile,
            ),
          ],
        ),
        cupertino: (_, __) => CupertinoNavigationBarData(
          backgroundColor: CupertinoColors.systemGroupedBackground.withAlpha(200),
          border: null,
          leading: GestureDetector(
            onTap: _showWidgetOrderingScreen,
            child: Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    CupertinoIcons.slider_horizontal_3,
                    size: 18,
                    color: CupertinoColors.activeBlue,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Düzen',
                    style: TextStyle(
                      fontSize: 11,
                      color: CupertinoColors.activeBlue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CupertinoButton(
                padding: EdgeInsets.zero,
                child: Stack(
                  children: [
                    const Icon(CupertinoIcons.bell, size: 24),
                    if (_unreadNotifications > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(1),
                          decoration: BoxDecoration(
                            color: CupertinoColors.destructiveRed,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 12,
                            minHeight: 12,
                          ),
                          child: Text(
                            _unreadNotifications > 9 ? '9+' : _unreadNotifications.toString(),
                            style: const TextStyle(
                              color: CupertinoColors.white,
                              fontSize: 8,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                onPressed: () {
                  if (mounted) {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (context) => const NotificationsView(),
                      ),
                    ).then((_) {
                      if (mounted) {
                        _checkNotifications();
                      }
                    });
                  }
                },
              ),
              const SizedBox(width: 8),
              CupertinoButton(
                padding: EdgeInsets.zero,
                child: const Icon(CupertinoIcons.person_circle, size: 26),
                onPressed: _goToProfile,
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            _buildDashboardBody(dashboardViewModel, groupViewModel, eventViewModel, isIOS),
            // AI Assistant Floating Action Button
            Positioned(
              bottom: 100,
              right: 16,
              child: FloatingActionButton(
                onPressed: _showAIAssistant,
                backgroundColor: isIOS ? CupertinoColors.activeBlue : Theme.of(context).primaryColor,
                child: Icon(
                  isIOS ? CupertinoIcons.chat_bubble_2 : Icons.smart_toy,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Dashboard ana içeriğini oluşturma - performans için ayrı metot
  Widget _buildDashboardBody(
    DashboardViewModel dashboardViewModel, 
    GroupViewModel groupViewModel, 
    EventViewModel eventViewModel,
    bool isIOS
  ) {
    final scrollView = CustomScrollView(
      slivers: [
        if (isIOS)
          CupertinoSliverRefreshControl(
            onRefresh: _refreshData,
          ),
        
        // Widget'ları sıraya göre oluştur
        ..._buildWidgetsInOrder(dashboardViewModel, groupViewModel, eventViewModel),
        
        const SliverToBoxAdapter(
          child: SizedBox(height: 90),
        ),
      ]
    );

    // Android için RefreshIndicator kullan
    if (isIOS) {
      return scrollView;
    } else {
      return RefreshIndicator(
        onRefresh: _refreshData,
        child: scrollView,
      );
    }
  }
  
  // Widget'ları belirlenen sıraya göre oluşturma
  List<Widget> _buildWidgetsInOrder(
    DashboardViewModel dashboardViewModel, 
    GroupViewModel groupViewModel, 
    EventViewModel eventViewModel
  ) {
    final List<Widget> widgets = [];
    
    // Widget sırası boşsa varsayılan sırayı kullan
    final order = _widgetOrder.isEmpty ? _defaultWidgetOrder : _widgetOrder;
    
    for (final widgetType in order) {
      switch (widgetType) {
        case DashboardWidgetType.welcomeSection:
          widgets.add(
            SliverToBoxAdapter(
              child: _buildWelcomeSection(),
            ),
          );
          break;
          
        case DashboardWidgetType.infoCards:
          widgets.add(
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10.0,
                  mainAxisSpacing: 10.0,
                  childAspectRatio: 2.0,
                ),
                delegate: SliverChildListDelegate([
                  _buildInfoCard(
                    context,
                    title: 'Bekleyen Görevler' ,
                    value: '${dashboardViewModel.incompletedTaskCount}',
                    icon: CupertinoIcons.tray_arrow_up_fill,
                    color: CupertinoColors.systemIndigo,
                  ),
                  _buildInfoCard(
                    context,
                    title: 'Gruplar',
                    value: '${groupViewModel.groups.length}',
                    icon: CupertinoIcons.group,
                    color: CupertinoColors.activeGreen,
                  ),
                  _buildInfoCard(
                    context,
                    title: 'Projeler',
                    value: '${groupViewModel.totalProjects}',
                    icon: CupertinoIcons.square_stack_3d_down_right,
                    color: CupertinoColors.systemOrange,
                  ),
                  _buildInfoCard(
                    context,
                    title: 'Etkinlikler',
                    value: '${eventViewModel.events.length}',
                    icon: CupertinoIcons.calendar_badge_plus,
                    color: CupertinoColors.systemPurple,
                  ),
                ]),
              ),
            ),
          );
          break;
          
        case DashboardWidgetType.recentGroups:
          widgets.add(_buildSectionHeader('Son Aktif Gruplar'));
          widgets.add(
            SliverToBoxAdapter(
              child: _buildRecentGroupsList(dashboardViewModel.isLoading),
            ),
          );
          break;
          
        case DashboardWidgetType.projects:
          widgets.add(_buildSectionHeader('Projelerim'));
          widgets.add(
            SliverToBoxAdapter(
              child: _buildProjectsList(dashboardViewModel.isLoading),
            ),
          );
          break;
          
        case DashboardWidgetType.upcomingEvents:
          widgets.add(_buildSectionHeader('Yaklaşan Etkinlikler', onViewAll: () {
            final parentContext = context;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && Navigator.of(parentContext).canPop()) {
                Navigator.of(parentContext).pop();
              }
              if (mounted && parentContext.findAncestorStateOfType<MainAppState>() != null) {
                parentContext.findAncestorStateOfType<MainAppState>()!.setCurrentIndex(2);
              }
            });
          }));
          widgets.add(_buildEventsList(eventViewModel));
          break;
          
        case DashboardWidgetType.myTasks:
          widgets.add(_buildSectionHeader('Görevlerim'));
          widgets.add(_buildMyTasksSection());
          break;
      }
    }
    
    return widgets;
  }
  
  Widget _buildWelcomeSection() {
    final profileViewModel = Provider.of<ProfileViewModel>(context);
    final userName = profileViewModel.user?.userFirstname;
    final bool isIOS = Platform.isIOS;
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Merhaba, $userName',
            style: isIOS 
                ? CupertinoTheme.of(context).textTheme.navLargeTitleTextStyle.copyWith(fontSize: 26, fontWeight: FontWeight.bold)
                : Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Bugün yapılacaklar ve genel durumun.',
            style: isIOS
                ? CupertinoTheme.of(context).textTheme.textStyle.copyWith(color: CupertinoColors.secondaryLabel, fontSize: 15)
                : Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final bool isIOS = Platform.isIOS;
    final cardColor = isIOS 
        ? (CupertinoTheme.of(context).brightness == Brightness.light ? CupertinoColors.white : CupertinoColors.darkBackgroundGray)
        : Theme.of(context).cardColor;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: isIOS ? Border.all(color: CupertinoColors.separator.withOpacity(0.2), width: 0.5) : null,
        boxShadow: isIOS 
          ? [
              BoxShadow(
                color: color.withOpacity(0.1),
                blurRadius: 12,
                spreadRadius: -2,
                offset: const Offset(0, 4),
              )
            ]
          : [
              BoxShadow(
                color: color.withOpacity(0.08),
                blurRadius: 10,
                spreadRadius: -2,
                offset: const Offset(0, 3),
              )
            ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 22,
                color: color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: (isIOS 
                      ? CupertinoTheme.of(context).textTheme.navTitleTextStyle.copyWith(fontWeight: FontWeight.w600, color: CupertinoTheme.of(context).textTheme.textStyle.color) 
                      : Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)
                    )?.copyWith(fontSize: 18),
                  ),
                  Text(
                    title,
                    style: isIOS
                      ? CupertinoTheme.of(context).textTheme.tabLabelTextStyle.copyWith(color: CupertinoColors.secondaryLabel, fontSize: 12)
                      : Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildRecentGroupsList(bool isLoadingOverall) {
    final groupViewModel = Provider.of<GroupViewModel>(context);
    
    if (isLoadingOverall && groupViewModel.groups.isEmpty) {
        return SizedBox(height: 130, child: Center(child: CupertinoActivityIndicator()));
    }
    if (groupViewModel.groups.isEmpty) {
      return const SizedBox.shrink();
    }
    
    // Sadece ilk 7 grubu göster - performans optimizasyonu için liste kopyası yapmadan
    final int groupCount = groupViewModel.groups.length;
    final int displayCount = groupCount > 7 ? 7 : groupCount;
    
    return SizedBox(
      height: 120,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        scrollDirection: Axis.horizontal,
        itemCount: displayCount,
        itemBuilder: (context, index) {
          final group = groupViewModel.groups[index];
          return _buildGroupCard(group);
        },
      ),
    );
  }
  
  Widget _buildGroupCard(Group group) {
    final bool isIOS = Platform.isIOS;
    
    Color baseColor;
    IconData groupIconData;
    
    if (group.isAdmin) {
      groupIconData = isIOS ? CupertinoIcons.shield_lefthalf_fill : Icons.admin_panel_settings;
      baseColor = isIOS ? CupertinoColors.activeBlue : Colors.blue;
    } else if (!group.isFree) {
      groupIconData = isIOS ? CupertinoIcons.star_circle_fill : Icons.star;
      baseColor = isIOS ? CupertinoColors.systemOrange : Colors.orange;
    } else {
      groupIconData = isIOS ? CupertinoIcons.group : Icons.group;
      baseColor = isIOS ? CupertinoColors.activeGreen : Colors.green;
    }
    
    final cardBackgroundColor = isIOS 
        ? (CupertinoTheme.of(context).brightness == Brightness.light ? CupertinoColors.white : CupertinoColors.tertiarySystemBackground)
        : Theme.of(context).cardColor;

    return GestureDetector(
      onTap: () {
        if (mounted) {
          Navigator.of(context).push(
            CupertinoPageRoute(builder: (context) => GroupDetailView(groupId: group.groupID)),
          );
        }
      },
      child: Container(
        width: 110,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: cardBackgroundColor,
          borderRadius: BorderRadius.circular(10),
          border: isIOS ? Border.all(color: CupertinoColors.separator.withOpacity(0.2), width: 0.5) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: baseColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                groupIconData,
                color: baseColor,
                size: 22,
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                group.groupName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: (isIOS 
                  ? CupertinoTheme.of(context).textTheme.textStyle.copyWith(fontWeight: FontWeight.w600, fontSize: 12)
                  : Theme.of(context).textTheme.titleSmall
                )?.copyWith(fontSize: 12.5),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${group.projects.length} Proje',
              style: TextStyle(
                fontSize: 10,
                color: isIOS ? CupertinoColors.secondaryLabel : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }
 
  Widget _buildLogItem(BuildContext context, GroupLog log) {
    final bool isIOS = Platform.isIOS;
    
    IconData logIconData;
    Color logIconColor;
    
    if (log.logName.contains('Tamamlandı')) {
      logIconData = isIOS ? CupertinoIcons.checkmark_seal_fill : Icons.check_circle;
      logIconColor = isIOS ? CupertinoColors.activeGreen : Colors.green;
    } else if (log.logName.contains('Tamamlanmadı')) {
      logIconData = isIOS ? CupertinoIcons.xmark_seal_fill : Icons.cancel;
      logIconColor = isIOS ? CupertinoColors.systemRed : Colors.red;
    } else if (log.logName.contains('Açıldı')) {
      logIconData = isIOS ? CupertinoIcons.add_circled_solid : Icons.add_circle;
      logIconColor = isIOS ? CupertinoColors.activeBlue : Colors.blue;
    } else {
      logIconData = isIOS ? CupertinoIcons.doc_text : Icons.article;
      logIconColor = isIOS ? CupertinoColors.systemGrey : Colors.grey;
    }

    final cardBackgroundColor = isIOS 
      ? (CupertinoTheme.of(context).brightness == Brightness.light ? CupertinoColors.white : CupertinoColors.tertiarySystemBackground)
      : Theme.of(context).cardColor;

    return GestureDetector(
      onTap: () {
        if (mounted) {
          Navigator.of(context).push(
            CupertinoPageRoute(builder: (context) => GroupDetailView(groupId: log.groupID)),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: cardBackgroundColor,
          borderRadius: BorderRadius.circular(10),
          border: isIOS ? Border.all(color: CupertinoColors.separator.withOpacity(0.3), width: 0.5) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: logIconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(logIconData, color: logIconColor, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    log.logName,
                    style: (isIOS 
                        ? CupertinoTheme.of(context).textTheme.textStyle.copyWith(fontWeight: FontWeight.w600, color: logIconColor, fontSize: 14)
                        : Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: logIconColor)
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  log.createDate,
                  style: (isIOS 
                      ? CupertinoTheme.of(context).textTheme.tabLabelTextStyle.copyWith(fontSize: 11)
                      : Theme.of(context).textTheme.bodySmall
                  )?.copyWith(color: CupertinoColors.secondaryLabel, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Padding(
              padding: EdgeInsets.only(left: 28 + 10.0 - 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if(log.logDesc.isNotEmpty)
                  Text(
                    log.logDesc,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: (isIOS 
                        ? CupertinoTheme.of(context).textTheme.pickerTextStyle.copyWith(fontSize: 13) 
                        : Theme.of(context).textTheme.bodySmall
                    )?.copyWith(color: CupertinoTheme.of(context).textTheme.textStyle.color, fontSize: 13),
                  ),
                  if(log.logDesc.isNotEmpty) const SizedBox(height: 6),
                  Row(
                    children: [
                      _buildLogInfoChip(
                        context,
                        icon: isIOS ? CupertinoIcons.folder : Icons.folder_open,
                        text: 'Proje: ${log.projectID}',
                      ),
                      const SizedBox(width: 8),
                      _buildLogInfoChip(
                        context,
                        icon: isIOS ? CupertinoIcons.doc_on_clipboard : Icons.assignment,
                        text: 'Görev: ${log.workID}',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogInfoChip(BuildContext context, {required IconData icon, required String text}) {
    final bool isIOS = Platform.isIOS;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: isIOS 
          ? CupertinoColors.systemGrey5 
          : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 11,
            color: isIOS ? CupertinoColors.secondaryLabel : Colors.grey[600],
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              color: isIOS ? CupertinoColors.secondaryLabel : Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({required IconData icon, required String message, VoidCallback? onRetry, String retryText = 'Yenile'}) {
    final bool isIOS = Platform.isIOS;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 30.0, horizontal: 20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 48,
              color: isIOS ? CupertinoColors.systemGrey2 : Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: (isIOS 
                  ? CupertinoTheme.of(context).textTheme.textStyle.copyWith(fontSize: 15)
                  : Theme.of(context).textTheme.bodyMedium
              )?.copyWith(color: CupertinoColors.secondaryLabel, fontSize: 15),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              CupertinoButton(
                color: isIOS ? CupertinoColors.activeBlue : Theme.of(context).primaryColor,
                onPressed: onRetry,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(isIOS ? CupertinoIcons.refresh : Icons.refresh, size: 16, color: CupertinoColors.white),
                    const SizedBox(width: 8),
                    Text(retryText, style: TextStyle(color: CupertinoColors.white)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }


  Widget _buildProjectsList(bool isLoadingOverall) {
    final groupViewModel = Provider.of<GroupViewModel>(context, listen: false);
    
    // Eğer gruplar henüz yüklenmediyse veya genel yükleme devam ediyorsa loading göster
    if ((isLoadingOverall && _userProjects.isEmpty) || groupViewModel.groups.isEmpty) {
        return SizedBox(height: 120, child: Center(child: CupertinoActivityIndicator()));
    }
    if (_userProjects.isEmpty) {
      return const SizedBox.shrink();
    }
    
    // Sadece ilk 7 projeyi göster - performans optimizasyonu için liste kopyası yapmadan
    final int projectCount = _userProjects.length;
    final int displayCount = projectCount > 7 ? 7 : projectCount;

    return SizedBox(
      height: 120,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        scrollDirection: Axis.horizontal,
        itemCount: displayCount,
        itemBuilder: (context, index) {
          final project = _userProjects[index];
          return _buildProjectCard(project);
        },
      ),
    );
  }
  
  Widget _buildProjectCard(Map<String, dynamic> project) {
    final bool isIOS = Platform.isIOS;
    final groupViewModel = Provider.of<GroupViewModel>(context, listen: false);
    final LoggerService _projectLogger = LoggerService();
    
    Color baseColor;
    IconData projectIconData;
    String statusText;
    
    // API'den yüklenen proje durumlarını kontrol et
    final statuses = groupViewModel.cachedProjectStatuses;
    
    // Status ID'sine göre varsayılan değerler ata (API'den bulunamazsa kullanılır)
    switch (project['projectStatusID'] as int) {
      case 1:
        baseColor = isIOS ? CupertinoColors.systemBlue : Colors.blue;
        projectIconData = isIOS ? CupertinoIcons.plus_app : Icons.add_box;
        statusText = 'Yeni';
        break;
      case 2:
        baseColor = isIOS ? CupertinoColors.systemOrange : Colors.orange;
        projectIconData = isIOS ? CupertinoIcons.arrow_right_circle : Icons.play_circle_outline;
        statusText = 'Devam';
        break;
      case 3:
        baseColor = isIOS ? CupertinoColors.systemGreen : Colors.green;
        projectIconData = isIOS ? CupertinoIcons.checkmark_seal : Icons.check_box;
        statusText = 'Bitti';
        break;
      case 4:
        baseColor = isIOS ? CupertinoColors.systemRed : Colors.red;
        projectIconData = isIOS ? CupertinoIcons.xmark_circle : Icons.cancel;
        statusText = 'İptal';
        break;
      case 5:
        baseColor = isIOS ? CupertinoColors.systemGrey : Colors.grey;
        projectIconData = isIOS ? CupertinoIcons.time : Icons.hourglass_empty;
        statusText = 'Bekliyor';
        break;
      default:
        baseColor = isIOS ? CupertinoColors.systemBlue : Colors.blue;
        projectIconData = isIOS ? CupertinoIcons.doc_plaintext : Icons.description;
        statusText = 'Bilinmiyor';
        break;
    }

    // API'den durumlar yüklendiyse, statuses içinde ilgili durum var mı kontrol et 
    if (statuses.isNotEmpty) {
      // İlgili durumu ara
      final matchingStatus = statuses.where((s) => s.statusID == (project['projectStatusID'] as int)).toList();
      if (matchingStatus.isNotEmpty) {
        // Durumun renk ve adını API'den kullan
        final status = matchingStatus.first;
        baseColor = _hexToColor(status.statusColor);
        statusText = status.statusName;
        _projectLogger.i('Proje ${project['projectName']} için API durumu bulundu: ${status.statusName}, Color: ${status.statusColor}');
      } else {
        _projectLogger.w('Proje ${project['projectName']} (ID: ${project['projectStatusID']}) için uygun durum bulunamadı. Varsayılan değer kullanılıyor.');
      }
    } else {
      _projectLogger.w('API proje durumları yüklenmemiş. Varsayılan değerler kullanılıyor.');
    }

    final cardBackgroundColor = isIOS 
        ? (CupertinoTheme.of(context).brightness == Brightness.light ? CupertinoColors.white : CupertinoColors.tertiarySystemBackground)
        : Theme.of(context).cardColor;
    
    return GestureDetector(
      onTap: () {
        if (mounted) {
          Navigator.of(context).push(
            CupertinoPageRoute(
              builder: (context) => ProjectDetailView(
                projectId: project['projectID'] as int,
                groupId: project['groupID'] as int,
              ),
            ),
          );
        }
      },
      child: Container(
        width: 110,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: cardBackgroundColor,
          borderRadius: BorderRadius.circular(10),
          border: isIOS ? Border.all(color: CupertinoColors.separator.withOpacity(0.2), width: 0.5) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: baseColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                projectIconData,
                color: baseColor,
                size: 22,
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                project['projectName'] as String,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: (isIOS 
                  ? CupertinoTheme.of(context).textTheme.textStyle.copyWith(fontWeight: FontWeight.w600, fontSize: 12)
                  : Theme.of(context).textTheme.titleSmall
                )?.copyWith(fontSize: 12.5),
              ),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: baseColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                statusText,
                style: TextStyle(
                  fontSize: 9,
                  color: baseColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Hex renk kodunu Color nesnesine çevirme
  Color _hexToColor(String hexColor) {
    hexColor = hexColor.replaceAll('#', '');
    if (hexColor.length == 6) {
      hexColor = 'FF' + hexColor;
    }
    return Color(int.parse(hexColor, radix: 16));
  }

  Widget _buildMyTasksSection() {
    final dashboardViewModel = Provider.of<DashboardViewModel>(context);
    
    // Sadece tamamlanmamış görevleri filtrele - performans optimizasyonu için burada
    final hasIncompleteTasks = dashboardViewModel.userTasks.any((task) => !task.workCompleted);
    final incompleteTasks = hasIncompleteTasks ? dashboardViewModel.userTasks
        .where((task) => !task.workCompleted)
        .take(5) // Sadece ilk 5 görev - performans için
        .toList() : [];
    
    if (dashboardViewModel.isLoadingTasks && incompleteTasks.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Center(child: CupertinoActivityIndicator()),
        ),
      );
    }
    
    if (!dashboardViewModel.isLoadingTasks && incompleteTasks.isEmpty) {
      return SliverToBoxAdapter(
        child: _buildEmptyState(
          icon: CupertinoIcons.square_list,
          message: 'Tamamlanmamış göreviniz bulunmuyor.',
        ),
      );
    }
    
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final task = incompleteTasks[index];
            return _buildWorkItem(task);
          },
          childCount: incompleteTasks.length,
        ),
      ),
    );
  }
  
  Widget _buildWorkItem(UserProjectWork task) {
    final bool isIOS = Platform.isIOS;
    final bool isCompleted = task.workCompleted;
    final bool isCompleting = _completingTasksMap.containsKey(task.workID);
    
    // Biraz daha hızlı render için renk hesaplamalarını optimize edelim
    final cardBackgroundColor = isIOS 
      ? (CupertinoTheme.of(context).brightness == Brightness.light ? CupertinoColors.white : CupertinoColors.tertiarySystemBackground)
      : Theme.of(context).cardColor;
    
    final statusColor = isCompleted 
        ? (isIOS ? CupertinoColors.systemGreen : Colors.green)
        : (isIOS ? CupertinoColors.systemGrey2 : Colors.grey);
    
    final _TaskCompletionAnimationState? animationState = isCompleting ? _completingTasksMap[task.workID] : null;
    
    // Animasyon durumu varsa animasyonlu göster
    if (isCompleting && animationState != null) {
      return _buildAnimatedTaskItem(task, animationState, statusColor, isIOS, isCompleted, cardBackgroundColor);
    }

    // Normal görünüm
    return GestureDetector(
      onTap: () {
        if (mounted) {
          Navigator.of(context).push(
            CupertinoPageRoute(
              builder: (context) => WorkDetailView(
                projectId: task.projectID,
                groupId: 0, // Burada grup ID'si yok, arayüzde işlevsiz kalabilir
                workId: task.workID,
              ),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10.0),
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
        decoration: BoxDecoration(
          color: cardBackgroundColor,
          borderRadius: BorderRadius.circular(10.0),
          border: isIOS ? Border.all(color: CupertinoColors.separator.withOpacity(0.3), width: 0.5) : null,
        ),
        child: _buildTaskContent(task, statusColor, isIOS, isCompleted),
      ),
    );
  }
  
  // Animasyonlu görev öğesi oluşturma - performans için ayrı metot
  Widget _buildAnimatedTaskItem(
    UserProjectWork task, 
    _TaskCompletionAnimationState animationState,
    Color statusColor,
    bool isIOS,
    bool isCompleted,
    Color cardBackgroundColor
  ) {
    return Stack(
      children: [
        // Ana görev kartı
        SlideTransition(
          position: animationState.slideAnimation,
          child: ScaleTransition(
            scale: animationState.scaleAnimation,
            child: RotationTransition(
              turns: animationState.rotateAnimation,
              child: GestureDetector(
                onTap: () {
                  if (mounted) {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (context) => WorkDetailView(
                          projectId: task.projectID,
                          groupId: 0,
                          workId: task.workID,
                        ),
                      ),
                    );
                  }
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10.0),
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                  decoration: BoxDecoration(
                    color: cardBackgroundColor,
                    borderRadius: BorderRadius.circular(10.0),
                    border: isIOS ? Border.all(color: CupertinoColors.separator.withOpacity(0.3), width: 0.5) : null,
                  ),
                  child: _buildTaskContent(task, statusColor, isIOS, isCompleted),
                ),
              ),
            ),
          ),
        ),
        
        // Konfeti efekti
        ...List.generate(animationState.confettiAnimations.length, (index) {
          // Her bir parçacık için rastgele pozisyon ve renk
          final randomOffsetX = 40.0 + (index * 20.0);
          final randomOffsetY = -20.0 - (index * 5.0);
          final randomColor = _confettiColors[math.Random().nextInt(_confettiColors.length)];
          final size = 5.0 + (index % 3) * 3.0;
          
          return Positioned(
            right: randomOffsetX,
            top: 25 + randomOffsetY,
            child: AnimatedBuilder(
              animation: animationState.confettiAnimations[index],
              builder: (context, child) {
                final value = animationState.confettiAnimations[index].value;
                final opacity = 1.0 - value * 0.5; // Yavaşça kaybolur
                
                return Transform.translate(
                  offset: Offset(
                    -100 * value, // Sola doğru hareket
                    50 * value + 20 * math.sin(value * math.pi * 2), // Parabol yörünge
                  ),
                  child: Transform.rotate(
                    angle: value * math.pi * 2 * (index % 2 == 0 ? 1 : -1), // Dönme efekti
                    child: Opacity(
                      opacity: opacity,
                      child: Container(
                        width: size,
                        height: size,
                        decoration: BoxDecoration(
                          color: randomColor,
                          shape: index % 2 == 0 ? BoxShape.circle : BoxShape.rectangle,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        }),
      ],
    );
  }

  Widget _buildTaskContent(UserProjectWork task, Color statusColor, bool isIOS, bool isCompleted) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () => _toggleTaskCompletion(task),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: statusColor, width: 1.5),
              color: isCompleted ? statusColor.withOpacity(0.2) : Colors.transparent,
            ),
            padding: const EdgeInsets.all(2),
            child: isCompleted 
              ? Icon(CupertinoIcons.checkmark, size: 14, color: statusColor)
              : SizedBox(width: 14, height: 14),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                task.workName,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                  decoration: isCompleted ? TextDecoration.lineThrough : null,
                  color: isCompleted 
                    ? (isIOS ? CupertinoColors.secondaryLabel : Colors.grey[600])
                    : (isIOS ? CupertinoTheme.of(context).textTheme.textStyle.color : Colors.black87),
                ),
                 maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (task.workDesc.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  task.workDesc,
                  style: TextStyle(
                    fontSize: 13,
                    color: isIOS ? CupertinoColors.tertiaryLabel : Colors.grey[500],
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 5),
              Row(
                children: [
                  Icon(
                    isIOS ? CupertinoIcons.calendar_today : Icons.calendar_today,
                    size: 11,
                    color: CupertinoColors.tertiaryLabel,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    task.workEndDate,
                    style: TextStyle(fontSize: 11, color: CupertinoColors.tertiaryLabel),
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    isIOS ? CupertinoIcons.folder_fill : Icons.folder,
                    size: 11,
                    color: CupertinoColors.tertiaryLabel,
                  ),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(
                      task.projectName,
                      style: TextStyle(fontSize: 11, color: CupertinoColors.tertiaryLabel),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _toggleTaskCompletion(UserProjectWork task) async {
    if (!mounted) return;
    
    _logger.i("Görev tamamlama durumu değiştiriliyor: ${task.workName}");
    
    // Eğer görev tamamlanıyorsa ve henüz animasyon listesinde değilse, animasyon listesine ekle
    if (!task.workCompleted && mounted) {
      final animState = _TaskCompletionAnimationState(this, task.workID);
      setState(() {
        _completingTasksMap[task.workID] = animState;
      });
      
      // Animasyonları başlat
      animState.startAnimations();
    }
    
    if (!mounted) return;
    
    final groupViewModel = Provider.of<GroupViewModel>(context, listen: false);
    final dashboardViewModel = Provider.of<DashboardViewModel>(context, listen: false);
    
    try {
      final success = await groupViewModel.changeWorkCompletionStatus(
        task.projectID,
        task.workID,
        !task.workCompleted, // Mevcut durumun tersini gönder
      );
      
      if (mounted) {
        if (success) {
          // Animasyon tamamlanana kadar bekle
          await Future.delayed(_taskCompletionAnimationDuration);
          
          // Animasyon durumunu temizle ve kaynakları serbest bırak
          if (mounted && _completingTasksMap.containsKey(task.workID)) {
            _completingTasksMap[task.workID]?.dispose();
            setState(() {
              _completingTasksMap.remove(task.workID);
            });
          }
          
          // Dashboard verilerini yenile
          if (mounted) {
            await dashboardViewModel.loadUserTasks();
            
            _showTaskStatusMessage(
              !task.workCompleted ? 'Görev tamamlandı olarak işaretlendi' : 'Görev tamamlanmadı olarak işaretlendi',
              isError: false
            );
          }
        } else {
          // Eğer başarısız olursa, animasyon durumunu temizle
          if (_completingTasksMap.containsKey(task.workID)) {
            _completingTasksMap[task.workID]?.dispose();
            setState(() {
              _completingTasksMap.remove(task.workID);
            });
          }
          _showTaskStatusMessage('Görev durumu değiştirilemedi', isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        _logger.e('Görev durumu değiştirilirken hata: $e');
        // Hata durumunda animasyon durumunu temizle
        if (_completingTasksMap.containsKey(task.workID)) {
          _completingTasksMap[task.workID]?.dispose();
          setState(() {
            _completingTasksMap.remove(task.workID);
          });
        }
        _showTaskStatusMessage('Hata: ${e.toString()}', isError: true);
      }
    }
  }

  void _showTaskStatusMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    
    final isIOS = Platform.isIOS;
    
    if (isIOS) {
      // iOS için CupertinoDialog kullanımı - Scaffold bağımlılığını ortadan kaldırır
      if (mounted) {
        showCupertinoDialog(
          context: context,
          barrierDismissible: true,
          builder: (BuildContext context) {
            return CupertinoAlertDialog(
              content: Text(message),
              actions: [
                CupertinoDialogAction(
                  onPressed: () {
                    if (mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  isDefaultAction: true,
                  child: const Text('Tamam'),
                ),
              ],
            );
          },
        );
      }
      
      // Otomatik kapanma için Timer kullanımı
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && Navigator.canPop(context)) {
          Navigator.of(context).pop();
        }
      });
    } else {
      try {
        // SnackBarService kullanımı - doğrudan context'e bağlı değil
        if (isError) {
          _snackBarService.showError(message);
        } else {
          _snackBarService.showSuccess(message);
        }
      } catch (e) {
        // Fallback olarak basit bir dialog gösterimi
        _logger.e('SnackBar gösterilirken hata: $e');
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: true,
            builder: (BuildContext dialogContext) {
              return AlertDialog(
                content: Text(message),
                actions: [
                  TextButton(
                    onPressed: () {
                      if (mounted) {
                        Navigator.of(dialogContext).pop();
                      }
                    },
                    child: const Text('Tamam'),
                  ),
                ],
              );
            },
          );
        }
      }
    }
  }

  void _loadUserProjects(GroupViewModel groupViewModel) {
    if (!mounted) return;
    
    // Grupların yüklendiğinden emin ol
    if (groupViewModel.groups.isEmpty) {
      _logger.w('Gruplar henüz yüklenmemiş, projeler yüklenemiyor');
      return;
    }
    
    // Optimize edilmiş verimli proje listesi oluşturma
    final List<Map<String, dynamic>> allProjects = [];
    final groups = groupViewModel.groups;
    final int groupCount = groups.length;
    
    // Kapasiteyi önceden ayarlayarak bellek optimizasyonu sağlanıyor
    for (int i = 0; i < groupCount; i++) {
      final group = groups[i];
      final projects = group.projects;
      final int projectCount = projects.length;
      
      for (int j = 0; j < projectCount; j++) {
        final project = projects[j];
        allProjects.add({
          'projectID': project.projectID,
          'projectName': project.projectName,
          'projectStatusID': project.projectStatusID,
          'groupID': group.groupID,
          'groupName': group.groupName,
        });
      }
    }
    
    if (mounted) {
      setState(() {
        _userProjects = allProjects;
      });
      _logger.i('Projeler UI\'a yüklendi: ${allProjects.length} adet');
    }
      
    // Log ekleyelim - hangi durumlara sahip projeler yüklendiğini görelim
    if (allProjects.isNotEmpty) {
      _logger.i('Projeler ve durumları yüklendi: ${allProjects.length} adet');
      
      // Statuses içinde bu durumlar var mı kontrol edelim
      final statuses = groupViewModel.cachedProjectStatuses;
      if (statuses.isNotEmpty) {
        _logger.i('Mevcut durumlar: ${statuses.length} adet');
      }
    } else {
      _logger.w('Hiç proje bulunamadı. Grup sayısı: $groupCount');
    }
  }

  // Verileri yenileme - optimize edilmiş
  Future<void> _refreshData() async {
    if (!mounted) return;
    
    _logger.i('Veriler yenileniyor...');
    
    // Önceden önbellekten yüklenen verileri koruruz, yenileyiciyi çekerken yenisini alırız
    final dashboardViewModel = Provider.of<DashboardViewModel>(context, listen: false);
    final groupViewModel = Provider.of<GroupViewModel>(context, listen: false);
    final eventViewModel = Provider.of<EventViewModel>(context, listen: false);
    final profileViewModel = Provider.of<ProfileViewModel>(context, listen: false);
    
    try {
      // Tüm veri yüklemelerini paralel olarak başlat
      await Future.wait([
        groupViewModel.getProjectStatuses(),
        dashboardViewModel.loadDashboardData(),
        groupViewModel.loadGroups(),
        eventViewModel.loadEvents(),
        _loadUserData(profileViewModel),
        _checkNotifications(),
      ]);
      
      // Projeleri yükle - gruplar yüklendikten sonra
      if (mounted) {
        // Gruplar yüklendi mi kontrol et
        if (groupViewModel.groups.isNotEmpty) {
          _loadUserProjects(groupViewModel);
          // AI Assistant verilerini de güncelle
          _updateAIAssistantData(profileViewModel, groupViewModel, dashboardViewModel);
        } else {
          _logger.w('Refresh sırasında gruplar boş, projeler yüklenemedi');
        }
        _logger.i('Dashboard verileri yenilendi');
      }
    } catch (e) {
      if (mounted) {
        _logger.e('Veriler yenilenirken hata: $e');
        _snackBarService.showError('Veriler yenilenirken hata oluştu');
      }
    }
  }

  // Etkinlikler listesi - ayrı metot olarak optimize edildi
  Widget _buildEventsList(EventViewModel eventViewModel) {
    final bool isLoading = eventViewModel.isLoading;
    final events = eventViewModel.events;
    final bool isEmpty = events.isEmpty;
    final int displayCount = events.length > 5 ? 5 : events.length;
    
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      sliver: isLoading && isEmpty
        ? SliverToBoxAdapter(child: Center(child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: CupertinoActivityIndicator(),
          )))
        : isEmpty
          ? SliverToBoxAdapter(
              child: _buildEmptyState(
                icon: CupertinoIcons.calendar_badge_minus,
                message: 'Yaklaşan etkinlik bulunmuyor',
              ),
            )
          : SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final event = events[index];
                  return _buildEventItem(
                    context, 
                    title: event.eventTitle,
                    description: event.eventDesc,
                    date: event.eventDate,
                    user: event.userFullname,
                    groupId: event.groupID,
                  );
                },
                childCount: displayCount,
              ),
            ),
    );
  }
  
  Widget _buildSectionHeader(String title, {VoidCallback? onViewAll, VoidCallback? onRefresh}) {
    final bool isIOS = Platform.isIOS;
    final titleStyle = isIOS 
      ? CupertinoTheme.of(context).textTheme.navTitleTextStyle.copyWith(fontWeight: FontWeight.bold, fontSize: 20)
      : Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18, fontWeight: FontWeight.bold);

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 24.0, bottom: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: titleStyle),
            if (onViewAll != null)
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: onViewAll,
                child: Text(
                  'Tümü',
                  style: TextStyle(
                    color: isIOS ? CupertinoColors.activeBlue : Theme.of(context).primaryColor,
                    fontSize: 15,
                  ),
                ),
              )
            else if (onRefresh != null)
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: onRefresh,
                child: Icon(
                  isIOS ? CupertinoIcons.refresh : Icons.refresh,
                  size: 22,
                  color: isIOS ? CupertinoColors.activeBlue : Theme.of(context).primaryColor,
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildEventItem(
    BuildContext context, {
    required String title,
    required String description,
    required String date,
    required String user,
    required int groupId,
  }) {
    final bool isIOS = Platform.isIOS;
    final cardBackgroundColor = isIOS 
      ? (CupertinoTheme.of(context).brightness == Brightness.light ? CupertinoColors.white : CupertinoColors.tertiarySystemBackground)
      : Theme.of(context).cardColor;

    return GestureDetector(
      onTap: () {
        if (mounted) {
          Navigator.of(context).push(
            CupertinoPageRoute(
              builder: (context) => EventDetailPage(
                groupId: groupId,
                eventTitle: title,
                eventDescription: description,
                eventDate: date,
                eventUser: user,
              ),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10.0),
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: cardBackgroundColor,
          borderRadius: BorderRadius.circular(10.0),
          border: isIOS ? Border.all(color: CupertinoColors.separator.withOpacity(0.3), width: 0.5) : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (isIOS ? CupertinoColors.systemIndigo : Colors.indigo).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isIOS ? CupertinoIcons.calendar : Icons.event,
                color: isIOS ? CupertinoColors.systemIndigo : Colors.indigo,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: isIOS 
                        ? CupertinoTheme.of(context).textTheme.textStyle.copyWith(fontWeight: FontWeight.w600, fontSize: 15)
                        : Theme.of(context).textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      description,
                      style: (isIOS 
                          ? CupertinoTheme.of(context).textTheme.pickerTextStyle.copyWith(color: CupertinoColors.secondaryLabel, fontSize: 13)
                          : Theme.of(context).textTheme.bodySmall
                      )?.copyWith(color: CupertinoColors.secondaryLabel, fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        isIOS ? CupertinoIcons.person : Icons.person_outline,
                        size: 12,
                        color: CupertinoColors.tertiaryLabel,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        user,
                        style: (isIOS ? CupertinoTheme.of(context).textTheme.tabLabelTextStyle.copyWith(fontSize: 11) : Theme.of(context).textTheme.bodySmall)
                            ?.copyWith(color: CupertinoColors.tertiaryLabel, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (isIOS ? CupertinoColors.systemOrange : Colors.orange).withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                date,
                style: TextStyle(
                  color: isIOS ? CupertinoColors.systemOrange : Colors.orange,
                  fontWeight: FontWeight.w500,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}



// Görev tamamlama animasyonu için durum sınıfı
class _TaskCompletionAnimationState {
  late AnimationController slideController;
  late AnimationController scaleController;
  late AnimationController rotateController;
  late Animation<Offset> slideAnimation;
  late Animation<double> scaleAnimation;
  late Animation<double> rotateAnimation;
  
  final List<AnimationController> confettiControllers = [];
  final List<Animation<double>> confettiAnimations = [];
  
  bool isDisposed = false;
  
  _TaskCompletionAnimationState(TickerProvider vsync, int workId) {
    // Kaydırma animasyonu - sağa doğru kayar
    slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: vsync,
    );
    
    slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(1.5, 0),
    ).animate(CurvedAnimation(
      parent: slideController,
      curve: Curves.easeOutQuint,
    ));
    
    // Ölçek animasyonu - küçülür
    scaleController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: vsync,
    );
    
    scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: scaleController,
      curve: Curves.easeInQuint,
    ));
    
    // Döndürme animasyonu
    rotateController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: vsync,
    );
    
    rotateAnimation = Tween<double>(
      begin: 0.0,
      end: 0.1, // 10% dönüş
    ).animate(CurvedAnimation(
      parent: rotateController,
      curve: Curves.easeInOutBack,
    ));
    
    // Her bir konfeti parçası için animasyon kontrolleri oluştur
    for (int i = 0; i < 6; i++) {
      final controller = AnimationController(
        duration: Duration(milliseconds: 400 + (i * 100)), // farklı sürelerde
        vsync: vsync,
      );
      
      final animation = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: controller,
        curve: Curves.easeOutQuad,
      ));
      
      confettiControllers.add(controller);
      confettiAnimations.add(animation);
    }
  }
  
  // Tüm animasyonları başlat
  Future<void> startAnimations() async {
    rotateController.forward();
    await Future.delayed(const Duration(milliseconds: 100));
    slideController.forward();
    await Future.delayed(const Duration(milliseconds: 200));
    scaleController.forward();
    
    // Konfeti animasyonlarını aralıklı olarak başlat
    for (var controller in confettiControllers) {
      await Future.delayed(const Duration(milliseconds: 50));
      controller.forward();
    }
  }
  
  // Animasyonlar tamamlandı mı?
  bool get isCompleted => 
      slideController.isCompleted && 
      scaleController.isCompleted &&
      rotateController.isCompleted;
  
  // Tüm kaynakları temizle
  void dispose() {
    if (!isDisposed) {
      slideController.dispose();
      scaleController.dispose();
      rotateController.dispose();
      
      for (var controller in confettiControllers) {
        controller.dispose();
      }
      
      isDisposed = true;
    }
  }
} 