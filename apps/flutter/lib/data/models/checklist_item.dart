import "package:isar/isar.dart";

import "sync_status.dart";

part "checklist_item.g.dart";

@collection
class ChecklistItem {
  Id id = Isar.autoIncrement;

  String? serverId;
  int projectId;
  String? projectServerId;
  String itemKey;
  String category;
  bool completed;
  DateTime updatedAt = DateTime.now();
  @enumerated
  SyncStatus syncStatus;

  ChecklistItem({
    this.serverId,
    required this.projectId,
    this.projectServerId,
    required this.itemKey,
    required this.category,
    this.completed = false,
    this.syncStatus = SyncStatus.pending
  });
}
