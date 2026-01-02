import "dart:convert";

import "package:isar/isar.dart";

import "../local/sync_queue_repository.dart";
import "../models/sync_queue_item.dart";
import "../remote/api_client.dart";

class SyncEngine {
  SyncEngine({required this.isar});

  final Isar isar;

  Future<void> syncAll({required String? token}) async {
    if (token == null || token.isEmpty) return;
    final queueRepository = SyncQueueRepository(isar);
    final items = await queueRepository.getAll();
    if (items.isEmpty) return;

    final client = ApiClient(token: token);
    for (final item in items) {
      final ok = await _processItem(client, item);
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

  Future<bool> _processItem(ApiClient client, SyncQueueItem item) async {
    try {
      final data = jsonDecode(item.payload) as Map<String, dynamic>;
      switch (item.type) {
        case "project_create":
          await client.dio.post("/products", data: data);
          return true;
        case "checklist_update":
          final productId = data["productId"] as String;
          await client.dio.post(
            "/products/$productId/checklist",
            data: data["payload"]
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
