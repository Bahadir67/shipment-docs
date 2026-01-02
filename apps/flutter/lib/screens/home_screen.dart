import "package:flutter/material.dart";

import "../state/app_scope.dart";
import "tabs/dashboard_tab.dart";
import "tabs/projects_tab.dart";
import "tabs/new_project_tab.dart";
import "tabs/uploads_tab.dart";
import "tabs/checklist_tab.dart";

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  static const _tabs = [
    "Genel Bakis",
    "Projeler",
    "Yeni Proje",
    "Checklist",
    "Yuklemeler"
  ];

  final _pages = const [
    DashboardTab(),
    ProjectsTab(),
    NewProjectTab(),
    ChecklistTab(),
    UploadsTab()
  ];

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);
    final onlineLabel = appState.isOnline ? "Cevrimici" : "Cevrimdisi";
    final projectLabel =
        appState.currentProject != null ? appState.currentProject!.project : "-";
    return Scaffold(
      appBar: AppBar(
        title: Text(_tabs[_index]),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text("$onlineLabel • $projectLabel")
            )
          )
        ]
      ),
      body: _pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            label: "Genel"
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            label: "Projeler"
          ),
          NavigationDestination(
            icon: Icon(Icons.add_box_outlined),
            label: "Yeni"
          ),
          NavigationDestination(
            icon: Icon(Icons.checklist),
            label: "Liste"
          ),
          NavigationDestination(
            icon: Icon(Icons.cloud_upload_outlined),
            label: "Yuklemeler"
          )
        ]
      )
    );
  }
}
