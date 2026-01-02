import "package:isar/isar.dart";

import "sync_status.dart";

part "file_item.g.dart";

@collection
class FileItem {
  Id id = Isar.autoIncrement;

  String? serverId;
  String? serverUrl;
  String? thumbnailId;
  String? thumbnailUrl;
  int projectId;
  String? projectServerId;
  String type;
  String? category;
  String fileName;
  String localPath;
  String? thumbnailPath;
  DateTime createdAt = DateTime.now();
  @enumerated
  SyncStatus syncStatus;

  FileItem({
    this.serverId,
    this.serverUrl,
    this.thumbnailId,
    this.thumbnailUrl,
    required this.projectId,
    this.projectServerId,
    required this.type,
    this.category,
    required this.fileName,
    required this.localPath,
    this.thumbnailPath,
    this.syncStatus = SyncStatus.pending
  });
}
