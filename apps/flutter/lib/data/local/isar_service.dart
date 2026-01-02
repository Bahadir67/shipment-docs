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
    final directory = kIsWeb ? null : (await getApplicationSupportDirectory()).path;
    final isar = await Isar.open(
      [
        ProjectSchema,
        FileItemSchema,
        ChecklistItemSchema,
        SyncQueueItemSchema,
        UserProfileSchema
      ],
      directory: directory
    );
    return IsarService._(isar);
  }
}
