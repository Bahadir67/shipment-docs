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
}
