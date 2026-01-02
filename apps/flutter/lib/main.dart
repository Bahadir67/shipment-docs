import "package:flutter/material.dart";

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ShipmentDocsApp());
}

class ShipmentDocsApp extends StatelessWidget {
  const ShipmentDocsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Shipment Docs",
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F1A1C)),
        useMaterial3: true
      ),
      home: const Scaffold(
        body: Center(
          child: Text("Shipment Docs - Flutter MVP"),
        )
      )
    );
  }
}
