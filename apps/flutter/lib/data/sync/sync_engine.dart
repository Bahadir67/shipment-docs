import "dart:convert";

import "package:dio/dio.dart";
import "package:isar/isar.dart";

import "../local/sync_queue_repository.dart";
import "../local/project_repository.dart";
import "../local/file_repository.dart";
import "../models/sync_queue_item.dart";
import "../remote/api_client.dart";
import "../models/project.dart";

class SyncEngine {
  SyncEngine({required this.isar});

  final Isar isar;

  Future<void> syncAll({required String? token}) async {
    if (token == null || token.isEmpty) return;
    final queueRepository = SyncQueueRepository(isar);
    final projectRepository = ProjectRepository(isar);
    final fileRepository = FileRepository(isar);
    final items = await queueRepository.getAll();
    if (items.isEmpty) return;

    final client = ApiClient(token: token);
    for (final item in items) {
      final ok = await _processItem(
        client,
        item,
        projectRepository: projectRepository,
        fileRepository: fileRepository
      );
      if (ok) {
        await queueRepository.remove(item.id);
      } else {
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
    required FileRepository fileRepository
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
        case "checklist_update":
          final productId = data["productId"] as String;
          await client.dio.post(
            "/products/$productId/checklist",
            data: data["payload"]
          );
          return true;
        case "file_upload":
          final localFileId = data["localFileId"] as int;
          final localProjectId = data["localProjectId"] as int;
          final project = await projectRepository.getById(localProjectId);
          final projectServerId = project?.serverId;
          if (projectServerId == null) return false;
          final fileItem = await fileRepository.getById(localFileId);
          if (fileItem == null) return true;
          final form = FormData.fromMap({
            "type": fileItem.type,
            if (fileItem.category != null) "category": fileItem.category,
            "file": await MultipartFile.fromFile(
              fileItem.localPath,
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
    } catch (_) {
      return false;
    }
  }
}
