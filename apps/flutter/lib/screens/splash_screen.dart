import "package:flutter/material.dart";

import "../config/theme.dart";

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.bgAccent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.line),
              ),
              child: const Icon(Icons.local_shipping, size: 42, color: AppTheme.accent),
            ),
            const SizedBox(height: 16),
            const Text(
              "Shipment Docs",
              style: TextStyle(
                color: AppTheme.paper,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Yukleniyor...",
              style: TextStyle(color: AppTheme.paper.withOpacity(0.6)),
            ),
            const SizedBox(height: 20),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent),
            ),
          ],
        ),
      ),
    );
  }
}
