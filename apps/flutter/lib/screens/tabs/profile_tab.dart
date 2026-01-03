import "package:flutter/material.dart";
import "../../config/theme.dart";
import "../../state/app_scope.dart";
import "../../data/local/sync_queue_repository.dart";
import "../deleted_projects_screen.dart";
import "../change_password_screen.dart";
import "../admin_users_screen.dart";

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _refreshSyncStatus();
  }

  Future<void> _refreshSyncStatus() async {
    final appState = AppScope.of(context);
    final repo = SyncQueueRepository(appState.isar);
    final count = await repo.count();
    if (mounted) {
      setState(() => _pendingCount = count);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);
    final user = appState.user;
    final isAdmin = user?.role == "admin";

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: ListView(
            padding: const EdgeInsets.all(24),
            shrinkWrap: true,
            children: [
              const CircleAvatar(
                radius: 40,
                backgroundColor: AppTheme.accent,
                child: Icon(Icons.person, size: 40, color: AppTheme.ink),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  user?.username ?? "Kullanici",
                  style: const TextStyle(
                    fontSize: 24, 
                    fontWeight: FontWeight.bold,
                    color: AppTheme.paper
                  )
                ),
              ),
              Center(
                child: Text(
                  "Rol: ${user?.role ?? '-'}",
                  style: TextStyle(color: AppTheme.paper.withOpacity(0.6))
                ),
              ),
              const SizedBox(height: 32),
              
              // Sync Status Card
              Card(
                color: AppTheme.bgAccent,
                child: ListTile(
                  leading: Icon(
                    _pendingCount > 0 ? Icons.sync_problem : Icons.check_circle,
                    color: _pendingCount > 0 ? Colors.orange : Colors.greenAccent
                  ),
                  title: const Text("Senkronizasyon", style: TextStyle(color: AppTheme.paper)),
                  subtitle: Text(
                    _pendingCount > 0 
                      ? "$_pendingCount islem kuyrukta bekliyor."
                      : "Her sey guncel.",
                    style: TextStyle(color: AppTheme.paper.withOpacity(0.6))
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.refresh, color: AppTheme.accent),
                    onPressed: () async {
                      await appState.syncEngine.syncAll(token: user?.token);
                      _refreshSyncStatus();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Senkronizasyon tetiklendi."))
                      );
                    },
                  ),
                ),
              ),
              
              const SizedBox(height: 24),

              // Admin Tools
              if (isAdmin) ...[
                const Text("Yonetici Araclari", style: TextStyle(color: AppTheme.paper, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ListTile(
                  tileColor: AppTheme.bgAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  leading: const Icon(Icons.delete_sweep, color: Colors.orangeAccent),
                  title: const Text("Geri Donusum Kutusu", style: TextStyle(color: AppTheme.paper)),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const DeletedProjectsScreen()));
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  tileColor: AppTheme.bgAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  leading: const Icon(Icons.people, color: Colors.blueAccent),
                  title: const Text("Kullanici Yonetimi", style: TextStyle(color: AppTheme.paper)),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminUsersScreen()));
                  },
                ),
                const SizedBox(height: 24),
              ],

              // General Settings
              const Text("Hesap", style: TextStyle(color: AppTheme.paper, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ListTile(
                tileColor: AppTheme.bgAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                leading: const Icon(Icons.key, color: AppTheme.paper),
                title: const Text("Sifre Degistir", style: TextStyle(color: AppTheme.paper)),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordScreen()));
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                tileColor: AppTheme.bgAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                leading: const Icon(Icons.logout, color: Colors.redAccent),
                title: const Text("Cikis Yap", style: TextStyle(color: AppTheme.paper)),
                onTap: () => appState.logout(),
              ),
              
              const SizedBox(height: 16),
              Center(
                child: Text(
                  "Versiyon: 1.1.0",
                  style: TextStyle(color: AppTheme.paper.withOpacity(0.3), fontSize: 12)
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
