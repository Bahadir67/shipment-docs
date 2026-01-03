import "dart:io";
import "package:flutter/material.dart";
import "package:path_provider/path_provider.dart";
import "package:path/path.dart" as p;
import "../config/theme.dart";
import "../state/app_scope.dart";
import "../data/models/project.dart";

class DeletedProjectsScreen extends StatefulWidget {
  const DeletedProjectsScreen({super.key});

  @override
  State<DeletedProjectsScreen> createState() => _DeletedProjectsScreenState();
}

class _DeletedProjectsScreenState extends State<DeletedProjectsScreen> {
  bool _loading = false;

  Future<List<Project>> _getDeletedProjects() async {
    final appState = AppScope.of(context);
    // Fetch all locally, filtering for deleted status
    // Note: ProjectRepository currently filters OUT deleted projects in listAll/listRecent.
    // We need a method to specifically get deleted ones or raw access.
    // We can use the Isar instance directly or add a method to Repo.
    // For now, let's use Isar directly here for simplicity or update Repo.
    // Updating Repo is cleaner. Let's assume we add listDeleted() to Repo.
    return appState.projectRepository.listDeleted();
  }

  Future<void> _restoreProject(Project project) async {
    final appState = AppScope.of(context);
    setState(() => _loading = true);
    
    // 1. Update Local
    project.status = "open";
    await appState.projectRepository.save(project);

    // 2. Sync
    await appState.syncEngine.enqueue(
      type: "project_restore",
      payload: {"localProjectId": project.id}
    );
    
    if (appState.isOnline) {
      await appState.syncEngine.syncAll(token: appState.user?.token);
    }
    
    setState(() => _loading = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Proje geri alindi.")));
  }

  Future<void> _hardDeleteProject(Project project) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("KALICI OLARAK SIL?"),
        content: const Text("Bu islem geri alinamaz. Proje ve tum verileri hem cihazdan hem sunucudan tamamen silinecek."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Iptal")),
          TextButton(onPressed: () => Navigator.pop(context, true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text("KALICI SIL")),
        ],
      )
    );

    if (confirmed != true) return;

    final appState = AppScope.of(context);
    setState(() => _loading = true);

    // 1. Delete Local Files
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, "photos", "${project.id}"));
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }

    // 2. Sync (Hard Delete) - Needs serverId
    // We must queue this BEFORE deleting the local record if we rely on local record for serverId
    // Or pass serverId in payload
    await appState.syncEngine.enqueue(
      type: "project_hard_delete",
      payload: {
        "localProjectId": project.id,
        "serverProjectId": project.serverId
      }
    );

    // 3. Delete Local DB Record
    await appState.projectRepository.hardDelete(project.id);

    if (appState.isOnline) {
      await appState.syncEngine.syncAll(token: appState.user?.token);
    }

    setState(() => _loading = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Proje kalici olarak silindi.")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Geri Donusum Kutusu")),
      body: FutureBuilder<List<Project>>(
        future: _getDeletedProjects(),
        builder: (context, snapshot) {
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return const Center(child: Text("Silinen proje yok."));
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                title: Text(item.project, style: const TextStyle(decoration: TextDecoration.lineThrough)),
                subtitle: Text(item.serial),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.restore, color: Colors.green),
                      onPressed: _loading ? null : () => _restoreProject(item),
                      tooltip: "Geri Al",
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_forever, color: Colors.red),
                      onPressed: _loading ? null : () => _hardDeleteProject(item),
                      tooltip: "Kalici Sil",
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
