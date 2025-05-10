import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'views/dashboard_view.dart';
import 'views/profile_view.dart';
import 'views/groups_view.dart';

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  _MainAppState createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  int _currentIndex = 0;
  final List<Widget> _pages = [
    const DashboardView(),
    const GroupsView(),
    const ProfileView(),
  ];

  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      body: _pages[_currentIndex],
      material: (_, __) => MaterialScaffoldData(
        // Material platform için ayarlar
      ),
      cupertino: (_, __) => CupertinoPageScaffoldData(
        // iOS platform için ayarlar
      ),
      bottomNavBar: PlatformNavBar(
        currentIndex: _currentIndex,
        itemChanged: (int index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: Icon(context.platformIcons.home),
            label: 'Anasayfa',
          ),
          BottomNavigationBarItem(
            icon: Icon(context.platformIcons.collections),
            label: 'Gruplar',
          ),
          BottomNavigationBarItem(
            icon: Icon(context.platformIcons.person),
            label: 'Profil',
          ),
        ],
        material: (_, __) => MaterialNavBarData(
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Theme.of(context).colorScheme.primary,
        ),
        cupertino: (_, __) => CupertinoTabBarData(
          activeColor: CupertinoColors.activeBlue,
          iconSize: 24,
        ),
      ),
    );
  }
} 