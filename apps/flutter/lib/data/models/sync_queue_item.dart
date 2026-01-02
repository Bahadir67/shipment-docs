import "package:isar/isar.dart";

part "sync_queue_item.g.dart";

@collection
class SyncQueueItem {
  Id id = Isar.autoIncrement;

  String type;
  String payload;
  DateTime createdAt;
  int retryCount;

  SyncQueueItem({
    required this.type,
    required this.payload,
    DateTime? createdAt,
    this.retryCount = 0
  }) : createdAt = createdAt ?? DateTime.now();
}
