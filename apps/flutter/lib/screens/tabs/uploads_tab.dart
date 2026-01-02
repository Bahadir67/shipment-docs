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

  Future<void> _pickImage({required bool fromCamera}) async {
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
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
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
    final fileName = p.basename(picked.path);
    final targetPath = p.join(projectDir, fileName);
    await File(picked.path).copy(targetPath);
    final thumbPath = p.join(projectDir, "thumb_$fileName");
    final thumb = await _createThumbnail(targetPath, thumbPath);

    final fileItem = FileItem(
      projectId: project.id,
      projectServerId: project.serverId,
      type: "photo",
      category: "Onden",
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

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);
    final project = appState.currentProject;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  project == null
                      ? "Proje secili degil"
                      : "Proje: ${project.project}",
                  style: const TextStyle(fontWeight: FontWeight.w600)
                )
              ),
              IconButton(
                onPressed: _loading ? null : () => _pickImage(fromCamera: true),
                icon: const Icon(Icons.photo_camera)
              ),
              IconButton(
                onPressed: _loading ? null : () => _pickImage(fromCamera: false),
                icon: const Icon(Icons.photo_library)
              )
            ],
          ),
        ),
        Expanded(
          child: project == null
              ? const Center(child: Text("Once proje secin."))
              : FutureBuilder(
                  future: appState.fileRepository.listByProject(project.id),
                  builder: (context, snapshot) {
                    final items = snapshot.data ?? [];
                    if (items.isEmpty) {
                      return const Center(child: Text("Dosya yok."));
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return ListTile(
                          title: Text(item.fileName),
                          subtitle: Text(item.type),
                          trailing: Text(item.syncStatus.name)
                        );
                      },
                      separatorBuilder: (_, __) => const Divider(),
                      itemCount: items.length
                    );
                  }
                )
        )
      ],
    );
  }
}
