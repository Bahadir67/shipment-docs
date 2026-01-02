import "package:flutter/material.dart";

import "../state/app_scope.dart";

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
      password: _passwordController.text
    );
    setState(() => _loading = false);
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Giris basarisiz."))
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              const Text(
                "Shipment Docs",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)
              ),
              const SizedBox(height: 8),
              const Text("Giris yaparak devam edin."),
              const SizedBox(height: 32),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _usernameController,
                      decoration: const InputDecoration(labelText: "Kullanici adi"),
                      validator: (value) =>
                          value == null || value.isEmpty ? "Zorunlu" : null
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      decoration: const InputDecoration(labelText: "Sifre"),
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
    );
  }
}
