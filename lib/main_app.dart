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
  int _unreadNotifications = 0;
  
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
  void initState() {
    super.initState();
    _checkNotifications();
  }
  
  // Bildirimleri kontrol et
  Future<void> _checkNotifications() async {
    await NotificationService.instance.fetchNotifications();
    setState(() {
      _unreadNotifications = NotificationService.instance.unreadCount;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      body: _pages[_currentIndex],
      material: (_, __) => MaterialScaffoldData(
        // Material platform için ayarlar
        appBar: _currentIndex == 0 ? AppBar(
          title: const Text('TodoBus'),
          actions: [
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
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const NotificationsView(),
                  ),
                ).then((_) => _checkNotifications());
              },
            ),
          ],
        ) : null,
      ),
      cupertino: (_, __) => CupertinoPageScaffoldData(
        // iOS platform için ayarlar
        navigationBar: _currentIndex == 0 ? CupertinoNavigationBar(
          middle: const Text('TodoBus'),
          trailing: GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (context) => const NotificationsView(),
                ),
              ).then((_) => _checkNotifications());
            },
            child: Stack(
              children: [
                const Icon(CupertinoIcons.bell),
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
          ),
        ) : null,
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