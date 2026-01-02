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

  Future<void> save(Project project) async {
    await isar.writeTxn(() async {
      await isar.projects.put(project);
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
