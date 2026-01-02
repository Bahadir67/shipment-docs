import "api_client.dart";

class ChecklistApi {
  ChecklistApi({required this.client});

  final ApiClient client;

  Future<List<Map<String, dynamic>>> listItems(String productId) async {
    final response = await client.dio.get("/products/$productId/checklist");
    final data = response.data as Map<String, dynamic>;
    final list = (data["data"] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    return list;
  }

  Future<void> updateItem({
    required String productId,
    required String itemKey,
    required String category,
    required bool completed
  }) async {
    await client.dio.post(
      "/products/$productId/checklist",
      data: {
        "itemKey": itemKey,
        "category": category,
        "completed": completed
      }
    );
  }
}
