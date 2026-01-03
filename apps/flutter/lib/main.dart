import "package:flutter/material.dart";

import "config/theme.dart";
import "data/local/isar_service.dart";
import "data/remote/api_client.dart";
import "data/remote/auth_api.dart";
import "screens/home_screen.dart";
import "screens/login_screen.dart";
import "state/app_scope.dart";
import "state/app_state.dart";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Isar Init with Error Handling
  IsarService? isarService;
  try {
    print("Initializing Database...");
    isarService = await IsarService.open();
    print("Database Initialized.");
  } catch (e) {
    print("Database Initialization FAILED: $e");
    // In a real app, show a fatal error screen here. 
    // For now, we allow crash or return, but logs are key.
    return;
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
  
  runApp(ShipmentDocsApp(appState: appState));
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

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);
    // If not ready, show splash (or black screen if waiting)
    // But since we force ready on timeout, this should transition.
    
    // Auth Check
    if (appState.user == null) {
      return const LoginScreen();
    }
    return const HomeScreen();
  }
}