import "package:flutter/material.dart";
import "../config/theme.dart";
import "../state/app_scope.dart";
import "home_screen.dart";
import "force_change_password_screen.dart";

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final appState = AppScope.of(context);
    if (!_formKey.currentState!.validate()) return;
    if (!appState.isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Offline modda giris yapilamaz."))
      );
      return;
    }
    setState(() => _loading = true);
    final success = await appState.login(
      username: _usernameController.text.trim(),
      password: _passwordController.text.trim(),
    );

    if (success && mounted) {
      if (_passwordController.text.trim() == "mert123") {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ForceChangePasswordScreen()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } else if (mounted) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Giris basarisiz."),
          backgroundColor: AppTheme.accent,
        )
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Web style panel width constraint
    final isLargeScreen = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Card(
                color: AppTheme.paper, // Manual color
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Giris",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.ink, // Ensure dark text on light card
                          fontFamily: 'Space Grotesk'
                        )
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Calisma alanina ulasmak icin giris yapin.",
                        style: TextStyle(color: AppTheme.ink.withOpacity(0.6)) // Dark muted text
                      ),
                      const SizedBox(height: 24),
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _usernameController,
                              style: const TextStyle(color: AppTheme.ink), // Dark text input
                              decoration: const InputDecoration(
                                labelText: "Kullanici adi",
                                hintText: "qc_user"
                              ),
                              validator: (value) =>
                                  value == null || value.isEmpty ? "Zorunlu" : null
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _passwordController,
                              style: const TextStyle(color: AppTheme.ink), // Dark text input
                              decoration: const InputDecoration(
                                labelText: "Sifre",
                                hintText: "Sifre girin"
                              ),
                              obscureText: true,
                              validator: (value) =>
                                  value == null || value.isEmpty ? "Zorunlu" : null
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _loading ? null : _submit,
                                child: Text(_loading ? "Giris..." : "Giris")
                              )
                            )
                          ],
                        )
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}