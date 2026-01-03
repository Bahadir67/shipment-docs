import "package:isar/isar.dart";

import "../models/project.dart";
import "../models/sync_status.dart";

class ProjectRepository {
  ProjectRepository(this.isar);

  final Isar isar;

  Future<List<Project>> listAll() async {
    // Only show non-deleted projects
    final all = await isar.projects.where().sortByCreatedAtDesc().findAll();
    return all.where((p) => p.status != "deleted").toList();
  }

  Future<List<Project>> listRecent(int limit) async {
    final all = await isar.projects.where().sortByCreatedAtDesc().findAll();
    return all.where((p) => p.status != "deleted").take(limit).toList();
  }

  Future<List<Project>> listDeleted() async {
    final all = await isar.projects.where().sortByCreatedAtDesc().findAll();
    return all.where((p) => p.status == "deleted").toList();
  }

  Future<void> hardDelete(int id) async {
    await isar.writeTxn(() async {
      await isar.projects.delete(id);
    });
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

  Future<void> markAsDeleted(int id) async {
    await isar.writeTxn(() async {
      final item = await isar.projects.get(id);
      if (item == null) return;
      item.status = "deleted";
      item.syncStatus = SyncStatus.pending; // Needs to be synced to server
      item.updatedAt = DateTime.now();
      await isar.projects.put(item);
    });
  }

  Future<void> upsertRemote(List<Project> remote) async {
    await isar.writeTxn(() async {
      for (final item in remote) {
        // If remote status is deleted, we can either delete locally or mark as deleted
        // Let's mark as deleted to keep sync history or just filter it out in queries.
        
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
          // Do not overwrite detailsSynced status for existing projects
          await isar.projects.put(existing);
        } else {
          // If it's a new project from remote, details are not synced yet
          if (item.status != "deleted") {
            item.syncStatus = SyncStatus.synced;
            item.detailsSynced = false;
            await isar.projects.put(item);
          }
        }
      }
    });
  }
}