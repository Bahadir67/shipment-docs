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
}
