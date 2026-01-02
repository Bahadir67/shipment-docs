import "dart:io";

import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter_image_compress/flutter_image_compress.dart";
import "package:image_picker/image_picker.dart";
import "package:path/path.dart" as p;
import "package:path_provider/path_provider.dart";

import "../../data/models/file_item.dart";
import "../../state/app_scope.dart";

class UploadsTab extends StatefulWidget {
  const UploadsTab({super.key});

  @override
  State<UploadsTab> createState() => _UploadsTabState();
}

class _UploadsTabState extends State<UploadsTab> {
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

  Future<void> _captureForSlot({
    required Map<String, String> slot,
    required ImageSource source
  }) async {
    final appState = AppScope.of(context);
    final project = appState.currentProject;
    if (project == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Once proje secin."))
      );
      return;
    }
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

  Future<void> _pickDocument() async {
    final appState = AppScope.of(context);
    final project = appState.currentProject;
    if (project == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Once proje secin."))
      );
      return;
    }
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Web icin dosya kaydi MVP disi."))
      );
      return;
    }
    final picked = await _picker.pickMedia();
    if (picked == null) return;
    final projectDir = await _resolveProjectDir(project.id);
    final fileName = p.basename(picked.path);
    final targetPath = p.join(projectDir, fileName);
    await File(picked.path).copy(targetPath);
    final fileItem = FileItem(
      projectId: project.id,
      projectServerId: project.serverId,
      type: "doc",
      category: null,
      fileName: fileName,
      localPath: targetPath
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

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);
    final project = appState.currentProject;
    if (project == null) {
      return const Center(child: Text("Once proje secin."));
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  "Proje: ${project.project}",
                  style: const TextStyle(fontWeight: FontWeight.w600)
                )
              ),
              IconButton(
                onPressed: _loading
                    ? null
                    : () => _captureForSlot(
                          slot: _photoSlots.first,
                          source: ImageSource.camera
                        ),
                icon: const Icon(Icons.photo_camera)
              ),
              IconButton(
                onPressed: _loading ? null : _pickDocument,
                icon: const Icon(Icons.attach_file)
              )
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder(
            future: appState.fileRepository.listByProject(project.id),
            builder: (context, snapshot) {
              final items = snapshot.data ?? [];
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  GridView.builder(
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
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Dosyalar",
                    style: TextStyle(fontWeight: FontWeight.w600)
                  ),
                  const SizedBox(height: 8),
                  if (items.isEmpty)
                    const Text("Dosya yok.")
                  else
                    ...items.map((item) => ListTile(
                          dense: true,
                          title: Text(item.fileName),
                          subtitle: Text(item.type),
                          trailing: Text(item.syncStatus.name)
                        ))
                ],
              );
            }
          ),
        )
      ],
    );
  }
}
