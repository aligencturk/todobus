import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:provider/provider.dart';
import 'dart:io' show Platform;
import '../services/storage_service.dart';
import '../services/logger_service.dart';
import '../viewmodels/group_viewmodel.dart';
import '../viewmodels/dashboard_viewmodel.dart';
import '../models/group_models.dart';
import '../models/user_model.dart';
import 'login_view.dart';
import 'profile_view.dart';
import 'group_detail_view.dart';

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
  
  @override
  void initState() {
    super.initState();
    
    // Sayfa açıldığında verileri yükle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final dashboardViewModel = Provider.of<DashboardViewModel>(context, listen: false);
        final groupViewModel = Provider.of<GroupViewModel>(context, listen: false);
        
        // API'den kullanıcı ve dashboard verilerini yükle
        dashboardViewModel.loadDashboardData();
        
        // Önce grupları yükle, sonra logları getir
        groupViewModel.loadGroups().then((_) {
          if (mounted) {
            // Gruplar yüklendiyse son aktivite loglarını yükle
            _loadRecentLogs(groupViewModel);
            _logger.i('Gruplar yüklendi ve loglar istendi');
          }
        });
        
        _logger.i('Dashboard açıldı: Veriler yükleniyor...');
      }
    });
  }
  
  Future<void> _logout() async {
    await _storageService.clearUserData();
    _logger.i('Kullanıcı çıkış yaptı');
    
    if (mounted) {
      Navigator.of(context).pushReplacement(
        platformPageRoute(
          context: context,
          builder: (context) => const LoginView(),
        ),
      );
    }
  }

  void _goToProfile() {
    Navigator.of(context).push(
      platformPageRoute(
        context: context,
        builder: (context) => const ProfileView(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupViewModel = Provider.of<GroupViewModel>(context);
    final dashboardViewModel = Provider.of<DashboardViewModel>(context);
    final isIOS = isCupertino(context);
    
    // iOS tarzı yuvarlatılmış köşeli kartlar
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: const Text('Ana Sayfa'),
        material: (_, __) => MaterialAppBarData(
          actions: <Widget>[
            IconButton(
              icon: Icon(context.platformIcons.search),
              onPressed: () {
                // Arama işlevi buraya eklenecek
              },
            ),
          ],
        ),
        cupertino: (_, __) => CupertinoNavigationBarData(
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CupertinoButton(
                padding: EdgeInsets.zero,
                child: Icon(context.platformIcons.search),
                onPressed: () {
                  // Arama işlevi buraya eklenecek
                },
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                child: Icon(context.platformIcons.person),
                onPressed: _goToProfile,
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Platform'a göre farklı refresh kontrolü ekleyelim
            if (Platform.isIOS)
              CupertinoSliverRefreshControl(
                onRefresh: () async {
                  await dashboardViewModel.loadDashboardData();
                  await groupViewModel.loadGroups();
                  
                  // Refresh sırasında logları da yenile
                  await _loadRecentLogs(groupViewModel);
                },
              )
            else
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Center(
                    child: PlatformIconButton(
                      icon: Icon(context.platformIcons.refresh),
                      onPressed: () {
                        dashboardViewModel.loadDashboardData();
                        groupViewModel.loadGroups();
                        _loadRecentLogs(groupViewModel);
                      },
                    ),
                  ),
                ),
              ),
            // iOS tarzı kullanıcı selamlama bölümü
            SliverToBoxAdapter(
              child: _buildWelcomeSection(),
            ),
            
            // Kullanıcı Hızlı Bilgi Kartı
            SliverToBoxAdapter(
              child: _buildUserQuickInfoCard(),
            ),
            
            // Widget kartları
            SliverPadding(
              padding: const EdgeInsets.all(16.0),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16.0,
                  mainAxisSpacing: 16.0,
                  childAspectRatio: 1.2,
                ),
                delegate: SliverChildListDelegate([
                  _buildInfoCard(
                    context,
                    title: 'Görevler',
                    value: '${dashboardViewModel.taskCount}',
                    icon: isIOS ? CupertinoIcons.checkmark_circle : Icons.check_circle_outline,
                    color: isIOS ? CupertinoColors.activeBlue : Colors.blue,
                  ),
                  _buildInfoCard(
                    context,
                    title: 'Gruplar',
                    value: '${groupViewModel.groups.length}',
                    icon: isIOS ? CupertinoIcons.group : Icons.group,
                    color: isIOS ? CupertinoColors.activeGreen : Colors.green,
                  ),
                  _buildInfoCard(
                    context,
                    title: 'Projeler',
                    value: '${groupViewModel.totalProjects}',
                    icon: isIOS ? CupertinoIcons.collections : Icons.collections_bookmark,
                    color: isIOS ? CupertinoColors.systemOrange : Colors.orange,
                  ),
                  _buildInfoCard(
                    context,
                    title: 'Etkinlikler',
                    value: '${dashboardViewModel.upcomingEvents.length}',
                    icon: isIOS ? CupertinoIcons.time : Icons.access_time,
                    color: isIOS ? CupertinoColors.systemPurple : Colors.purple,
                  ),
                ]),
              ),
            ),
            
            // Son Aktif Gruplar
            SliverToBoxAdapter(
              child: _buildRecentGroupsList(),
            ),
            
            // Yaklaşan Etkinlikler Bölümü
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Yaklaşan Etkinlikler',
                  style: platformThemeData(
                    context,
                    material: (data) => data.textTheme.titleLarge?.copyWith(fontSize: 18),
                    cupertino: (data) => data.textTheme.navTitleTextStyle.copyWith(
                      fontSize: 18, 
                      fontWeight: FontWeight.bold
                    ),
                  ),
                ),
              ),
            ),
            
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              sliver: dashboardViewModel.upcomingEvents.isEmpty
                ? SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20.0),
                        child: Text(
                          'Yaklaşan etkinlik bulunmuyor',
                          style: platformThemeData(
                            context,
                            material: (data) => data.textTheme.bodyMedium?.copyWith(color: Colors.grey),
                            cupertino: (data) => data.textTheme.textStyle.copyWith(color: CupertinoColors.systemGrey),
                          ),
                        ),
                      ),
                    ),
                  )
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index < dashboardViewModel.upcomingEvents.length) {
                          final event = dashboardViewModel.upcomingEvents[index];
                          return _buildEventItem(
                            context, 
                            title: event.eventTitle,
                            description: event.eventDesc,
                            date: event.eventDate,
                            user: event.userFullname,
                            groupId: event.groupID,
                          );
                        }
                        return null;
                      },
                      childCount: dashboardViewModel.upcomingEvents.isEmpty ? 0 : dashboardViewModel.upcomingEvents.length,
                    ),
                  ),
            ),
            
            // Son Aktiviteler/Raporlar Bölümü
            SliverToBoxAdapter(
              child: _buildRecentActivities(),
            ),
            
            // Alt boşluk
            const SliverToBoxAdapter(
              child: SizedBox(height: 20),
            ),
          ]
        )
      )
    );
  }

  
 
  
  Widget _buildWelcomeSection() {
    final dashboardViewModel = Provider.of<DashboardViewModel>(context);
    final userName = dashboardViewModel.user?.userFullname ?? 'Kullanıcı';
    
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Merhaba, $userName',
            style: platformThemeData(
              context,
              material: (data) => data.textTheme.headlineSmall,
              cupertino: (data) => data.textTheme.navLargeTitleTextStyle.copyWith(fontSize: 28),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Bugün yapılacaklar',
            style: platformThemeData(
              context,
              material: (data) => data.textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
              cupertino: (data) => data.textTheme.textStyle.copyWith(
                color: CupertinoColors.secondaryLabel,
                fontSize: 14,
              ),
            ),
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
    final isIOS = isCupertino(context);
    
    return Container(
      decoration: BoxDecoration(
        color: isIOS 
          ? CupertinoColors.systemBackground 
          : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: isIOS
          ? [
              BoxShadow(
                color: CupertinoColors.systemGrey5.withOpacity(0.5),
                blurRadius: 10,
                offset: const Offset(0, 2),
              )
            ]
          : [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 2),
              )
            ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 36,
              color: color,
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: platformThemeData(
                context,
                material: (data) => data.textTheme.headlineSmall,
                cupertino: (data) => data.textTheme.navLargeTitleTextStyle.copyWith(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: platformThemeData(
                context,
                material: (data) => data.textTheme.bodySmall,
                cupertino: (data) => data.textTheme.textStyle.copyWith(
                  color: CupertinoColors.secondaryLabel,
                  fontSize: 12,
                ),
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
    final isIOS = isCupertino(context);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isIOS 
          ? CupertinoColors.systemBackground 
          : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: isIOS
          ? [
              BoxShadow(
                color: CupertinoColors.systemGrey5.withOpacity(0.5),
                blurRadius: 6,
                offset: const Offset(0, 2),
              )
            ]
          : [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                blurRadius: 6,
                offset: const Offset(0, 2),
              )
            ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              platformPageRoute(
                context: context,
                builder: (context) => GroupDetailView(groupId: groupId),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isIOS 
                        ? CupertinoColors.systemIndigo.withOpacity(0.1) 
                        : Colors.indigo.withOpacity(0.1),
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
                    child: Text(
                      title,
                      style: platformThemeData(
                        context,
                        material: (data) => data.textTheme.titleSmall,
                        cupertino: (data) => data.textTheme.navTitleTextStyle.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isIOS 
                        ? CupertinoColors.systemOrange.withOpacity(0.1) 
                        : Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      date,
                      style: platformThemeData(
                        context,
                        material: (data) => data.textTheme.bodySmall?.copyWith(
                          color: Colors.orange,
                          fontWeight: FontWeight.w500,
                          fontSize: 10,
                        ),
                        cupertino: (data) => data.textTheme.tabLabelTextStyle.copyWith(
                          color: CupertinoColors.systemOrange,
                          fontWeight: FontWeight.w500,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      description,
                      style: platformThemeData(
                        context,
                        material: (data) => data.textTheme.bodySmall,
                        cupertino: (data) => data.textTheme.textStyle.copyWith(
                          color: CupertinoColors.secondaryLabel,
                          fontSize: 12,
                        ),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          isIOS ? CupertinoIcons.person : Icons.person_outline,
                          size: 12,
                          color: isIOS ? CupertinoColors.secondaryLabel : Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          user,
                          style: platformThemeData(
                            context,
                            material: (data) => data.textTheme.bodySmall?.copyWith(
                              color: Colors.grey,
                              fontSize: 10,
                            ),
                            cupertino: (data) => data.textTheme.tabLabelTextStyle.copyWith(
                              color: CupertinoColors.secondaryLabel,
                              fontSize: 10,
                            ),
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
      ),
    );
  }
  
  // Kullanıcı Hızlı Bilgi Kartı
  Widget _buildUserQuickInfoCard() {
    final dashboardViewModel = Provider.of<DashboardViewModel>(context);
    final isIOS = isCupertino(context);
    final user = dashboardViewModel.user;
    
    if (user == null) {
      return const SizedBox.shrink();
    }
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        decoration: BoxDecoration(
          color: isIOS 
            ? CupertinoColors.systemBackground 
            : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: isIOS
            ? [BoxShadow(
                color: CupertinoColors.systemGrey5.withOpacity(0.5),
                blurRadius: 10,
                offset: const Offset(0, 2),
              )]
            : [BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 2),
              )],
        ),
        child: InkWell(
          onTap: _goToProfile,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: isIOS 
                      ? CupertinoColors.activeBlue.withOpacity(0.1) 
                      : Colors.blue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isIOS ? CupertinoIcons.person_fill : Icons.person,
                    color: isIOS ? CupertinoColors.activeBlue : Colors.blue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.userFullname,
                        style: platformThemeData(
                          context,
                          material: (data) => data.textTheme.titleMedium,
                          cupertino: (data) => data.textTheme.navTitleTextStyle,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.userEmail,
                        style: platformThemeData(
                          context,
                          material: (data) => data.textTheme.bodySmall,
                          cupertino: (data) => data.textTheme.textStyle.copyWith(
                            color: CupertinoColors.secondaryLabel,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isIOS 
                      ? CupertinoColors.systemIndigo.withOpacity(0.1) 
                      : Colors.indigo.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    user.userRank,
                    style: platformThemeData(
                      context,
                      material: (data) => data.textTheme.bodySmall?.copyWith(
                        color: Colors.indigo,
                        fontWeight: FontWeight.w500,
                      ),
                      cupertino: (data) => data.textTheme.tabLabelTextStyle.copyWith(
                        color: CupertinoColors.systemIndigo,
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  // Son Aktif Gruplar Listesi
  Widget _buildRecentGroupsList() {
    final groupViewModel = Provider.of<GroupViewModel>(context);
    final isIOS = isCupertino(context);
    
    if (groupViewModel.groups.isEmpty) {
      return const SizedBox.shrink();
    }
    
    // En fazla 5 grubu al
    final recentGroups = groupViewModel.groups.length > 5 
        ? groupViewModel.groups.sublist(0, 5) 
        : groupViewModel.groups;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Son Aktif Gruplar',
                style: platformThemeData(
                  context,
                  material: (data) => data.textTheme.titleLarge?.copyWith(fontSize: 18),
                  cupertino: (data) => data.textTheme.navTitleTextStyle.copyWith(
                    fontSize: 18, 
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  // Tüm gruplar sayfasına git
                },
                child: Text(
                  'Tümü',
                  style: platformThemeData(
                    context,
                    material: (data) => data.textTheme.bodyMedium?.copyWith(
                      color: Colors.blue,
                    ),
                    cupertino: (data) => data.textTheme.textStyle.copyWith(
                      color: CupertinoColors.activeBlue,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 180,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            scrollDirection: Axis.horizontal,
            itemCount: recentGroups.length,
            itemBuilder: (context, index) {
              final group = recentGroups[index];
              return _buildGroupCard(group);
            },
          ),
        ),
      ],
    );
  }
  
  Widget _buildGroupCard(Group group) {
    final isIOS = isCupertino(context);
    
    // Grup tipine göre renk ve simge belirle
    Color cardColor;
    IconData groupIcon;
    
    if (group.isAdmin) {
      groupIcon = isIOS ? CupertinoIcons.shield_lefthalf_fill : Icons.admin_panel_settings;
      cardColor = isIOS ? CupertinoColors.activeBlue : Colors.blue;
    } else if (!group.isFree) {
      groupIcon = isIOS ? CupertinoIcons.star_fill : Icons.star;
      cardColor = isIOS ? CupertinoColors.systemOrange : Colors.orange;
    } else {
      groupIcon = isIOS ? CupertinoIcons.group_solid : Icons.group;
      cardColor = isIOS ? CupertinoColors.systemGreen : Colors.green;
    }
    
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          platformPageRoute(
            context: context,
            builder: (context) => GroupDetailView(groupId: group.groupID),
          ),
        );
      },
      child: Container(
        width: 150,
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: isIOS 
            ? CupertinoColors.systemBackground 
            : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isIOS
            ? [BoxShadow(
                color: CupertinoColors.systemGrey5.withOpacity(0.5),
                blurRadius: 6,
                offset: const Offset(0, 2),
              )]
            : [BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                blurRadius: 6,
                offset: const Offset(0, 2),
              )],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Üst kısım
            Container(
              height: 60,
              decoration: BoxDecoration(
                color: cardColor.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Center(
                child: Icon(
                  groupIcon,
                  color: cardColor,
                  size: 32,
                ),
              ),
            ),
            
            // İçerik kısmı
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.groupName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: platformThemeData(
                            context,
                            material: (data) => data.textTheme.titleSmall,
                            cupertino: (data) => data.textTheme.navTitleTextStyle.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          group.groupDesc,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: platformThemeData(
                            context,
                            material: (data) => data.textTheme.bodySmall,
                            cupertino: (data) => data.textTheme.textStyle.copyWith(
                              color: CupertinoColors.secondaryLabel,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    // Alt kısım: bilgi çipleri
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Proje sayısı
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isIOS 
                              ? CupertinoColors.systemGrey4 
                              : Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${group.projects.length} Proje',
                            style: TextStyle(
                              fontSize: 10,
                              color: isIOS ? CupertinoColors.label : Colors.black87,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        
                        // Paket bilgisi
                        if (!group.isFree)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: cardColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              group.packageName,
                              style: TextStyle(
                                fontSize: 9,
                                color: cardColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Son aktiviteleri yükle - gruplardaki son logları getir
  Future<void> _loadRecentLogs(GroupViewModel groupViewModel) async {
    if (_isLoadingLogs) return;
    
    setState(() {
      _isLoadingLogs = true;
      _recentLogs = []; // Önceki logları temizle
    });
    
    try {
      _logger.i('Son aktiviteler yükleniyor...');
      
      // Gruplar boş mu kontrol et
      if (groupViewModel.groups.isEmpty) {
        // Önce grupları yüklemeyi dene
        await groupViewModel.loadGroups();
        
        // Hala boşsa işlemi bitir
        if (groupViewModel.groups.isEmpty) {
          setState(() {
            _isLoadingLogs = false;
          });
          return;
        }
      }
      
      // Tercih sırası: Admin olan gruplar, Premium gruplar, Standart gruplar
      int? targetGroupId;
      
      // 1. Önce Admin olduğumuz grupları kontrol et
      final adminGroups = groupViewModel.groups.where((group) => group.isAdmin).toList();
      if (adminGroups.isNotEmpty) {
        targetGroupId = adminGroups.first.groupID;
        _logger.i('Admin olduğunuz grup bulundu: ${adminGroups.first.groupName} (ID: $targetGroupId)');
      } 
      // 2. Admin grup yoksa premium grupları kontrol et
      else {
        final premiumGroups = groupViewModel.groups.where((group) => !group.isFree).toList();
        if (premiumGroups.isNotEmpty) {
          targetGroupId = premiumGroups.first.groupID;
          _logger.i('Premium grup bulundu: ${premiumGroups.first.groupName} (ID: $targetGroupId)');
        }
        // 3. Premium grup da yoksa herhangi bir grubu kullan
        else if (groupViewModel.groups.isNotEmpty) {
          targetGroupId = groupViewModel.groups.first.groupID;
          _logger.i('Standart grup bulundu: ${groupViewModel.groups.first.groupName} (ID: $targetGroupId)');
        }
      }
      
      // Hedef grup bulunduysa rapor verilerini getir
      if (targetGroupId != null) {
        final isAdmin = adminGroups.any((group) => group.groupID == targetGroupId);
        
        _logger.i('Grup ID: $targetGroupId için rapor verileri getiriliyor (Admin: $isAdmin)');
        
        // API'den logları getir
        try {
          final logs = await groupViewModel.getGroupReports(targetGroupId, isAdmin);
          
          if (mounted) {
            setState(() {
              _recentLogs = logs;
              _isLoadingLogs = false;
            });
            
            _logger.i('${logs.length} adet log başarıyla yüklendi');
          }
        } catch (innerError) {
          if (mounted) {
            _logger.e('Loglar yüklenirken iç hata: $innerError');
            setState(() {
              _isLoadingLogs = false;
            });
          }
        }
      } else {
        // Hedef grup bulunamadı, hata durumu
        if (mounted) {
          _logger.e('Hiçbir grup bulunamadı');
          setState(() {
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
    
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isIOS 
          ? CupertinoColors.systemBackground 
          : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: isIOS
          ? [BoxShadow(
              color: CupertinoColors.systemGrey5.withOpacity(0.5),
              blurRadius: 6,
              offset: const Offset(0, 2),
            )]
          : [BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              blurRadius: 6,
              offset: const Offset(0, 2),
            )],
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            platformPageRoute(
              context: context,
              builder: (context) => GroupDetailView(groupId: log.groupID),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
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
                      color: logColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      logIcon,
                      color: logColor,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      log.logName,
                      style: platformThemeData(
                        context,
                        material: (data) => data.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: logColor,
                        ),
                        cupertino: (data) => data.textTheme.navTitleTextStyle.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: logColor,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isIOS 
                        ? CupertinoColors.systemGrey4
                        : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      log.createDate,
                      style: platformThemeData(
                        context,
                        material: (data) => data.textTheme.bodySmall?.copyWith(
                          fontSize: 10,
                        ),
                        cupertino: (data) => data.textTheme.tabLabelTextStyle.copyWith(
                          color: CupertinoColors.secondaryLabel,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 42),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      log.logDesc,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: platformThemeData(
                        context,
                        material: (data) => data.textTheme.bodySmall,
                        cupertino: (data) => data.textTheme.textStyle.copyWith(
                          color: CupertinoColors.label,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _buildLogInfoChip(
                          context,
                          icon: isIOS ? CupertinoIcons.folder : Icons.folder,
                          text: 'Proje: ${log.projectID}',
                        ),
                        const SizedBox(width: 8),
                        _buildLogInfoChip(
                          context,
                          icon: isIOS ? CupertinoIcons.doc_text : Icons.assignment,
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
      ),
    );
  }

  Widget _buildLogInfoChip(BuildContext context, {required IconData icon, required String text}) {
    final isIOS = isCupertino(context);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isIOS 
          ? CupertinoColors.systemGrey6
          : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 10,
            color: isIOS ? CupertinoColors.secondaryLabel : Colors.grey[600],
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              color: isIOS ? CupertinoColors.secondaryLabel : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  // Son Aktiviteler bölümü
  Widget _buildRecentActivities() {
    final isIOS = isCupertino(context);
    final groupViewModel = Provider.of<GroupViewModel>(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Son Aktiviteler',
                style: platformThemeData(
                  context,
                  material: (data) => data.textTheme.titleLarge?.copyWith(fontSize: 18),
                  cupertino: (data) => data.textTheme.navTitleTextStyle.copyWith(
                    fontSize: 18, 
                    fontWeight: FontWeight.bold
                  ),
                ),
              ),
              PlatformIconButton(
                padding: EdgeInsets.zero,
                icon: Icon(
                  isIOS ? CupertinoIcons.refresh : Icons.refresh,
                  size: 20,
                ),
                onPressed: () {
                  _loadRecentLogs(groupViewModel);
                },
              ),
            ],
          ),
        ),
        
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: _isLoadingLogs 
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20.0),
                  child: PlatformCircularProgressIndicator(),
                ),
              )
            : _recentLogs.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20.0),
                    child: Column(
                      children: [
                        Icon(
                          isIOS ? CupertinoIcons.doc_text_search : Icons.assignment_late,
                          size: 36,
                          color: isIOS ? CupertinoColors.systemGrey : Colors.grey,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Henüz aktivite kaydı bulunmuyor',
                          style: platformThemeData(
                            context,
                            material: (data) => data.textTheme.bodyMedium?.copyWith(color: Colors.grey),
                            cupertino: (data) => data.textTheme.textStyle.copyWith(color: CupertinoColors.systemGrey),
                          ),
                        ),
                        const SizedBox(height: 16),
                        PlatformElevatedButton(
                          onPressed: () => _loadRecentLogs(groupViewModel),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(isIOS ? CupertinoIcons.refresh : Icons.refresh, size: 16),
                              const SizedBox(width: 8),
                              const Text('Yenile'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _recentLogs.length > 5 ? 5 : _recentLogs.length,
                  itemBuilder: (context, index) {
                    return _buildLogItem(context, _recentLogs[index]);
                  },
                ),
        ),
      ],
    );
  }
} 