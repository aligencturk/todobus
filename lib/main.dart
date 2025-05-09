import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/logger_service.dart';
import 'services/storage_service.dart';
import 'views/login_view.dart';
import 'views/dashboard_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Servislerin başlatılması
  final storageService = StorageService();
  await storageService.init();
  
  final logger = LoggerService();
  logger.i('Uygulama başlatıldı');
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final storageService = StorageService();
    final isLoggedIn = storageService.isLoggedIn();

    return MaterialApp(
      title: 'TodoBus',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          primary: Colors.blue,
        ),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
      home: isLoggedIn ? const DashboardView() : const LoginView(),
    );
  }
}
