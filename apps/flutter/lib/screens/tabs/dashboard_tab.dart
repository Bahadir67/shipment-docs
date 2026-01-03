import "package:flutter/material.dart";
import "../../config/theme.dart";
import "../../data/models/project.dart";
import "../../data/models/checklist_item.dart";
import "../../data/models/file_item.dart";
import "../../state/app_scope.dart";
import "../project_detail_screen.dart";

class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);
    
    return FutureBuilder<List<Project>>(
      future: appState.projectRepository.listRecent(10),
      builder: (context, snapshot) {
        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.folder_open, size: 64, color: AppTheme.paper.withOpacity(0.1)),
                const SizedBox(height: 16),
                const Text("Henuz proje bulunmuyor.", style: TextStyle(color: Colors.white54)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final project = items[index];
            return _ProjectCard(project: project);
          },
        );
      },
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final Project project;
  const _ProjectCard({required this.project});

  Future<Map<String, dynamic>> _getStats(BuildContext context) async {
    final appState = AppScope.of(context);
    final files = await appState.fileRepository.listByProject(project.id);
    final checklist = await appState.checklistRepository.listByProject(project.id);
    
    final photoCount = files.where((f) => f.type == "photo").length;
    final checklistDone = checklist.where((c) => c.completed).length;
    final isComplete = photoCount >= 6 && checklist.isNotEmpty && checklistDone == checklist.length;

    return {
      "photos": photoCount,
      "checklist": "$checklistDone / ${checklist.length}",
      "isComplete": isComplete
    };
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);

    return FutureBuilder<Map<String, dynamic>>(
      future: _getStats(context),
      builder: (context, snapshot) {
        final stats = snapshot.data;
        final isComplete = stats?["isComplete"] ?? false;
        final statusColor = isComplete ? Colors.greenAccent : Colors.redAccent;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: AppTheme.bgAccent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: statusColor.withOpacity(0.3),
              width: 1.5
            ),
            boxShadow: [
              BoxShadow(
                color: statusColor.withOpacity(0.05),
                blurRadius: 10,
                spreadRadius: 2
              )
            ]
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              appState.setCurrentProject(project);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProjectDetailScreen())
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  // Side Indicator
                  Container(
                    width: 4,
                    height: 60,
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 20),
                  
                  // Main Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          project.customer,
                          style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          project.project,
                          style: const TextStyle(color: AppTheme.paper, fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "${project.serial} • ${project.year}",
                          style: TextStyle(color: AppTheme.paper.withOpacity(0.5), fontSize: 12),
                        ),
                      ],
                    ),
                  ),

                  // Stats Info
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _StatBadge(
                        icon: Icons.photo_library_outlined,
                        text: "${stats?["photos"] ?? 0} / 6",
                        color: (stats?["photos"] ?? 0) >= 6 ? Colors.greenAccent : Colors.white24,
                      ),
                      const SizedBox(height: 8),
                      _StatBadge(
                        icon: Icons.checklist_rtl_outlined,
                        text: stats?["checklist"] ?? "- / -",
                        color: isComplete ? Colors.greenAccent : Colors.white24,
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StatBadge extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _StatBadge({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color.withOpacity(0.7)),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(color: color.withOpacity(0.9), fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}