import "package:flutter/material.dart";
import "../config/theme.dart";
import "../state/app_scope.dart";

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _users = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final appState = AppScope.of(context);
    try {
      final list = await appState.authApi.listUsers();
      setState(() => _users = list);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Liste alinamadi.")));
      }
    }
    setState(() => _loading = false);
  }

  Future<void> _createUser() async {
    final usernameController = TextEditingController();
    final roleController = TextEditingController(text: "user"); // Default user
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Yeni Kullanici"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: usernameController, decoration: const InputDecoration(labelText: "Kullanici Adi")),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: "user",
              items: const [
                DropdownMenuItem(value: "user", child: Text("Kullanici (User)")),
                DropdownMenuItem(value: "admin", child: Text("Yonetici (Admin)")),
              ],
              onChanged: (v) => roleController.text = v!,
              decoration: const InputDecoration(labelText: "Rol"),
            ),
            const SizedBox(height: 8),
            const Text("Varsayilan sifre: mert123", style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Iptal")),
          ElevatedButton(
            onPressed: () async {
              final appState = AppScope.of(context);
              try {
                await appState.authApi.createUser(
                  usernameController.text.trim(),
                  "mert123",
                  roleController.text
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  _refresh();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Kullanici olusturuldu.")));
                }
              } catch (e) {
                // Handle duplicate user etc
              }
            }, 
            child: const Text("Olustur")
          )
        ],
      )
    );
  }

  Future<void> _resetPassword(String id, String username) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("$username Sifresini Sifirla?"),
        content: const Text("Sifre 'mert123' olarak degistirilecek. Emin misiniz?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Iptal")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("SIFIRLA")),
        ],
      )
    );

    if (confirm == true) {
      final appState = AppScope.of(context);
      await appState.authApi.resetPassword(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sifre sifirlandi: mert123")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Kullanici Yonetimi")),
      floatingActionButton: FloatingActionButton(
        onPressed: _createUser,
        child: const Icon(Icons.add),
      ),
      body: _loading 
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              itemCount: _users.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                final u = _users[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: u["role"] == "admin" ? Colors.redAccent : Colors.blueAccent,
                    child: Icon(u["role"] == "admin" ? Icons.admin_panel_settings : Icons.person, color: Colors.white),
                  ),
                  title: Text(u["username"]),
                  subtitle: Text(u["role"].toString().toUpperCase()),
                  trailing: IconButton(
                    icon: const Icon(Icons.lock_reset, color: Colors.orange),
                    onPressed: () => _resetPassword(u["id"], u["username"]),
                    tooltip: "Sifreyi Sifirla (mert123)",
                  ),
                );
              },
            ),
    );
  }
}
