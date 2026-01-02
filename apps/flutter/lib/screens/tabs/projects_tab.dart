import "package:flutter/material.dart";

import "../../state/app_scope.dart";
import "../project_detail_screen.dart";

class ProjectsTab extends StatefulWidget {
  const ProjectsTab({super.key});

  @override
  State<ProjectsTab> createState() => _ProjectsTabState();
}

class _ProjectsTabState extends State<ProjectsTab> {
  bool _refreshing = false;

  Future<void> _refresh() async {
    final appState = AppScope.of(context);
    if (_refreshing) return;
    setState(() => _refreshing = true);
    await appState.refreshProjects();
    setState(() => _refreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Expanded(
                child: Text("Tum projeler")
              ),
              IconButton(
                onPressed: appState.isOnline ? _refresh : null,
                icon: _refreshing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2)
                      )
                    : const Icon(Icons.refresh)
              )
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder(
            future: appState.projectRepository.listAll(),
            builder: (context, snapshot) {
              final items = snapshot.data ?? [];
              if (items.isEmpty) {
                return const Center(child: Text("Kayitli proje yok."));
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return ListTile(
                    title: Text(item.project),
                    subtitle: Text("${item.serial} • ${item.customer}"),
                    trailing: Text(item.status),
                    onTap: () {
                      appState.setCurrentProject(item);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ProjectDetailScreen()
                        )
                      );
                    }
                  );
                },
                separatorBuilder: (_, __) => const Divider(),
                itemCount: items.length
              );
            }
          )
        )
      ],
    );
  }
}
