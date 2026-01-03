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

  Future<void> changePassword(String currentPassword, String newPassword) async {
    await client.dio.post(
      "/auth/change-password",
      data: {"currentPassword": currentPassword, "newPassword": newPassword}
    );
  }

  Future<List<Map<String, dynamic>>> listUsers() async {
    final response = await client.dio.get("/auth/users");
    final data = response.data as Map<String, dynamic>;
    return (data["data"] as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<void> createUser(String username, String password, String role) async {
    await client.dio.post("/auth/users", data: {
      "username": username,
      "password": password,
      "role": role
    });
  }

  Future<void> resetPassword(String userId) async {
    await client.dio.post("/auth/users/$userId/reset-password", data: {
      "password": "mert123"
    });
  }
}
