import "dart:async";

import "package:connectivity_plus/connectivity_plus.dart";
import "package:flutter/foundation.dart";
import "package:isar/isar.dart";

import "../data/local/user_repository.dart";
import "../data/models/user_profile.dart";
import "../data/remote/auth_api.dart";

class AppState extends ChangeNotifier {
  AppState({
    required this.isar,
    required this.authApi
  }) {
    userRepository = UserRepository(isar);
  }

  final Isar isar;
  final AuthApi authApi;
  late final UserRepository userRepository;
  StreamSubscription<ConnectivityResult>? _connectivitySub;

  bool isOnline = true;
  bool isReady = false;
  UserProfile? user;

  bool get hasAccess => user != null || !isOnline;

  Future<void> init() async {
    final connectivity = Connectivity();
    isOnline = (await connectivity.checkConnectivity()) != ConnectivityResult.none;
    _connectivitySub = connectivity.onConnectivityChanged.listen((result) {
      final nextOnline = result != ConnectivityResult.none;
      if (nextOnline != isOnline) {
        isOnline = nextOnline;
        notifyListeners();
      }
    });
    user = await userRepository.getCurrent();
    isReady = true;
    notifyListeners();
  }

  Future<bool> login({
    required String username,
    required String password
  }) async {
    if (!isOnline) return false;
    final payload = await authApi.login(username: username, password: password);
    final userPayload = payload["user"] as Map<String, dynamic>;
    final token = payload["token"] as String;
    final profile = UserProfile(
      userId: userPayload["id"] as String,
      username: userPayload["username"] as String,
      role: userPayload["role"] as String,
      token: token
    );
    await userRepository.save(profile);
    user = profile;
    notifyListeners();
    return true;
  }

  Future<void> logout() async {
    await userRepository.clear();
    user = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }
}
