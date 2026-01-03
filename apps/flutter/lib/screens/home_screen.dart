import "package:flutter/material.dart";
import "../config/theme.dart";
import "../state/app_scope.dart";
import "tabs/dashboard_tab.dart";
import "tabs/projects_tab.dart";
import "tabs/new_project_tab.dart";
import "tabs/profile_tab.dart";

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
    "Ayarlar"
  ];

  final _pages = const [
    DashboardTab(),
    ProjectsTab(),
    NewProjectTab(),
    ProfileTab()
  ];

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);
    final width = MediaQuery.of(context).size.width;
    final isTablet = width > 700;

    final projectLabel = appState.currentProject != null 
        ? appState.currentProject!.project 
        : "Proje Secilmedi";

    const destinations = [
      NavigationDestination(
        icon: Icon(Icons.dashboard_outlined),
        selectedIcon: Icon(Icons.dashboard),
        label: "Genel"
      ),
      NavigationDestination(
        icon: Icon(Icons.folder_outlined),
        selectedIcon: Icon(Icons.folder),
        label: "Projeler"
      ),
      NavigationDestination(
        icon: Icon(Icons.add_box_outlined),
        selectedIcon: Icon(Icons.add_box),
        label: "Yeni"
      ),
      NavigationDestination(
        icon: Icon(Icons.settings_outlined),
        selectedIcon: Icon(Icons.settings),
        label: "Ayarlar"
      ),
    ];

    final railDestinations = destinations.map((d) => NavigationRailDestination(
      icon: d.icon,
      selectedIcon: d.selectedIcon,
      label: Text(d.label),
    )).toList();

    return Scaffold(
      body: Row(
        children: [
          if (isTablet)
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: (value) => setState(() => _index = value),
              labelType: NavigationRailLabelType.all,
              destinations: railDestinations,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.accent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text("SD", style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.ink)),
                    ),
                  ],
                ),
              ),
            ),
          
          Expanded(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 40, 24, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _tabs[_index],
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.paper
                        )
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20)
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 8, height: 8,
                              decoration: BoxDecoration(
                                color: appState.isOnline ? const Color(0xFF6EF5A7) : AppTheme.muted,
                                shape: BoxShape.circle,
                                boxShadow: appState.isOnline ? [
                                  BoxShadow(color: const Color(0xFF6EF5A7).withOpacity(0.4), blurRadius: 4, spreadRadius: 2)
                                ] : []
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              projectLabel,
                              style: const TextStyle(color: AppTheme.paperSoft, fontSize: 12, fontWeight: FontWeight.w500)
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
                Expanded(child: _pages[_index]),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: isTablet ? null : NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: destinations,
      ),
    );
  }
}
