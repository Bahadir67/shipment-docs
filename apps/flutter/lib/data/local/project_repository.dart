import "package:isar/isar.dart";

import "../models/project.dart";
import "../models/sync_status.dart";

class ProjectRepository {
  ProjectRepository(this.isar);

  final Isar isar;

  Future<List<Project>> listAll() async {
    return isar.projects.where().sortByCreatedAtDesc().findAll();
  }

  Future<List<Project>> listRecent(int limit) async {
    return isar.projects.where().sortByCreatedAtDesc().limit(limit).findAll();
  }

  Future<int> save(Project project) async {
    return isar.writeTxn(() async {
      return isar.projects.put(project);
    });
  }

  Future<Project?> getById(int id) async {
    return isar.projects.get(id);
  }

  Future<void> updateServerId({required int id, required String serverId}) async {
    await isar.writeTxn(() async {
      final item = await isar.projects.get(id);
      if (item == null) return;
      item.serverId = serverId;
      item.syncStatus = SyncStatus.synced;
      item.updatedAt = DateTime.now();
      await isar.projects.put(item);
    });
  }

  Future<void> upsertRemote(List<Project> remote) async {
    await isar.writeTxn(() async {
      for (final item in remote) {
        final existing = await isar.projects
            .filter()
            .serverIdEqualTo(item.serverId)
            .findFirst();
        if (existing != null) {
          existing.serial = item.serial;
          existing.customer = item.customer;
          existing.project = item.project;
          existing.productType = item.productType;
          existing.year = item.year;
          existing.status = item.status;
          existing.updatedAt = item.updatedAt;
          existing.syncStatus = SyncStatus.synced;
          await isar.projects.put(existing);
        } else {
          item.syncStatus = SyncStatus.synced;
          await isar.projects.put(item);
        }
      }
    });
  }
}
