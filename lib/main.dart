import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/app_config.dart';
import 'config/theme.dart';
import 'core/cache/hive_manager.dart';
import 'services/locale_service.dart';
import 'services/settings_service.dart';
import 'viewmodels/scanner_viewmodel.dart';
import 'viewmodels/shopping_assistant_viewmodel.dart';
import 'viewmodels/shopping_list_viewmodel.dart';
import 'viewmodels/discount_viewmodel.dart';
import 'viewmodels/fuel_viewmodel.dart';
import 'ui/components/app_background.dart';
import 'ui/screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('[CompraMas] main() iniciando...');

  // 1. Inicializar persistencia ultrarrápida Hive (sin bloqueos de red)
  try {
    await HiveManager.init();
    debugPrint('[CompraMas] HiveManager inicializado.');
  } catch (e) {
    debugPrint('[CompraMas] Error inicializando HiveManager: $e');
  }

  // 2. Cargar configuración de credenciales y endpoints en memoria
  try {
    await AppConfig.loadConfig().timeout(const Duration(seconds: 2));
    debugPrint('[CompraMas] Configuración cargada.');
  } catch (e) {
    debugPrint('[CompraMas] Advertencia al cargar config.json: $e');
  }

  // 3. Inicializar Firebase y Ads en segundo plano (NO bloquea el inicio de la app)
  unawaited(_initBackgroundServices());

  debugPrint('[CompraMas] Lanzando runApp()...');
  runApp(const CompraMasApp());
}

Future<void> _initBackgroundServices() async {
  try {
    await Firebase.initializeApp().timeout(const Duration(seconds: 3));
    debugPrint('[CompraMas] Firebase inicializado.');

    // Inicializar Crashlytics para capturar excepciones no controladas de Flutter
    FlutterError.onError = (errorDetails) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
    debugPrint('[CompraMas] Firebase Crashlytics configurado.');
  } catch (e) {
    debugPrint('[CompraMas] Firebase omitido: $e');
  }
}

class CompraMasApp extends StatelessWidget {
  const CompraMasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocaleService()),
        ChangeNotifierProvider(create: (_) => SettingsService()),
        ChangeNotifierProvider(create: (_) => ScannerViewModel()),
        ChangeNotifierProvider(create: (_) => ShoppingListViewModel()..loadAllLists()),
        ChangeNotifierProvider(create: (_) => ShoppingAssistantViewModel()),
        ChangeNotifierProvider(create: (_) => DiscountViewModel()..loadDiscounts()),
        ChangeNotifierProvider(create: (_) => FuelViewModel()),
      ],
      child: Consumer<SettingsService>(
        builder: (context, settings, _) => MaterialApp(
          title: 'CompraMas',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.light,
          builder: (context, child) {
            final mq = MediaQuery.of(context);
            return MediaQuery(
              data: mq.copyWith(
                textScaler: TextScaler.linear(settings.fontScale),
              ),
              child: AppBackground(child: child ?? const SizedBox.shrink()),
            );
          },
          home: const SplashScreen(),
        ),
      ),
    );
  }
}
