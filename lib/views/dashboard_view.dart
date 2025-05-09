import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../services/logger_service.dart';
import 'login_view.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({Key? key}) : super(key: key);

  @override
  _DashboardViewState createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  final StorageService _storageService = StorageService();
  final LoggerService _logger = LoggerService();
  int _userID = 0;
  
  @override
  void initState() {
    super.initState();
    _getUserInfo();
  }
  
  Future<void> _getUserInfo() async {
    final userId = _storageService.getUserId();
    if (userId != null) {
      setState(() {
        _userID = userId;
      });
    }
    _logger.i('Dashboard açıldı: Kullanıcı ID: $_userID');
  }
  
  Future<void> _logout() async {
    await _storageService.clearUserData();
    _logger.i('Kullanıcı çıkış yaptı');
    
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginView()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TodoBus Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Çıkış Yap',
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Hoş geldiniz!',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 20),
            Text(
              'Kullanıcı ID: $_userID',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 40),
            const Text(
              'Bu ekranda görevleri listeleyebilir ve yönetebilirsiniz.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
} 