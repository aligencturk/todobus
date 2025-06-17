import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io';
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
import 'services/base_api_service.dart';
import 'services/spelling_correction_service.dart';
import 'views/login_view.dart';
import 'views/splash_screen.dart';
import 'views/onboarding_view.dart';
import 'main_app.dart';
import 'services/snackbar_service.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import '../services/version_check_service.dart';

void main() async {
  // Native splash screen için gerekli
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  
  // Logger servisi başlat
  final logger = LoggerService();
  logger.i('Uygulama başlatıldı');
  
  try {
    // Kritik servisleri paralel olarak başlat
    await _initializeCriticalServices(logger);
    
    // Non-kritik servisleri arka planda başlat (uygulamayı bloklamaz)
    _initializeNonCriticalServices(logger);
    
  } catch (e) {
    logger.e('Servisler başlatılırken hata: $e');
  }
  
  runApp(const MyApp());
}

// Kritik servisleri paralel olarak başlat
Future<void> _initializeCriticalServices(LoggerService logger) async {
  await Future.wait([
    // .env dosyasını yükle
    _loadEnvironmentFile(logger),
    
    // Firebase başlatma
    _initializeFirebase(logger),
    
    // Storage servisi başlatma
    _initializeStorage(),
    
    // Device info servisi başlatma
    _initializeDeviceInfo(),
  ]);
}

// Non-kritik servisleri arka planda başlat
void _initializeNonCriticalServices(LoggerService logger) {
  // Bu servisler uygulamanın açılmasını bloklamaz
  Future.microtask(() async {
    try {
      await Future.wait([
        // Firebase Messaging Servisi
        _initializeMessaging(logger),
        
        // Yazım düzeltme servisini başlat
        _initializeSpellingCorrection(logger),
        
        // Version check servisini başlat
        _initializeVersionCheck(logger),
      ]);
      
      logger.i('✅ Tüm non-kritik servisler başarıyla yüklendi');
      
    } catch (e) {
      logger.e('Non-kritik servisler başlatılırken hata: $e');
    } finally {
      // Servisler yüklendikten hemen sonra native splash'i kaldır
      FlutterNativeSplash.remove();
      logger.i('🎨 Native splash kaldırıldı');
    }
  });
}

Future<void> _loadEnvironmentFile(LoggerService logger) async { 
  try {
    await dotenv.load(fileName: ".env");
    logger.i('.env dosyası başarıyla yüklendi');
  } catch (e) {
    logger.e('.env dosyası yüklenemedi: $e');
    
    // Hata detayını logla
    logger.i('Çalışma dizini: ${Directory.current.path}');
    logger.i('Hata detayı: ${e.toString()}');
    
    // .env dosyasının dosya sisteminde var olup olmadığını kontrol et
    final envFile = File('.env');
    if (await envFile.exists()) {
      logger.i('.env dosyası mevcut fakat yüklenemedi, içeriği kontrol edin');
      try {
        final content = await envFile.readAsString();
        // API anahtarını gizleyerek içeriği logla
        final sanitizedContent = content.replaceAll(RegExp(r'GEMINI_API_KEY=.*'), 'GEMINI_API_KEY=[GİZLİ]');
        logger.i('.env içeriği: $sanitizedContent');
      } catch (readError) {
        logger.e('.env dosyası okunamadı: $readError');
      }
    } else {
      logger.e('.env dosyası bulunamadı: ${envFile.absolute.path}');
    }
  }
}

Future<void> _initializeFirebase(LoggerService logger) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    logger.i('Firebase başarıyla başlatıldı (main)');
    
    // Arka plan mesaj işleyicisini ayarla
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    
    // iOS için bildirim ayarlarını yapılandır
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true, // Bildirim göster
      badge: true, // Rozet göster
      sound: true, // Ses çal
    );
  } catch (e) {
    logger.e('Firebase başlatılırken hata: $e');
  }
}

Future<void> _initializeStorage() async {
  final storageService = StorageService();
  await storageService.init();
}

Future<void> _initializeDeviceInfo() async {
  final deviceInfoService = DeviceInfoService();
  await deviceInfoService.init();
}

Future<void> _initializeMessaging(LoggerService logger) async {
  try {
    await NotificationService.instance.init();
    
    // Notification tap callback'i ayarla
    NotificationService.instance.onNotificationTap = (data) {
      logger.i('📱 Notification tapped from main: $data');
      // Burada gerekli navigation işlemleri yapılabilir
    };
    
    // Token update callback'i ayarla
    NotificationService.instance.onTokenUpdate = (token) {
      logger.i('🔄 FCM Token updated: ${token.substring(0, 20)}...');
    };
    
    logger.i('✅ Notification servisi başarıyla başlatıldı');
  } catch (e) {
    logger.e('❌ Bildirim servisi başlatılırken hata: $e');
  }
}

Future<void> _initializeSpellingCorrection(LoggerService logger) async {
  try {
    await SpellingCorrectionService.instance.initialize();
    logger.i('Yazım düzeltme servisi başarıyla başlatıldı');
  } catch (e) {
    logger.e('Yazım düzeltme servisi başlatılırken hata: $e');
  }
}

Future<void> _initializeVersionCheck(LoggerService logger) async {
  final versionCheckService = VersionCheckService();
  await versionCheckService.initialize();
  logger.i('Version check servisi başlatıldı');
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}


class _MyAppState extends State<MyApp> {
  final StorageService _storageService = StorageService();
  final LoggerService _logger = LoggerService();
  bool _isLoggedIn = false;
  bool _isOnboardingCompleted = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkAppStatus();
    _setupPushNotifications();
  }

  Future<void> _setupPushNotifications() async {
    try {
      // Bildirim izinlerini kontrol et ve iste
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
        criticalAlert: true,
      );
      
      _logger.i('📱 Bildirim izin durumu: ${settings.authorizationStatus}');
      
      // Debug modunda ve izinler alındıysa debug bilgilerini göster
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        // Debug bilgilerini sadece debug modunda ve background'da göster
        if (kDebugMode) {
          Future.delayed(const Duration(seconds: 10), () async {
            try {
              await NotificationService.instance.debug();
            } catch (e) {
              _logger.e('❌ Debug bilgileri gösterilirken hata: $e');
            }
          });
        }
      }
      
    } catch (e) {
      _logger.e('❌ Bildirim ayarları yapılandırılırken hata: $e');
    }
  }

  Future<void> _checkAppStatus() async {
    try {
      final isOnboardingCompleted = _storageService.isOnboardingCompleted();
      final token = _storageService.getToken();
      
      setState(() {
        _isOnboardingCompleted = isOnboardingCompleted;
        _isLoggedIn = token != null;
        _isLoading = false;
      });
      
      _logger.i('App durumu kontrol edildi: Onboarding: $isOnboardingCompleted, Giriş: $_isLoggedIn');
      
    } catch (e) {
      _logger.e('Uygulama durumu kontrol edilirken hata: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ProfileViewModel(), lazy: true),
        ChangeNotifierProvider(create: (_) => DashboardViewModel(), lazy: true),
        ChangeNotifierProvider(create: (_) => GroupViewModel(), lazy: true),
                  ChangeNotifierProvider(create: (_) => EventViewModel(), lazy: true),
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
              useMaterial3: false,
              brightness: Brightness.light,
              appBarTheme: const AppBarTheme(
                centerTitle: true,
                elevation: 1,
              ),
              bottomNavigationBarTheme: const BottomNavigationBarThemeData(
                type: BottomNavigationBarType.fixed,
                elevation: 8,
              ),
            ),
            scaffoldMessengerKey: SnackBarService.scaffoldMessengerKey,
            navigatorKey: BaseApiService.navigatorKey,
            routes: {
              '/login': (context) => const LoginView(),
              '/main': (context) => const MainApp(),
              '/onboarding': (context) => const OnboardingView(),
            },
            home: SplashScreen(
              duration: const Duration(milliseconds: 300), // Splash süresini kısaltıyoruz
              child: _isLoading
                ? PlatformScaffold(
                    body: Center(
                      child: PlatformCircularProgressIndicator(),
                    ),
                  )
                : !_isOnboardingCompleted
                    ? const OnboardingView()
                    : _isLoggedIn
                        ? const MainApp()
                        : const LoginView(),
            ),
          ),
        ),
      ),
    );
  }
}
