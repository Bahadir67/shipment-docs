import "package:flutter/material.dart";

import "../state/app_scope.dart";

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
    "Yuklemeler"
  ];

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);
    final onlineLabel = appState.isOnline ? "Cevrimici" : "Cevrimdisi";
    return Scaffold(
      appBar: AppBar(
        title: Text(_tabs[_index]),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(onlineLabel)
            )
          )
        ]
      ),
      body: Center(
        child: Text("${_tabs[_index]} (MVP)")
      ),
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
            icon: Icon(Icons.cloud_upload_outlined),
            label: "Yuklemeler"
          )
        ]
      )
    );
  }
}
