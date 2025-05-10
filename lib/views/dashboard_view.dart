import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:provider/provider.dart';
import '../services/storage_service.dart';
import '../services/logger_service.dart';
import '../viewmodels/group_viewmodel.dart';
import 'login_view.dart';
import 'profile_view.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({Key? key}) : super(key: key);

  @override
  _DashboardViewState createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  final StorageService _storageService = StorageService();
  final LoggerService _logger = LoggerService();
  String _userName = "";
  
  @override
  void initState() {
    super.initState();
    _getUserInfo();
  }
  
  Future<void> _getUserInfo() async {
    final userName = await _storageService.getUserName();
    if (userName != null && userName.isNotEmpty) {
      setState(() {
        _userName = userName;
      });
    } else {
      setState(() {
        _userName = "Kullanıcı";
      });
    }
    _logger.i('Dashboard açıldı: Kullanıcı: $_userName');
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
            CupertinoSliverRefreshControl(
              onRefresh: () async {
                await groupViewModel.loadGroups();
              },
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
                    value: '0',
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
                    value: '0',
                    icon: isIOS ? CupertinoIcons.time : Icons.access_time,
                    color: isIOS ? CupertinoColors.systemPurple : Colors.purple,
                  ),
                ]),
              ),
            ),
            
            // Son aktiviteler
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Son Aktiviteler',
                  style: platformThemeData(
                    context,
                    material: (data) => data.textTheme.titleLarge,
                    cupertino: (data) => data.textTheme.navTitleTextStyle.copyWith(
                      fontSize: 20, 
                      fontWeight: FontWeight.bold
                    ),
                  ),
                ),
              ),
            ),
            
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return _buildActivityItem(
                      context, 
                      title: 'Aktivite ${index + 1}',
                      description: 'Bu bir örnek aktivite açıklamasıdır.',
                      time: '${index + 1} saat önce',
                      icon: isIOS 
                        ? (index % 2 == 0 ? CupertinoIcons.checkmark_circle : CupertinoIcons.person)
                        : (index % 2 == 0 ? Icons.check_circle_outline : Icons.person),
                    );
                  },
                  childCount: 3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildWelcomeSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Merhaba, $_userName',
            style: platformThemeData(
              context,
              material: (data) => data.textTheme.headlineMedium,
              cupertino: (data) => data.textTheme.navLargeTitleTextStyle,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Bugün yapılacaklar',
            style: platformThemeData(
              context,
              material: (data) => data.textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
              cupertino: (data) => data.textTheme.textStyle.copyWith(
                color: CupertinoColors.secondaryLabel,
                fontSize: 16,
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
                material: (data) => data.textTheme.headlineMedium,
                cupertino: (data) => data.textTheme.navLargeTitleTextStyle.copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: platformThemeData(
                context,
                material: (data) => data.textTheme.bodyMedium,
                cupertino: (data) => data.textTheme.textStyle.copyWith(
                  color: CupertinoColors.secondaryLabel,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildActivityItem(
    BuildContext context, {
    required String title,
    required String description,
    required String time,
    required IconData icon,
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
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isIOS 
                  ? CupertinoColors.systemGrey5 
                  : Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: isIOS 
                  ? CupertinoColors.activeBlue 
                  : Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: platformThemeData(
                      context,
                      material: (data) => data.textTheme.titleMedium,
                      cupertino: (data) => data.textTheme.navTitleTextStyle.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: platformThemeData(
                      context,
                      material: (data) => data.textTheme.bodyMedium,
                      cupertino: (data) => data.textTheme.textStyle.copyWith(
                        color: CupertinoColors.secondaryLabel,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              time,
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
      ),
    );
  }
} 