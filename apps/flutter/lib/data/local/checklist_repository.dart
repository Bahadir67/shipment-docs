import "package:isar/isar.dart";

import "../models/checklist_item.dart";
import "../models/sync_status.dart";

class ChecklistRepository {
  ChecklistRepository(this.isar);

  final Isar isar;

  Future<List<ChecklistItem>> listByProject(int projectId) async {
    return isar.checklistItems.filter().projectIdEqualTo(projectId).findAll();
  }

  Future<void> save(ChecklistItem item) async {
    await isar.writeTxn(() async {
      await isar.checklistItems.put(item);
    });
  }

  Future<void> upsertRemote({
    required int projectId,
    required List<ChecklistItem> items
  }) async {
    await isar.writeTxn(() async {
      await isar.checklistItems.filter().projectIdEqualTo(projectId).deleteAll();
      for (final item in items) {
        item.projectId = projectId;
        item.syncStatus = SyncStatus.synced;
        await isar.checklistItems.put(item);
      }
    });
  }
}
