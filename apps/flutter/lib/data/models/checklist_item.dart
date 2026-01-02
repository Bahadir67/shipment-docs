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
  DateTime updatedAt;
  SyncStatus syncStatus;

  ChecklistItem({
    this.serverId,
    required this.projectId,
    this.projectServerId,
    required this.itemKey,
    required this.category,
    this.completed = false,
    DateTime? updatedAt,
    this.syncStatus = SyncStatus.pending
  }) : updatedAt = updatedAt ?? DateTime.now();
}
