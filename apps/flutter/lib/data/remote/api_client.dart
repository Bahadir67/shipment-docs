import "package:dio/dio.dart";

import "../../config/app_config.dart";

class ApiClient {
  ApiClient({String? token}) {
    final options = BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30)
    );
    dio = Dio(options);
    if (token != null && token.isNotEmpty) {
      dio.options.headers["Authorization"] = "Bearer $token";
    }
  }

  late final Dio dio;
}
