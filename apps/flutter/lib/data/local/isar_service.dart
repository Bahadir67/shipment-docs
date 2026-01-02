import "package:flutter/foundation.dart";
import "package:isar/isar.dart";
import "package:path_provider/path_provider.dart";

import "../models/checklist_item.dart";
import "../models/file_item.dart";
import "../models/project.dart";
import "../models/sync_queue_item.dart";
import "../models/user_profile.dart";

class IsarService {
  IsarService._(this.isar);

  final Isar isar;

  static Future<IsarService> open() async {
    final directory = kIsWeb ? "" : (await getApplicationSupportDirectory()).path;
    final schemas = [
      ProjectSchema,
      FileItemSchema,
      ChecklistItemSchema,
      SyncQueueItemSchema,
      UserProfileSchema
    ];
    final isar = await Isar.open(schemas, directory: directory);
    return IsarService._(isar);
  }
}
