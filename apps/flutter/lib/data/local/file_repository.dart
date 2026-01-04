import "package:isar/isar.dart";

import "../models/file_item.dart";

class FileRepository {
  FileRepository(this.isar);

  final Isar isar;

  Future<List<FileItem>> listByProject(int projectId) async {
    return isar.fileItems.filter().projectIdEqualTo(projectId).findAll();
  }

  Future<int> save(FileItem item) async {
    return isar.writeTxn(() async {
      return isar.fileItems.put(item);
    });
  }

  Future<FileItem?> getById(int id) async {
    return isar.fileItems.get(id);
  }

  Future<void> delete(int id) async {
    await isar.writeTxn(() async {
      await isar.fileItems.delete(id);
    });
  }

  Future<void> updateFromRemote({
    required int id,
    required String serverId,
    String? serverUrl,
    String? thumbnailId,
    String? thumbnailUrl
  }) async {
    await isar.writeTxn(() async {
      final item = await isar.fileItems.get(id);
      if (item == null) return;
      item.serverId = serverId;
      item.serverUrl = serverUrl;
      item.thumbnailId = thumbnailId;
      item.thumbnailUrl = thumbnailUrl;
      await isar.fileItems.put(item);
    });
  }

  Future<void> upsertRemote({required int projectId, required List<FileItem> items}) async {
    await isar.writeTxn(() async {
      for (final remote in items) {
        // Find existing local file for this project by category or serverId
        FileItem? existing;
        
        if (remote.serverId != null) {
          existing = await isar.fileItems
              .filter()
              .projectIdEqualTo(projectId)
              .and()
              .serverIdEqualTo(remote.serverId)
              .findFirst();
        }

        // If not found by serverId, try matching by category (for photos taken offline)
        if (existing == null && remote.category != null) {
          existing = await isar.fileItems
              .filter()
              .projectIdEqualTo(projectId)
              .and()
              .categoryEqualTo(remote.category)
              .findFirst();
        }

        if (existing != null) {
          // UPDATE: Preserve local path while updating server info
          existing.serverId = remote.serverId;
          existing.serverUrl = remote.serverUrl;
          existing.thumbnailId = remote.thumbnailId;
          existing.thumbnailUrl = remote.thumbnailUrl;
          // Keep localPath and thumbnailPath as they are on this specific device
          await isar.fileItems.put(existing);
        } else {
          // INSERT: New file from remote that doesn't exist here
          await isar.fileItems.put(remote);
        }
      }
    });
  }
}
