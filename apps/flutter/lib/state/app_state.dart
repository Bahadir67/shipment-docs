import "dart:async";

import "package:connectivity_plus/connectivity_plus.dart";
import "package:flutter/foundation.dart";
import "package:isar/isar.dart";

import "../data/local/user_repository.dart";
import "../data/local/project_repository.dart";
import "../data/local/file_repository.dart";
import "../data/models/user_profile.dart";
import "../data/models/project.dart";
import "../data/remote/auth_api.dart";
import "../data/remote/projects_api.dart";
import "../data/sync/sync_engine.dart";

class AppState extends ChangeNotifier {
  AppState({
    required this.isar,
    required this.authApi
  }) {
    userRepository = UserRepository(isar);
    projectRepository = ProjectRepository(isar);
    fileRepository = FileRepository(isar);
    syncEngine = SyncEngine(isar: isar);
  }

  final Isar isar;
  final AuthApi authApi;
  late final ProjectRepository projectRepository;
  late final FileRepository fileRepository;
  late final UserRepository userRepository;
  late final SyncEngine syncEngine;
  StreamSubscription<ConnectivityResult>? _connectivitySub;

  bool isOnline = true;
  bool isReady = false;
  UserProfile? user;
  Project? currentProject;

  bool get hasAccess => user != null || !isOnline;

  void setCurrentProject(Project? project) {
    currentProject = project;
    notifyListeners();
  }

  Future<void> init() async {
    final connectivity = Connectivity();
    isOnline = (await connectivity.checkConnectivity()) != ConnectivityResult.none;
    _connectivitySub = connectivity.onConnectivityChanged.listen((result) {
      final nextOnline = result != ConnectivityResult.none;
      if (nextOnline != isOnline) {
        isOnline = nextOnline;
        if (isOnline) {
          syncEngine.syncAll(token: user?.token);
        }
        notifyListeners();
      }
    });
    user = await userRepository.getCurrent();
    if (user != null && isOnline) {
      await refreshProjects();
    }
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
    await refreshProjects();
    await syncEngine.syncAll(token: profile.token);
    notifyListeners();
    return true;
  }

  Future<void> refreshProjects() async {
    if (!isOnline || user?.token == null) return;
    final api = ProjectsApi(client: ApiClient(token: user!.token));
    final data = await api.listProjects();
    final recent = data.take(5).map((entry) {
      final project = Project(
        serverId: entry["id"] as String,
        serial: entry["serial"] as String,
        customer: entry["customer"] as String,
        project: entry["project"] as String,
        productType: entry["productType"] as String?,
        year: entry["year"] as int,
        status: entry["status"] as String? ?? "open"
      );
      project.createdAt = DateTime.tryParse(entry["createdAt"] as String? ?? "") ??
          DateTime.now();
      project.updatedAt = DateTime.tryParse(entry["updatedAt"] as String? ?? "") ??
          DateTime.now();
      return project;
    }).toList();
    await projectRepository.upsertRemote(recent);
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
