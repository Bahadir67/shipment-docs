import "package:flutter/material.dart";

import "data/local/isar_service.dart";
import "data/remote/api_client.dart";
import "data/remote/auth_api.dart";
import "screens/home_screen.dart";
import "screens/login_screen.dart";
import "state/app_scope.dart";
import "state/app_state.dart";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final isarService = await IsarService.open();
  final appState = AppState(
    isar: isarService.isar,
    authApi: AuthApi(client: ApiClient())
  );
  await appState.init();
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
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F1A1C)),
          useMaterial3: true
        ),
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
    if (!appState.isReady) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator())
      );
    }
    return appState.hasAccess ? const HomeScreen() : const LoginScreen();
  }
}
