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
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _refresh());
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    
    final appState = AppScope.of(context);
    try {
      final list = await appState.authApi.listUsers();
      setState(() => _users = list);
    } catch (e) {
      setState(() => _errorMessage = "Kullanici listesi alinamadi. Yetkiniz olmayabilir.");
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _showAddUserDialog() async {
    final nameController = TextEditingController();
    String selectedRole = "user";

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.paper,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          top: 24, left: 24, right: 24
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Yeni Personel Tanimla", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.ink)),
            const SizedBox(height: 24),
            TextField(
              controller: nameController,
              autofocus: true,
              style: const TextStyle(color: AppTheme.ink),
              decoration: const InputDecoration(
                labelText: "Kullanici Adi",
                hintText: "Örn: mehmet_qc",
              ),
            ),
            const SizedBox(height: 16),
            const Text("Yetki Seviyesi", style: TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text("Standart Kullanici")),
                    selected: selectedRole == "user",
                    onSelected: (s) => setState(() => selectedRole = "user"),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text("Yonetici (Admin)")),
                    selected: selectedRole == "admin",
                    onSelected: (s) => setState(() => selectedRole = "admin"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () async {
                  if (nameController.text.trim().isEmpty) return;
                  final appState = AppScope.of(context);
                  try {
                    await appState.authApi.createUser(nameController.text.trim(), "mert123", selectedRole);
                    if (context.mounted) {
                      Navigator.pop(context);
                      _refresh();
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Personel basariyla eklendi.")));
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Hata: Bu kullanici zaten var olabilir.")));
                  }
                },
                child: const Text("TANIMLA"),
              ),
            ),
            const Center(child: Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text("Baslangic sifresi: mert123", style: TextStyle(fontSize: 11, color: Colors.grey)),
            )),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F8),
      appBar: AppBar(
        title: const Text("Personel Yonetimi"),
        actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh))],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddUserDialog,
        label: const Text("Yeni Personel"),
        icon: const Icon(Icons.person_add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(_errorMessage!, style: const TextStyle(color: AppTheme.ink)),
                    TextButton(onPressed: _refresh, child: const Text("Tekrar Dene"))
                  ],
                ))
              : _users.isEmpty
                  ? const Center(child: Text("Henuz personel tanimlanmamis."))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _users.length,
                      itemBuilder: (context, index) {
                        final u = _users[index];
                        final isAdmin = u["role"] == "admin";
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey.shade200)
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isAdmin ? Colors.red.shade100 : Colors.blue.shade100,
                              child: Icon(isAdmin ? Icons.admin_panel_settings : Icons.person, color: isAdmin ? Colors.red : Colors.blue),
                            ),
                            title: Text(u["username"], style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.ink)),
                            subtitle: Text(isAdmin ? "Yonetici" : "Saha Personeli", style: TextStyle(color: Colors.grey.shade600)),
                            trailing: PopupMenuButton(
                              itemBuilder: (context) => [
                                const PopupMenuItem(value: "reset", child: Text("Sifreyi Sifirla (mert123)")),
                              ],
                              onSelected: (v) {
                                if (v == "reset") {
                                  // Reset password logic
                                  AppScope.of(context).authApi.resetPassword(u["id"]);
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sifre sifirlandi: mert123")));
                                }
                              },
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}