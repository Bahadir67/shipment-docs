import "package:flutter/material.dart";
import "../config/theme.dart";
import "../state/app_scope.dart";

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _loading = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final appState = AppScope.of(context);
    try {
      await appState.authApi.changePassword(
        _currentController.text,
        _newController.text
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sifre degistirildi.")));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Hata: Mevcut sifre yanlis olabilir.")));
      }
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Sifre Degistir")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _currentController,
                obscureText: true,
                style: const TextStyle(color: AppTheme.ink),
                decoration: const InputDecoration(labelText: "Mevcut Sifre"),
                validator: (v) => v!.isEmpty ? "Zorunlu" : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _newController,
                obscureText: true,
                style: const TextStyle(color: AppTheme.ink),
                decoration: const InputDecoration(labelText: "Yeni Sifre"),
                validator: (v) => v!.length < 6 ? "En az 6 karakter" : null,
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
                  child: const Text("Guncelle"),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
