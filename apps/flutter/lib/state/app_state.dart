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
import "../data/models/file_item.dart";
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
    if (project != null && isOnline && !project.detailsSynced) {
      refreshProjectDetails(project);
    }
    notifyListeners();
  }

  Future<void> init() async {
    final connectivity = Connectivity();
    final result = await connectivity.checkConnectivity();
    // If result contains 'none', we are OFFLINE. So isOnline should be false.
    isOnline = !result.contains(ConnectivityResult.none);
    
    _connectivitySub = connectivity.onConnectivityChanged.listen((result) {
      final nextOnline = !result.contains(ConnectivityResult.none);
      if (nextOnline != isOnline) {
        isOnline = nextOnline;
        if (isOnline) {
          syncAllData();
        }
        notifyListeners();
      }
    });
    user = await userRepository.getCurrent();
    if (isOnline) {
      await syncAllData();
    }
    isReady = true;
    notifyListeners();
  }
  
  // ... (syncAllData remains same)

  // ... (login remains same)

  // ... (refreshProjects remains same, but wait, we need to fix ProjectRepository separately)

  Future<void> refreshProjectDetails(Project project) async {
    if (!isOnline || user?.token == null || project.serverId == null) return;
    
    // NO CHECKLIST FETCH NEEDED (It's part of Project model now)

    // Fetch files
    try {
      final projectsApi = ProjectsApi(client: ApiClient(token: user!.token));
      final filesData = await projectsApi.listFiles(project.serverId!);
      final fileItems = filesData.map<FileItem>((entry) {
        return FileItem(
          serverId: entry["id"] as String,
          projectId: project.id,
          projectServerId: project.serverId,
          type: entry["type"] as String,
          category: entry["category"] as String?,
          fileName: entry["fileId"] as String,
          serverUrl: entry["fileUrl"] as String?,
          thumbnailId: entry["thumbnailId"] as String?,
          thumbnailUrl: entry["thumbnailUrl"] as String?
        );
      }).toList();
      await fileRepository.upsertRemote(projectId: project.id, items: fileItems);

      // Mark as synced
      project.detailsSynced = true;
      await projectRepository.save(project);
      notifyListeners();
    } catch (e) {
      debugPrint("refreshProjectDetails error: $e");
    }
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