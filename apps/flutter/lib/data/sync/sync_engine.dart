import "dart:convert";

import "package:dio/dio.dart";
import "package:flutter/foundation.dart";
import "package:isar/isar.dart";

import "../local/sync_queue_repository.dart";
import "../local/project_repository.dart";
import "../local/file_repository.dart";
import "../local/checklist_repository.dart";
import "../models/sync_queue_item.dart";
import "../remote/api_client.dart";
import "../models/project.dart";

class SyncEngine {
  SyncEngine({required this.isar});

  final Isar isar;

  Future<void> syncAll({required String? token}) async {
    if (token == null || token.isEmpty) {
      debugPrint("SyncEngine: No token, skipping sync.");
      return;
    }
    final queueRepository = SyncQueueRepository(isar);
    final items = await queueRepository.getAll();
    if (items.isEmpty) {
      debugPrint("SyncEngine: Queue empty.");
      return;
    }

    debugPrint("SyncEngine: Processing ${items.length} items...");
    final client = ApiClient(token: token);
    
    // Pass repos properly
    final projectRepo = ProjectRepository(isar);
    final fileRepo = FileRepository(isar);
    final checklistRepo = ChecklistRepository(isar);

    for (final item in items) {
      debugPrint("SyncEngine: Processing item ${item.type} (ID: ${item.id})");
      final ok = await _processItem(
        client,
        item,
        projectRepository: projectRepo,
        fileRepository: fileRepo,
        checklistRepository: checklistRepo
      );
      if (ok) {
        debugPrint("SyncEngine: Item ${item.id} DONE.");
        await queueRepository.remove(item.id);
      } else {
        debugPrint("SyncEngine: Item ${item.id} FAILED.");
        item.retryCount += 1;
        await queueRepository.update(item);
      }
    }
  }

  Future<void> enqueue({
    required String type,
    required Map<String, dynamic> payload
  }) async {
    final queueRepository = SyncQueueRepository(isar);
    await queueRepository.add(
      SyncQueueItem(
        type: type,
        payload: jsonEncode(payload)
      )
    );
  }

  Future<bool> _processItem(
    ApiClient client,
    SyncQueueItem item, {
    required ProjectRepository projectRepository,
    required FileRepository fileRepository,
    required ChecklistRepository checklistRepository
  }) async {
    try {
      final data = jsonDecode(item.payload) as Map<String, dynamic>;
      switch (item.type) {
        case "project_create":
          final localId = data["localProjectId"] as int?;
          final response = await client.dio.post("/products", data: data);
          final payload = response.data as Map<String, dynamic>;
          final serverId = payload["id"] as String?;
          if (localId != null && serverId != null) {
            await projectRepository.updateServerId(id: localId, serverId: serverId);
          }
          return true;
        case "project_delete":
          final localId = data["localProjectId"] as int?;
          if (localId != null) {
            final project = await projectRepository.getById(localId);
            final serverId = project?.serverId;
            if (serverId != null) {
              await client.dio.delete("/products/$serverId");
            }
          }
          return true;
        case "project_hard_delete":
          final localId = data["localProjectId"] as int?;
          if (localId != null) {
            // Even if local record is gone, we might have stored serverId in payload? 
            // Or we assume we fetch it before deleting local.
            // For hard delete, we usually need serverId directly.
            // Let's assume payload has serverId if local is gone.
            String? serverId = data["serverProjectId"] as String?;
            if (serverId == null && localId != null) {
               final project = await projectRepository.getById(localId);
               serverId = project?.serverId;
            }
            
            if (serverId != null) {
              await client.dio.delete("/products/$serverId?hard=true");
            }
          }
          return true;
        case "project_restore":
          final localId = data["localProjectId"] as int?;
          if (localId != null) {
            final project = await projectRepository.getById(localId);
            final serverId = project?.serverId;
            if (serverId != null) {
              await client.dio.put("/products/$serverId/restore");
            }
          }
          return true;
        case "checklist_update":
          final localProjectId = data["localProjectId"] as int?;
          final project = localProjectId == null
              ? null
              : await projectRepository.getById(localProjectId);
          final projectServerId = project?.serverId;
          if (projectServerId == null) return false;
          await client.dio.post(
            "/products/$projectServerId/checklist",
            data: {
              "itemKey": data["itemKey"],
              "category": data["category"],
              "completed": data["completed"]
            }
          );
          return true;
        case "file_upload":
          final localFileId = data["localFileId"] as int;
          final localProjectId = data["localProjectId"] as int;
          final project = await projectRepository.getById(localProjectId);
          final projectServerId = project?.serverId;
          if (projectServerId == null) return false;
          final fileItem = await fileRepository.getById(localFileId);
          if (fileItem == null || fileItem.localPath == null) return true; // Already synced or path missing, skip
          final form = FormData.fromMap({
            "type": fileItem.type,
            if (fileItem.category != null) "category": fileItem.category,
            "file": await MultipartFile.fromFile(
              fileItem.localPath!, // Non-null asserted here
              filename: fileItem.fileName
            )
          });
          final response = await client.dio.post(
            "/products/$projectServerId/files",
            data: form
          );
          final payload = response.data as Map<String, dynamic>;
          await fileRepository.updateFromRemote(
            id: localFileId,
            serverId: payload["id"] as String,
            serverUrl: payload["fileUrl"] as String?,
            thumbnailId: payload["thumbnailId"] as String?,
            thumbnailUrl: payload["thumbnailUrl"] as String?
          );
          return true;
        default:
          return true;
      }
    } catch (e, stack) {
      debugPrint("SyncEngine Error processing item ${item.type}: $e");
      if (e is DioException) {
        final code = e.response?.statusCode;
        // Unrecoverable errors, delete the item from queue
        if (code == 404 || code == 409) {
          debugPrint("SyncEngine: Unrecoverable error ($code), removing item ${item.id}.");
          return true; // Mark as "processed" to delete from queue
        }
      }
      debugPrint(stack.toString());
      return false;
    }
  }
}
