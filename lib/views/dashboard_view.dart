import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:provider/provider.dart';
import 'package:todobus/viewmodels/profile_viewmodel.dart';
import 'dart:io' show Platform;
import '../services/storage_service.dart';
import '../services/logger_service.dart';
import '../viewmodels/group_viewmodel.dart';
import '../viewmodels/dashboard_viewmodel.dart';
import '../models/group_models.dart';
import '../main_app.dart';
import 'login_view.dart';
import 'profile_view.dart';
import 'group_detail_view.dart';
import 'project_detail_view.dart';
import 'work_detail_view.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({Key? key}) : super(key: key);

  @override
  _DashboardViewState createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  final StorageService _storageService = StorageService();
  final LoggerService _logger = LoggerService();
  
  List<GroupLog> _recentLogs = [];
  bool _isLoadingLogs = false;
  
  
  List<ProjectPreviewItem> _userProjects = [];

  @override
  void initState() {
    super.initState();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final dashboardViewModel = Provider.of<DashboardViewModel>(context, listen: false);
        final groupViewModel = Provider.of<GroupViewModel>(context, listen: false);
        
        // Her seferinde tüm verileri yeniden yüklüyoruz, önbelleği kullanmıyoruz
        dashboardViewModel.loadDashboardData(forceRefresh: true);
        dashboardViewModel.loadUserTasks(forceRefresh: true);
        
        groupViewModel.loadGroups().then((_) {
          if (mounted) {
            _loadRecentLogs(groupViewModel);
            _loadUserProjects(groupViewModel);
            _logger.i('Gruplar yüklendi, loglar ve projeler istendi');
          }
        });
        
        _logger.i('Dashboard açıldı: Veriler yükleniyor...');
      }
    });
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    final dashboardViewModel = Provider.of<DashboardViewModel>(context, listen: false);
    // Kullanıcı her sayfaya eriştiğinde görevleri ve diğer verileri tazelemek için
    // Özellikle logout/login sonrası önbellek sorunlarını engellemek amacıyla
    dashboardViewModel.loadUserTasks(forceRefresh: true);
  }

  Future<void> _refreshData() async {
    final dashboardViewModel = Provider.of<DashboardViewModel>(context, listen: false);
    final groupViewModel = Provider.of<GroupViewModel>(context, listen: false);

    // Yenileme işleminde her zaman taze veri alıyoruz
    await dashboardViewModel.loadDashboardData(forceRefresh: true);
    await dashboardViewModel.loadUserTasks(forceRefresh: true);
    await groupViewModel.loadGroups();
    
    if (mounted) {
      await _loadRecentLogs(groupViewModel);
      _loadUserProjects(groupViewModel);
    }
  }

  Future<void> _logout() async {
    // Önce tüm önbelleği temizle
    await _storageService.clearAllCache();
    
    // Sonra kullanıcı oturum verilerini temizle
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
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => const ProfileView(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupViewModel = Provider.of<GroupViewModel>(context);
    final dashboardViewModel = Provider.of<DashboardViewModel>(context);

    return PlatformScaffold(
      backgroundColor: Platform.isIOS ? CupertinoColors.systemGroupedBackground : Theme.of(context).colorScheme.background,
      appBar: PlatformAppBar(
        title: const Text('Ana Sayfa'),
        material: (_, __) => MaterialAppBarData(
          actions: <Widget>[
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                // Arama işlevi
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
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CupertinoButton(
                padding: EdgeInsets.zero,
                child: const Icon(CupertinoIcons.search, size: 24),
                onPressed: () {
                  // Arama işlevi
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
        child: CustomScrollView(
          slivers: [
            if (Platform.isIOS)
              CupertinoSliverRefreshControl(
                onRefresh: _refreshData,
              )
            else
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10.0, bottom: 5.0),
                  child: Center(
                    child: PlatformIconButton(
                      icon: Icon(context.platformIcons.refresh),
                      onPressed: _refreshData,
                    ),
                  ),
                ),
              ),
            
            SliverToBoxAdapter(
              child: _buildWelcomeSection(),
            ),
            
            SliverToBoxAdapter(
              child: _buildUserQuickInfoCard(),
            ),
            
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12.0,
                  mainAxisSpacing: 12.0,
                  childAspectRatio: 1.3,
                ),
                delegate: SliverChildListDelegate([
                  _buildInfoCard(
                    context,
                    title: 'Görevler',
                    value: '${dashboardViewModel.taskCount}',
                    icon: CupertinoIcons.checkmark_shield,
                    color: CupertinoColors.activeBlue,
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
                    value: '${dashboardViewModel.upcomingEvents.length}',
                    icon: CupertinoIcons.calendar_badge_plus,
                    color: CupertinoColors.systemPurple,
                  ),
                ]),
              ),
            ),
            
            _buildSectionHeader('Son Aktif Gruplar', onViewAll: () {
              // Tüm gruplar sayfasına git
            }),
            SliverToBoxAdapter(
              child: _buildRecentGroupsList(dashboardViewModel.isLoading),
            ),
            
            _buildSectionHeader('Projelerim', onViewAll: () {
               // Tüm projeler sayfasına git
            }),
            SliverToBoxAdapter(
              child: _buildProjectsList(dashboardViewModel.isLoading),
            ),
            
            _buildSectionHeader('Yaklaşan Etkinlikler', onViewAll: () {
              final parentContext = context;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (Navigator.of(parentContext).canPop()) {
                  Navigator.of(parentContext).pop();
                }
                if (parentContext.findAncestorStateOfType<MainAppState>() != null) {
                  parentContext.findAncestorStateOfType<MainAppState>()!.setCurrentIndex(2);
                }
              });
            }),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              sliver: dashboardViewModel.isLoading && dashboardViewModel.upcomingEvents.isEmpty
                ? SliverToBoxAdapter(child: Center(child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: CupertinoActivityIndicator(),
                  )))
                : dashboardViewModel.upcomingEvents.isEmpty
                  ? SliverToBoxAdapter(
                      child: _buildEmptyState(
                        icon: CupertinoIcons.calendar_badge_minus,
                        message: 'Yaklaşan etkinlik bulunmuyor',
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final event = dashboardViewModel.upcomingEvents[index];
                          return _buildEventItem(
                            context, 
                            title: event.eventTitle,
                            description: event.eventDesc,
                            date: event.eventDate,
                            user: event.userFullname,
                            groupId: event.groupID,
                          );
                        },
                        childCount: dashboardViewModel.upcomingEvents.length,
                      ),
                    ),
            ),
            
            _buildSectionHeader('Görevlerim', onViewAll: () {
              // Tüm görevler sayfasına git
            }),
            _buildMyTasksSection(),
            
            _buildSectionHeader('Son Aktiviteler', onRefresh: () => _loadRecentLogs(groupViewModel)),
            _buildRecentActivities(),
            
            const SliverToBoxAdapter(
              child: SizedBox(height: 40),
            ),
          ]
        )
      )
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
  
  Widget _buildWelcomeSection() {
    final profileViewModel = Provider.of<ProfileViewModel>(context);
    final userName = profileViewModel.user?.userFullname;
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
        borderRadius: BorderRadius.circular(12),
        border: isIOS ? Border.all(color: CupertinoColors.separator.withOpacity(0.3), width: 0.5) : null,
        boxShadow: isIOS 
          ? [
              BoxShadow(
                color: CupertinoColors.systemGrey4.withOpacity(0.2),
                blurRadius: 10,
                spreadRadius: -2,
                offset: const Offset(0, 3),
              )
            ]
          : [
              BoxShadow(
                color: Colors.grey.withOpacity(0.15),
                blurRadius: 8,
                offset: const Offset(0, 2),
              )
            ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 26,
              color: color,
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: (isIOS 
                ? CupertinoTheme.of(context).textTheme.navTitleTextStyle.copyWith(fontWeight: FontWeight.w600, color: CupertinoTheme.of(context).textTheme.textStyle.color) 
                : Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)
              )?.copyWith(fontSize: 20),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: isIOS
                ? CupertinoTheme.of(context).textTheme.tabLabelTextStyle.copyWith(color: CupertinoColors.secondaryLabel, fontSize: 13)
                : Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
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
        Navigator.of(context).push(
          CupertinoPageRoute(builder: (context) => GroupDetailView(groupId: groupId)),
        );
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
  
  Widget _buildUserQuickInfoCard() {
    final dashboardViewModel = Provider.of<DashboardViewModel>(context);
    final bool isIOS = Platform.isIOS;
    final user = dashboardViewModel.user;
    
    if (user == null) {
      return const SizedBox.shrink();
    }
    
    final cardBackgroundColor = isIOS 
        ? (CupertinoTheme.of(context).brightness == Brightness.light ? CupertinoColors.white : CupertinoColors.darkBackgroundGray)
        : Theme.of(context).cardColor;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: GestureDetector(
        onTap: _goToProfile,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
          decoration: BoxDecoration(
            color: cardBackgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: isIOS ? Border.all(color: CupertinoColors.separator.withOpacity(0.3), width: 0.5) : null,
            boxShadow: isIOS ? [
              BoxShadow(
                color: CupertinoColors.systemGrey5.withOpacity(0.15),
                blurRadius: 8,
                offset: const Offset(0, 2),
              )
            ] : [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 6,
                offset: const Offset(0, 1),
              )
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: (isIOS ? CupertinoColors.activeBlue : Colors.blue).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isIOS ? CupertinoIcons.person_fill : Icons.person,
                  color: isIOS ? CupertinoColors.activeBlue : Colors.blue,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.userFullname,
                       style: isIOS 
                          ? CupertinoTheme.of(context).textTheme.textStyle.copyWith(fontWeight: FontWeight.w600, fontSize: 16)
                          : Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.userEmail,
                      style: (isIOS 
                          ? CupertinoTheme.of(context).textTheme.tabLabelTextStyle.copyWith(fontSize: 13)
                          : Theme.of(context).textTheme.bodySmall
                      )?.copyWith(color: CupertinoColors.secondaryLabel, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (isIOS ? CupertinoColors.systemIndigo : Colors.indigo).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  user.userRank,
                  style: TextStyle(
                    color: isIOS ? CupertinoColors.systemIndigo : Colors.indigo,
                    fontWeight: FontWeight.w500,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
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
    
    final recentGroups = groupViewModel.groups.length > 7
        ? groupViewModel.groups.sublist(0, 7) 
        : groupViewModel.groups;
    
    return SizedBox(
      height: 120,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        scrollDirection: Axis.horizontal,
        itemCount: recentGroups.length,
        itemBuilder: (context, index) {
          final group = recentGroups[index];
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
        Navigator.of(context).push(
          CupertinoPageRoute(builder: (context) => GroupDetailView(groupId: group.groupID)),
        );
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

  Future<void> _loadRecentLogs(GroupViewModel groupViewModel) async {
    if (_isLoadingLogs && _recentLogs.isNotEmpty) return;
    
    setState(() {
      _isLoadingLogs = true;
    });
    
    try {
      _logger.i('Son aktiviteler yükleniyor...');
      
      if (groupViewModel.groups.isEmpty) {
        await groupViewModel.loadGroups();
        if (groupViewModel.groups.isEmpty) {
          if (mounted) setState(() => _isLoadingLogs = false);
          return;
        }
      }
      
      int? targetGroupId;
      final adminGroups = groupViewModel.groups.where((group) => group.isAdmin).toList();
      if (adminGroups.isNotEmpty) {
        targetGroupId = adminGroups.first.groupID;
      } else {
        final premiumGroups = groupViewModel.groups.where((group) => !group.isFree).toList();
        if (premiumGroups.isNotEmpty) {
          targetGroupId = premiumGroups.first.groupID;
        } else if (groupViewModel.groups.isNotEmpty) {
          targetGroupId = groupViewModel.groups.first.groupID;
        }
      }
      
      if (targetGroupId != null) {
        final isAdmin = adminGroups.any((group) => group.groupID == targetGroupId);
        final logs = await groupViewModel.getGroupReports(targetGroupId, isAdmin);
        if (mounted) {
          setState(() {
            _recentLogs = logs;
            _isLoadingLogs = false;
          });
          _logger.i('${logs.length} adet log başarıyla yüklendi');
        }
      } else {
        if (mounted) {
          _logger.e('Hiçbir grup bulunamadı (log için)');
          setState(() {
             _recentLogs = [];
            _isLoadingLogs = false;
          });
        }
      }
    } catch (e) {
      _logger.e('Son aktiviteler yüklenirken hata: $e');
      if (mounted) {
        setState(() {
          _recentLogs = [];
          _isLoadingLogs = false;
        });
      }
    }
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
        Navigator.of(context).push(
          CupertinoPageRoute(builder: (context) => GroupDetailView(groupId: log.groupID)),
        );
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

  Widget _buildRecentActivities() {
    final groupViewModel = Provider.of<GroupViewModel>(context);
    
    if (_isLoadingLogs && _recentLogs.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Center(child: CupertinoActivityIndicator()),
        ),
      );
    }
    
    if (!_isLoadingLogs && _recentLogs.isEmpty) {
      return SliverToBoxAdapter(
        child: _buildEmptyState(
          icon: CupertinoIcons.doc_text_search,
          message: 'Henüz aktivite kaydı bulunmuyor.',
          onRetry: () => _loadRecentLogs(groupViewModel),
        ),
      );
    }
    
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildLogItem(context, _recentLogs[index]),
          childCount: _recentLogs.length > 5 ? 5 : _recentLogs.length,
        ),
      ),
    );
  }

  Widget _buildProjectsList(bool isLoadingOverall) {
        
    if (isLoadingOverall && _userProjects.isEmpty) {
        return SizedBox(height: 120, child: Center(child: CupertinoActivityIndicator()));
    }
    if (_userProjects.isEmpty) {
      return const SizedBox.shrink();
    }
    
    final displayedProjects = _userProjects.length > 7 ? _userProjects.sublist(0, 7) : _userProjects;

    return SizedBox(
      height: 120,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        scrollDirection: Axis.horizontal,
        itemCount: displayedProjects.length,
        itemBuilder: (context, index) {
          final project = displayedProjects[index];
          return _buildProjectCard(project);
        },
      ),
    );
  }
  
  Widget _buildProjectCard(ProjectPreviewItem project) {
    final bool isIOS = Platform.isIOS;
    
    Color baseColor;
    IconData projectIconData;
    String statusText;
    
    switch (project.projectStatusID) {
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

    final cardBackgroundColor = isIOS 
        ? (CupertinoTheme.of(context).brightness == Brightness.light ? CupertinoColors.white : CupertinoColors.tertiarySystemBackground)
        : Theme.of(context).cardColor;
    
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (context) => ProjectDetailView(
              projectId: project.projectID,
              groupId: project.groupID,
            ),
          ),
        );
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
                project.projectName,
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

  Widget _buildMyTasksSection() {
    final dashboardViewModel = Provider.of<DashboardViewModel>(context);
    
    if (dashboardViewModel.isLoadingTasks && dashboardViewModel.userTasks.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Center(child: CupertinoActivityIndicator()),
        ),
      );
    }
    
    if (!dashboardViewModel.isLoadingTasks && dashboardViewModel.userTasks.isEmpty) {
      return SliverToBoxAdapter(
        child: _buildEmptyState(
          icon: CupertinoIcons.square_list,
          message: dashboardViewModel.tasksErrorMessage.isNotEmpty 
              ? dashboardViewModel.tasksErrorMessage
              : 'Henüz atanmış göreviniz bulunmuyor.',
          onRetry: dashboardViewModel.tasksErrorMessage.isNotEmpty 
              ? () => dashboardViewModel.loadUserTasks()
              : null,
          retryText: 'Tekrar Dene',
        ),
      );
    }
    
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final task = dashboardViewModel.userTasks[index];
            return _buildWorkItem(task);
          },
          childCount: dashboardViewModel.userTasks.length > 5 ? 5 : dashboardViewModel.userTasks.length,
        ),
      ),
    );
  }
  
  Widget _buildWorkItem(UserProjectWork task) {
    final bool isIOS = Platform.isIOS;
    
    final cardBackgroundColor = isIOS 
      ? (CupertinoTheme.of(context).brightness == Brightness.light ? CupertinoColors.white : CupertinoColors.tertiarySystemBackground)
      : Theme.of(context).cardColor;

    final bool isCompleted = task.workCompleted;
    final Color statusColor = isCompleted 
        ? (isIOS ? CupertinoColors.systemGreen : Colors.green)
        : (isIOS ? CupertinoColors.systemGrey2 : Colors.grey);

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (context) => WorkDetailView(
              projectId: task.projectID,
              groupId: 0, // Burada grup ID'si yok, arayüzde işlevsiz kalabilir
              workId: task.workID,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10.0),
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
        decoration: BoxDecoration(
          color: cardBackgroundColor,
          borderRadius: BorderRadius.circular(10.0),
          border: isIOS ? Border.all(color: CupertinoColors.separator.withOpacity(0.3), width: 0.5) : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              minSize: 0,
              onPressed: () {
                _logger.i("Görev tamamlama durumu değiştirme istendi: ${task.workName}");
                // TODO: Implement task completion toggle logic here
                // e.g., context.read<GroupViewModel>().toggleTaskCompletion(...);
              },
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
        ),
      ),
    );
  }

  void _loadUserProjects(GroupViewModel groupViewModel) {
    List<ProjectPreviewItem> allProjects = [];
    
    for (final group in groupViewModel.groups) {
      for (final project in group.projects) {
        allProjects.add(
          ProjectPreviewItem(
            projectID: project.projectID,
            projectName: project.projectName,
            projectStatusID: project.projectStatusID,
            groupID: group.groupID,
            groupName: group.groupName,
          ),
        );
      }
    }
    
    if (mounted) {
        setState(() {
          _userProjects = allProjects;
        });
    }
  }
}

class ProjectPreviewItem {
  final int projectID;
  final String projectName;
  final int projectStatusID;
  final int groupID;
  final String groupName;
  
  ProjectPreviewItem({
    required this.projectID,
    required this.projectName,
    required this.projectStatusID,
    required this.groupID,
    required this.groupName,
  });
} 