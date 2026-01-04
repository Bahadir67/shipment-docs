import "package:flutter/material.dart";

import "config/theme.dart";
import "data/local/isar_service.dart";
import "data/remote/api_client.dart";
import "data/remote/auth_api.dart";
import "screens/home_screen.dart";
import "screens/login_screen.dart";
import "screens/splash_screen.dart";
import "state/app_scope.dart";
import "state/app_state.dart";

Future<void> main() async {
  // 1. Ensure bindings are ready
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. RUN APP IMMEDIATELY to show the dark SplashScreen as fast as possible
  runApp(const BootstrapApp());
}

class ShipmentDocsApp extends StatelessWidget {
  const ShipmentDocsApp({super.key, required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      notifier: appState,
      child: MaterialApp(
        title: "Shipment Docs",
        theme: AppTheme.lightTheme,
        home: const AppShell()
      )
    );
  }
}

class BootstrapApp extends StatefulWidget {
  const BootstrapApp({super.key});

  @override
  State<BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends State<BootstrapApp> {
  late final Future<AppState> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = _initApp();
  }

  Future<AppState> _initApp() async {
    // Isar Init with Error Handling
    IsarService? isarService;
    try {
      print("Initializing Database...");
      isarService = await IsarService.open();
      print("Database Initialized.");
    } catch (e) {
      print("Database Initialization FAILED: $e");
      rethrow;
    }

    final appState = AppState(
      isar: isarService.isar,
      authApi: AuthApi(client: ApiClient())
    );

    try {
      print("Initializing AppState...");
      // Add timeout to prevent infinite hanging on network/connectivity checks
      await appState.init().timeout(const Duration(seconds: 5), onTimeout: () {
        print("AppState init timed out! Continuing anyway...");
        appState.isReady = true; // Force ready to show UI
      });
      print("AppState Initialized.");
    } catch (e) {
      print("AppState Initialization FAILED: $e");
      // Continue to run app so user sees Login Screen
    }

    return appState;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppState>(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return MaterialApp(
            title: "Shipment Docs",
            theme: AppTheme.lightTheme,
            home: const SplashScreen(),
          );
        }
        if (snapshot.hasError) {
          return MaterialApp(
            title: "Shipment Docs",
            theme: AppTheme.lightTheme,
            home: const Scaffold(
              body: Center(
                child: Text("Baslatma hatasi. Lutfen tekrar deneyin."),
              ),
            ),
          );
        }
        return ShipmentDocsApp(appState: snapshot.data!);
      }
    );
  }
}

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);
    // If not ready, show splash (or black screen if waiting)
    if (!appState.isReady) {
      return const SplashScreen();
    }
    
    // Auth Check
    if (appState.user == null) {
      return const LoginScreen();
    }
    return const HomeScreen();
  }
}
