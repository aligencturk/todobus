import 'package:flutter/material.dart';
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
import 'services/firebase_messaging_service.dart';
import 'services/notification_viewmodel.dart';
import 'services/base_api_service.dart';
import 'services/onboarding_service.dart';
import 'services/spelling_correction_service.dart';
import 'views/login_view.dart';
import 'views/splash_screen.dart';
import 'views/onboarding_view.dart';
import 'main_app.dart';
import 'services/snackbar_service.dart';
// Batarya optimizasyonu için gerekli paket
import 'package:disable_battery_optimization/disable_battery_optimization.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:path/path.dart';

void main() async {
  // Native splash screen için gerekli
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  
  // Logger servisi başlat
  final logger = LoggerService();
  logger.i('Uygulama başlatıldı');
  
  // .env dosyasını yükle
  try {
    // Önce projenin kök dizinindeki .env'yi dene
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
  
  // Firebase başlatma
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
  
  // Servislerin başlatılması
  final storageService = StorageService();
  await storageService.init();
  
  final deviceInfoService = DeviceInfoService();
  await deviceInfoService.init();
  
  // Bildirim servisini başlat
  try {
    // Firebase Messaging Servisi başlatılıyor
    await FirebaseMessagingService.instance.initialize();
    logger.i('Firebase Messaging servisi başarıyla başlatıldı');
  } catch (e) {
    logger.e('Bildirim servisi başlatılırken hata: $e');
  }

  // Yazım düzeltme servisini başlat
  try {
    await SpellingCorrectionService.instance.initialize();
    logger.i('Yazım düzeltme servisi başarıyla başlatıldı');
  } catch (e) {
    logger.e('Yazım düzeltme servisi başlatılırken hata: $e');
  }
  
  // Native splash screen'i kaldır, kendi özel splash screen'imize geçiş yapacağız
  FlutterNativeSplash.remove();
  
  runApp(const MyApp());
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
      
      _logger.i('Bildirim izin durumu: ${settings.authorizationStatus}');
      
      // Batarya optimizasyonu kontrolü ve istemi
      await _checkBatteryOptimization();
      
    } catch (e) {
      _logger.e('Bildirim ayarları yapılandırılırken hata: $e');
    }
  }

  Future<void> _checkBatteryOptimization() async {
    try {
      // Tüm batarya optimizasyonları devre dışı bırakılmış mı kontrol et
      final isAllOptimizationsDisabled = 
          await DisableBatteryOptimization.isAllBatteryOptimizationDisabled;
      
      if (isAllOptimizationsDisabled != null && !isAllOptimizationsDisabled) {
        // Kullanıcıya batarya optimizasyonlarını devre dışı bırakması için bilgi ver
        DisableBatteryOptimization.showDisableAllOptimizationsSettings(
          "Otomatik Başlatmayı Etkinleştir",
          "Bildirimleri düzgün alabilmek için otomatik başlatmayı etkinleştirin",
          "Cihazınızda ek batarya optimizasyonları var",
          "Bildirimleri arka planda alabilmek için batarya optimizasyonlarını devre dışı bırakın"
        );
      }
    } catch (e) {
      _logger.e('Batarya optimizasyonu kontrolü sırasında hata: $e');
    }
  }

  Future<void> _checkAppStatus() async {
    final isLoggedIn = await _storageService.isLoggedIn();
    final isOnboardingCompleted = await OnboardingService.isOnboardingCompleted();
    
    setState(() {
      _isLoggedIn = isLoggedIn;
      _isOnboardingCompleted = isOnboardingCompleted;
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
        ChangeNotifierProvider(
          create: (_) => NotificationViewModel(FirebaseMessagingService.instance),
        ),
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
            navigatorKey: BaseApiService.navigatorKey,
            routes: {
              '/login': (context) => const LoginView(),
              '/main': (context) => const MainApp(),
              '/onboarding': (context) => const OnboardingView(),
            },
            home: SplashScreen(
              duration: const Duration(seconds: 3),
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
