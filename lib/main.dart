import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'viewmodels/profile_viewmodel.dart';
import 'viewmodels/dashboard_viewmodel.dart';
import 'viewmodels/group_viewmodel.dart';
import 'viewmodels/event_viewmodel.dart';
import 'services/logger_service.dart';
import 'services/storage_service.dart';
import 'services/device_info_service.dart';
import 'views/login_view.dart';
import 'main_app.dart';
import 'services/snackbar_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Servislerin başlatılması
  final storageService = StorageService();
  await storageService.init();
  

  
  final deviceInfoService = DeviceInfoService();
  await deviceInfoService.init();
  
  final logger = LoggerService();
  logger.i('Uygulama başlatıldı');
  
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
