import "api_client.dart";

class ProjectsApi {
  ProjectsApi({required this.client});

  final ApiClient client;

  Future<List<Map<String, dynamic>>> listProjects() async {
    final response = await client.dio.get("/products");
    final data = response.data as Map<String, dynamic>;
    final list = (data["data"] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    return list;
  }

  Future<void> deleteProject(String serverId, {bool hard = false}) async {
    await client.dio.delete("/products/$serverId${hard ? '?hard=true' : ''}");
  }

  Future<void> restoreProject(String serverId) async {
    await client.dio.put("/products/$serverId/restore");
  }

  Future<List<Map<String, dynamic>>> listFiles(String serverId) async {
    final response = await client.dio.get("/products/$serverId/files");
    final data = response.data as Map<String, dynamic>;
    final list = (data["data"] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    return list;
  }
}
