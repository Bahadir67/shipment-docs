import "dart:io";

import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter_image_compress/flutter_image_compress.dart";
import "package:image_picker/image_picker.dart";
import "package:path/path.dart" as p;
import "package:path_provider/path_provider.dart";

import "../data/models/checklist_item.dart";
import "../data/models/file_item.dart";
import "../state/app_scope.dart";

class ProjectDetailScreen extends StatefulWidget {
  const ProjectDetailScreen({super.key});

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  final _picker = ImagePicker();
  bool _loading = false;

  static const _photoSlots = [
    {"key": "onden", "label": "Onden"},
    {"key": "sagdan", "label": "Sagdan"},
    {"key": "soldan", "label": "Soldan"},
    {"key": "arkadan", "label": "Arkadan"},
    {"key": "etiket", "label": "Etiket"},
    {"key": "genel", "label": "Genel"}
  ];

  Future<String> _resolveProjectDir(int projectId) async {
    if (kIsWeb) return "";
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, "photos", "$projectId"));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir.path;
  }

  Future<String?> _createThumbnail(String sourcePath, String targetPath) async {
    final result = await FlutterImageCompress.compressAndGetFile(
      sourcePath,
      targetPath,
      quality: 70,
      minWidth: 256,
      minHeight: 256
    );
    return result?.path;
  }

  FileItem? _matchSlot(List<FileItem> items, Map<String, String> slot) {
    final key = slot["key"]!;
    final label = slot["label"]!.toLowerCase();
    for (final item in items) {
      final name = item.fileName.toLowerCase();
      final category = (item.category ?? "").toLowerCase();
      if (name.contains(key) || category == label) {
        return item;
      }
    }
    return null;
  }

  Future<void> _captureForSlot({
    required Map<String, String> slot,
    required ImageSource source
  }) async {
    final appState = AppScope.of(context);
    final project = appState.currentProject;
    if (project == null) return;
    setState(() => _loading = true);
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 85
    );
    if (picked == null) {
      setState(() => _loading = false);
      return;
    }
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Web icin dosya kaydi MVP disi."))
      );
      setState(() => _loading = false);
      return;
    }
    final projectDir = await _resolveProjectDir(project.id);
    final ext = p.extension(picked.path).isEmpty ? ".jpg" : p.extension(picked.path);
    final fileName = "${slot["key"]}$ext";
    final targetPath = p.join(projectDir, fileName);
    await File(picked.path).copy(targetPath);
    final thumbPath = p.join(projectDir, "thumb_${slot["key"]}.jpg");
    final thumb = await _createThumbnail(targetPath, thumbPath);

    final fileItem = FileItem(
      projectId: project.id,
      projectServerId: project.serverId,
      type: "photo",
      category: slot["label"],
      fileName: fileName,
      localPath: targetPath,
      thumbnailPath: thumb
    );
    final localFileId = await appState.fileRepository.save(fileItem);
    await appState.syncEngine.enqueue(
      type: "file_upload",
      payload: {
        "localFileId": localFileId,
        "localProjectId": project.id
      }
    );
    if (appState.isOnline) {
      await appState.syncEngine.syncAll(token: appState.user?.token);
    }
    setState(() => _loading = false);
  }

  Future<void> _toggleChecklist(ChecklistItem item, bool value) async {
    final appState = AppScope.of(context);
    item.completed = value;
    item.updatedAt = DateTime.now();
    await appState.checklistRepository.save(item);
    await appState.syncEngine.enqueue(
      type: "checklist_update",
      payload: {
        "localProjectId": item.projectId,
        "itemKey": item.itemKey,
        "category": item.category,
        "completed": item.completed
      }
    );
    if (appState.isOnline) {
      await appState.syncEngine.syncAll(token: appState.user?.token);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);
    final project = appState.currentProject;
    if (project == null) {
      return const Scaffold(
        body: Center(child: Text("Once proje secin."))
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(project.project)
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            "${project.serial} • ${project.customer}",
            style: const TextStyle(fontWeight: FontWeight.w600)
          ),
          const SizedBox(height: 16),
          const Text(
            "Fotograflar",
            style: TextStyle(fontWeight: FontWeight.w600)
          ),
          const SizedBox(height: 8),
          FutureBuilder(
            future: appState.fileRepository.listByProject(project.id),
            builder: (context, snapshot) {
              final items = snapshot.data ?? [];
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12
                ),
                itemCount: _photoSlots.length,
                itemBuilder: (context, index) {
                  final slot = _photoSlots[index];
                  final file = _matchSlot(items, slot);
                  final imagePath = file?.thumbnailPath ?? file?.localPath;
                  return GestureDetector(
                    onTap: _loading
                        ? null
                        : () => _captureForSlot(
                              slot: slot,
                              source: ImageSource.camera
                            ),
                    onLongPress: _loading
                        ? null
                        : () => _captureForSlot(
                              slot: slot,
                              source: ImageSource.gallery
                            ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black12)
                      ),
                      child: imagePath != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                File(imagePath),
                                fit: BoxFit.cover
                              )
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.photo_camera_outlined),
                                const SizedBox(height: 8),
                                Text(slot["label"]!)
                              ]
                            ),
                    ),
                  );
                }
              );
            }
          ),
          const SizedBox(height: 20),
          const Text(
            "Checklist",
            style: TextStyle(fontWeight: FontWeight.w600)
          ),
          const SizedBox(height: 8),
          FutureBuilder(
            future: appState.checklistRepository.listByProject(project.id),
            builder: (context, snapshot) {
              final items = snapshot.data ?? [];
              if (items.isEmpty) {
                return const Text("Checklist yok.");
              }
              return Column(
                children: items
                    .map(
                      (item) => CheckboxListTile(
                        title: Text(item.itemKey.replaceAll("_", " ").toUpperCase()),
                        subtitle: Text(item.category),
                        value: item.completed,
                        onChanged: (value) {
                          if (value == null) return;
                          _toggleChecklist(item, value);
                        }
                      )
                    )
                    .toList()
              );
            }
          ),
          const SizedBox(height: 20),
          const Text(
            "Dosyalar",
            style: TextStyle(fontWeight: FontWeight.w600)
          ),
          const SizedBox(height: 8),
          FutureBuilder(
            future: appState.fileRepository.listByProject(project.id),
            builder: (context, snapshot) {
              final items = snapshot.data ?? [];
              if (items.isEmpty) {
                return const Text("Dosya yok.");
              }
              return Column(
                children: items
                    .map(
                      (item) => ListTile(
                        dense: true,
                        title: Text(item.fileName),
                        subtitle: Text(item.type),
                        trailing: Text(item.syncStatus.name)
                      )
                    )
                    .toList()
              );
            }
          )
        ],
      ),
    );
  }
}
