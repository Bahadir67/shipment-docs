import "package:flutter/material.dart";

import "../../data/models/checklist_item.dart";
import "../../state/app_scope.dart";

class ChecklistTab extends StatefulWidget {
  const ChecklistTab({super.key});

  @override
  State<ChecklistTab> createState() => _ChecklistTabState();
}

class _ChecklistTabState extends State<ChecklistTab> {
  bool _refreshing = false;

  Future<void> _refresh() async {
    final appState = AppScope.of(context);
    final project = appState.currentProject;
    if (project == null) return;
    setState(() => _refreshing = true);
    await appState.refreshChecklist(project);
    setState(() => _refreshing = false);
  }

  Future<void> _toggle(ChecklistItem item, bool value) async {
    final appState = AppScope.of(context);
    item.completed = value;
    item.updatedAt = DateTime.now();
    await appState.checklistRepository.save(item);
    await appState.syncEngine.enqueue(
      type: "checklist_update",
      payload: {
        "localProjectId": item.projectId,
        "itemKey": item.itemKey,
        "category": item.category,
        "completed": item.completed
      }
    );
    if (appState.isOnline) {
      await appState.syncEngine.syncAll(token: appState.user?.token);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);
    final project = appState.currentProject;
    if (project == null) {
      return const Center(child: Text("Once proje secin."));
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text("Checklist: ${project.project}")
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
            future: appState.checklistRepository.listByProject(project.id),
            builder: (context, snapshot) {
              final items = snapshot.data ?? [];
              if (items.isEmpty) {
                return const Center(child: Text("Checklist yok."));
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return CheckboxListTile(
                    title: Text(item.itemKey.replaceAll("_", " ").toUpperCase()),
                    subtitle: Text(item.category),
                    value: item.completed,
                    onChanged: (value) {
                      if (value == null) return;
                      _toggle(item, value);
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
