import "package:isar/isar.dart";

import "sync_status.dart";

part "project.g.dart";

@collection
class Project {
  Id id = Isar.autoIncrement;

  String? serverId;
  String serial;
  String customer;
  String project;
  String? productType;
  int year;
  String status;
  DateTime createdAt = DateTime.now();
  DateTime updatedAt = DateTime.now();
  @enumerated
  SyncStatus syncStatus;
  bool detailsSynced;

  Project({
    this.serverId,
    required this.serial,
    required this.customer,
    required this.project,
    this.productType,
    required this.year,
    this.status = "open",
    this.syncStatus = SyncStatus.pending,
    this.detailsSynced = false,
  });
}
