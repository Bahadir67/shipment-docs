import "dart:async";

import "package:connectivity_plus/connectivity_plus.dart";
import "package:flutter/foundation.dart";
import "package:isar/isar.dart";

import "../data/local/user_repository.dart";
import "../data/local/project_repository.dart";
import "../data/local/file_repository.dart";
import "../data/local/checklist_repository.dart";
import "../data/models/user_profile.dart";
import "../data/models/project.dart";
import "../data/models/checklist_item.dart";
import "../data/remote/api_client.dart";
import "../data/remote/auth_api.dart";
import "../data/remote/projects_api.dart";
import "../data/remote/checklist_api.dart";
import "../data/sync/sync_engine.dart";

class AppState extends ChangeNotifier {
  AppState({
    required this.isar,
    required this.authApi
  }) {
    userRepository = UserRepository(isar);
    projectRepository = ProjectRepository(isar);
    fileRepository = FileRepository(isar);
    checklistRepository = ChecklistRepository(isar);
    syncEngine = SyncEngine(isar: isar);
  }

  final Isar isar;
  final AuthApi authApi;
  late final ProjectRepository projectRepository;
  late final FileRepository fileRepository;
  late final ChecklistRepository checklistRepository;
  late final UserRepository userRepository;
  late final SyncEngine syncEngine;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  bool isOnline = true;
  bool isReady = false;
  UserProfile? user;
  Project? currentProject;

  bool get hasAccess => user != null || !isOnline;

  void setCurrentProject(Project? project) {
    currentProject = project;
    if (project != null && isOnline) {
      refreshChecklist(project);
    }
    notifyListeners();
  }

  Future<void> init() async {
    final connectivity = Connectivity();
    isOnline = (await connectivity.checkConnectivity()) != ConnectivityResult.none;
    _connectivitySub = connectivity.onConnectivityChanged.listen((result) {
      final nextOnline = result.isNotEmpty &&
          result.any((entry) => entry != ConnectivityResult.none);
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
    try {
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
    } catch (_) {
      return false;
    }
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

  Future<void> refreshChecklist(Project project) async {
    if (!isOnline || user?.token == null || project.serverId == null) return;
    final api = ChecklistApi(client: ApiClient(token: user!.token));
    final data = await api.listItems(project.serverId!);
    final List<ChecklistItem> items = data.map<ChecklistItem>((entry) {
      return ChecklistItem(
        serverId: entry["id"] as String?,
        projectId: project.id,
        projectServerId: project.serverId,
        itemKey: entry["itemKey"] as String,
        category: entry["category"] as String,
        completed: entry["completed"] as bool? ?? false
      );
    }).toList();
    await checklistRepository.upsertRemote(projectId: project.id, items: items);
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
