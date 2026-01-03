import "package:flutter/material.dart";
import "../config/theme.dart";
import "../state/app_scope.dart";
import "home_screen.dart";

class ForceChangePasswordScreen extends StatefulWidget {
  const ForceChangePasswordScreen({super.key});

  @override
  State<ForceChangePasswordScreen> createState() => _ForceChangePasswordScreenState();
}

class _ForceChangePasswordScreenState extends State<ForceChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _loading = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final appState = AppScope.of(context);
    try {
      // Current password is known: mert123
      await appState.authApi.changePassword(
        "mert123",
        _newController.text
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sifre guncellendi.")));
        // Navigate to Home replacing everything
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Hata olustu.")));
      }
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Sifre Degisikligi Zorunlu"), automaticallyImplyLeading: false),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.security, size: 64, color: Colors.orange),
                  const SizedBox(height: 16),
                  const Text(
                    "Guvenliginiz icin varsayilan sifrenizi degistirmeniz gerekmektedir.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.paper)
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _newController,
                    obscureText: true,
                    style: const TextStyle(color: AppTheme.ink),
                    decoration: const InputDecoration(labelText: "Yeni Sifre"),
                    validator: (v) {
                      if (v!.length < 6) return "En az 6 karakter";
                      if (v == "mert123") return "Eski sifreyle ayni olamaz";
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmController,
                    obscureText: true,
                    style: const TextStyle(color: AppTheme.ink),
                    decoration: const InputDecoration(labelText: "Yeni Sifre (Tekrar)"),
                    validator: (v) => v != _newController.text ? "Sifreler eslesmiyor" : null,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      child: const Text("Degistir ve Devam Et"),
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
