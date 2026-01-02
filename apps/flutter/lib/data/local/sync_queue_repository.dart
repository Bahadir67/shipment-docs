import "package:isar/isar.dart";

import "../models/sync_queue_item.dart";

class SyncQueueRepository {
  SyncQueueRepository(this.isar);

  final Isar isar;

  Future<List<SyncQueueItem>> getAll() async {
    return isar.syncQueueItems.where().findAll();
  }

  Future<void> add(SyncQueueItem item) async {
    await isar.writeTxn(() async {
      await isar.syncQueueItems.put(item);
    });
  }

  Future<void> remove(int id) async {
    await isar.writeTxn(() async {
      await isar.syncQueueItems.delete(id);
    });
  }

  Future<void> update(SyncQueueItem item) async {
    await isar.writeTxn(() async {
      await isar.syncQueueItems.put(item);
    });
  }
}
