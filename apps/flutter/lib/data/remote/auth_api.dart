import "api_client.dart";

class AuthApi {
  AuthApi({required this.client});

  final ApiClient client;

  Future<Map<String, dynamic>> login({
    required String username,
    required String password
  }) async {
    final response = await client.dio.post(
      "/auth/login",
      data: {"username": username, "password": password}
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> me() async {
    final response = await client.dio.get("/auth/me");
    return response.data as Map<String, dynamic>;
  }
}
