import "package:flutter/material.dart";
import "../../config/theme.dart";
import "../../data/models/project.dart";
import "../../state/app_scope.dart";
import "../project_detail_screen.dart";
import "dashboard_tab.dart"; // Reuse _ProjectCard logic or structure

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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with Refresh
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 16, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Tüm Kayıtlar",
                style: TextStyle(color: AppTheme.paper.withOpacity(0.5), fontWeight: FontWeight.w500),
              ),
              IconButton(
                onPressed: appState.isOnline ? _refresh : null,
                icon: _refreshing
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh, color: AppTheme.accent),
              )
            ],
          ),
        ),

        // List
        Expanded(
          child: FutureBuilder<List<Project>>(
            future: appState.projectRepository.listAll(),
            builder: (context, snapshot) {
              final items = snapshot.data ?? [];
              if (items.isEmpty) {
                return const Center(child: Text("Kayitli proje bulunamadi.", style: TextStyle(color: Colors.white24)));
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  // We'll use the same card design as dashboard for consistency
                  // Note: Since _ProjectCard was private in DashboardTab, 
                  // I should ideally move it to a shared component.
                  // But for speed, let's just make it accessible or recreate.
                  // Re-using the logic from DashboardTab.
                  return ProjectCardShared(project: items[index]);
                },
              );
            }
          ),
        )
      ],
    );
  }
}

// Quick shared version of the card
class ProjectCardShared extends StatelessWidget {
  final Project project;
  const ProjectCardShared({super.key, required this.project});

  @override
  Widget build(BuildContext context) {
    // Re-use logic from Dashboard's _ProjectCard by calling it if it was public
    // Since I cannot easily split files now, I'll implement a slightly more compact version here.
    final appState = AppScope.of(context);

    return FutureBuilder<Map<String, dynamic>>(
      future: _getStats(context),
      builder: (context, snapshot) {
        final stats = snapshot.data;
        final isComplete = stats?["isComplete"] ?? false;
        final statusColor = isComplete ? Colors.greenAccent : Colors.redAccent;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppTheme.bgAccent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: statusColor.withOpacity(0.2)),
          ),
          child: ListTile(
            onTap: () {
              appState.setCurrentProject(project);
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProjectDetailScreen()));
            },
            leading: Icon(isComplete ? Icons.check_circle : Icons.error_outline, color: statusColor),
            title: Text(project.project, style: const TextStyle(color: AppTheme.paper, fontWeight: FontWeight.bold)),
            subtitle: Text("${project.customer} • ${project.serial}", style: TextStyle(color: AppTheme.paper.withOpacity(0.5), fontSize: 12)),
            trailing: const Icon(Icons.chevron_right, color: Colors.white24),
          ),
        );
      }
    );
  }

  Future<Map<String, dynamic>> _getStats(BuildContext context) async {
    final appState = AppScope.of(context);
    final files = await appState.fileRepository.listByProject(project.id);
    final checklist = await appState.checklistRepository.listByProject(project.id);
    final photoCount = files.where((f) => f.type == "photo").length;
    final checklistDone = checklist.where((c) => c.completed).length;
    final isComplete = photoCount >= 6 && checklist.isNotEmpty && checklistDone == checklist.length;
    return {"isComplete": isComplete};
  }
}