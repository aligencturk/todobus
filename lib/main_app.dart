import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:provider/provider.dart';
import 'views/dashboard_view.dart';
import 'views/profile_view.dart';
import 'views/groups_view.dart';
import 'views/events_view.dart';
import 'views/notifications_view.dart';
import 'viewmodels/event_viewmodel.dart';
import 'services/notification_service.dart';

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  MainAppState createState() => MainAppState();
}

class MainAppState extends State<MainApp> {
  int _currentIndex = 0;
  
  // Bu metodu dışarıdan çağrılabilir hale getiriyoruz
  void setCurrentIndex(int index) {
    setState(() {
      _currentIndex = index;
    });
  }
  
  final List<Widget> _pages = [
    const DashboardView(),
    const GroupsView(),
    const EventsView(groupID: 0), // Tüm etkinlikler
    const ProfileView(),
  ];

  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      body: _pages[_currentIndex],
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
            icon: Icon(context.platformIcon(material: Icons.calendar_month, cupertino: CupertinoIcons.calendar)),
            label: 'Etkinlikler',
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