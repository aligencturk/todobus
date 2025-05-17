import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'firebase_messaging_background.dart';
import 'viewmodels/profile_viewmodel.dart';
import 'viewmodels/dashboard_viewmodel.dart';
import 'viewmodels/group_viewmodel.dart';
import 'viewmodels/event_viewmodel.dart';
import 'services/logger_service.dart';
import 'services/storage_service.dart';
import 'services/device_info_service.dart';
import 'services/notification_service.dart';
import 'views/login_view.dart';
import 'main_app.dart';
import 'services/snackbar_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Logger servisi başlat
  final logger = LoggerService();
  logger.i('Uygulama başlatıldı');
  
  // Firebase başlatma
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      logger.i('Firebase başarıyla başlatıldı (main)');
    } else {
      logger.i('Firebase zaten başlatılmış (main)');
    }
    
    // Arka plan mesaj işleyicisini ayarla
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (e) {
    logger.e('Firebase başlatılırken hata: $e');
  }
  
  // Servislerin başlatılması
  final storageService = StorageService();
  await storageService.init();
  
  final deviceInfoService = DeviceInfoService();
  await deviceInfoService.init();
  
  // Bildirim servisini başlat
  try {
    await NotificationService.instance.init();
    logger.i('Bildirim servisi başarıyla başlatıldı');
    
    // FCM server key ayarla (Firebase Console'dan alınmalı)
    // NOT: Gerçek projelerde bu değer güvenli bir şekilde saklanmalıdır
    NotificationService.instance.setFcmServerKey('YOUR_FCM_SERVER_KEY');
    
    // FCM token bilgilerini debug konsoluna yazdır
    NotificationService.instance.printFcmTokenInfo();
  } catch (e) {
    logger.e('Bildirim servisi başlatılırken hata: $e');
  }
  
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}


class _MyAppState extends State<MyApp> {
  final StorageService _storageService = StorageService();
  bool _isLoggedIn = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final isLoggedIn = await _storageService.isLoggedIn();
    setState(() {
      _isLoggedIn = isLoggedIn;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ProfileViewModel()),
        ChangeNotifierProvider(create: (_) => DashboardViewModel()),
        ChangeNotifierProvider(create: (_) => GroupViewModel()),
        ChangeNotifierProvider(create: (_) => EventViewModel()),
      ],
      child: PlatformProvider(
        settings: PlatformSettingsData(
          iosUsesMaterialWidgets: true,
        ),
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            boldText: false,
          ),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'TodoBus',
            localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('tr', 'TR'),
              Locale('en', 'US'),
            ],
            theme: ThemeData(
              colorSchemeSeed: Colors.blue,
              useMaterial3: true,
            ),
            scaffoldMessengerKey: SnackBarService.scaffoldMessengerKey,
            home: _isLoading
                ? PlatformScaffold(
                    body: Center(
                      child: PlatformCircularProgressIndicator(),
                    ),
                  )
                : _isLoggedIn
                    ? const MainApp()
                    : const LoginView(),
          ),
        ),
      ),
    );
  }
}
