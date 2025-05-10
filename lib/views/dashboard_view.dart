import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:provider/provider.dart';
import 'dart:io' show Platform;
import '../services/storage_service.dart';
import '../services/logger_service.dart';
import '../viewmodels/group_viewmodel.dart';
import '../viewmodels/dashboard_viewmodel.dart';
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
        groupViewModel.loadGroups();
        
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
          trailing: CupertinoButton(
            padding: EdgeInsets.zero,
            child: Icon(context.platformIcons.search),
            onPressed: () {
              // Arama işlevi buraya eklenecek
            },
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
                      },
                    ),
                  ),
                ),
              ),
            // iOS tarzı kullanıcı selamlama bölümü
            SliverToBoxAdapter(
              child: _buildWelcomeSection(),
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
                    title: 'Yaklaşan',
                    value: '${dashboardViewModel.upcomingEvents.length}',
                    icon: isIOS ? CupertinoIcons.time : Icons.access_time,
                    color: isIOS ? CupertinoColors.systemPurple : Colors.purple,
                  ),
                ]),
              ),
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
} 