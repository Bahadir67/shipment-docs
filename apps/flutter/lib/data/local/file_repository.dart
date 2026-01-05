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
        // 1. Try to find by unique Server ID
        FileItem? match;
        if (remote.serverId != null) {
          match = await isar.fileItems
              .filter()
              .projectIdEqualTo(projectId)
              .and()
              .serverIdEqualTo(remote.serverId)
              .findFirst();
        }

        // 2. If not found, try to find by Category (Logic: One photo per category)
        if (match == null && remote.category != null && remote.type == "photo") {
          final candidates = await isar.fileItems
              .filter()
              .projectIdEqualTo(projectId)
              .and()
              .categoryEqualTo(remote.category)
              .findAll();
          
          if (candidates.isNotEmpty) {
            match = candidates.first;
            // CLEANUP: If there are multiple local files for this category, delete duplicates!
            if (candidates.length > 1) {
              for (int i = 1; i < candidates.length; i++) {
                await isar.fileItems.delete(candidates[i].id);
              }
            }
          }
        }

        // 3. If not found, try matching by FileName (Last resort)
        if (match == null) {
           match = await isar.fileItems
              .filter()
              .projectIdEqualTo(projectId)
              .and()
              .fileNameEqualTo(remote.fileName)
              .findFirst();
        }

        if (match != null) {
          // UPDATE
          match.serverId = remote.serverId;
          match.serverUrl = remote.serverUrl;
          match.thumbnailId = remote.thumbnailId;
          match.thumbnailUrl = remote.thumbnailUrl;
          // IMPORTANT: If remote has a different filename (e.g. renamed on server), update it?
          // For now, trust remote filename as source of truth if it has ID
          if (remote.serverId != null) {
             match.fileName = remote.fileName;
          }
          await isar.fileItems.put(match);
        } else {
          // INSERT
          await isar.fileItems.put(remote);
        }
      }
    });
  }
}
