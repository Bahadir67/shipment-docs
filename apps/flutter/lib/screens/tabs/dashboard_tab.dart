import "package:flutter/material.dart";

import "../../state/app_scope.dart";

class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);
    return FutureBuilder(
      future: appState.projectRepository.listRecent(5),
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
              trailing: Text(item.status)
            );
          },
          separatorBuilder: (_, __) => const Divider(),
          itemCount: items.length
        );
      }
    );
  }
}
