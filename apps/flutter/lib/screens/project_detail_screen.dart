import "dart:io";

import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter_image_compress/flutter_image_compress.dart";
import "package:image_picker/image_picker.dart";
import "package:path/path.dart" as p;
import "package:path_provider/path_provider.dart";

import "../config/theme.dart";
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
    for (final item in items) {
      final name = item.fileName.toLowerCase();
      if (name.contains(key)) return item;
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
    final picked = await _picker.pickImage(source: source, imageQuality: 85);
    
    if (picked == null) {
      setState(() => _loading = false);
      return;
    }

    final projectDir = await _resolveProjectDir(project.id);
    final ext = p.extension(picked.path).isEmpty ? ".jpg" : p.extension(picked.path);
    final fileName = "${slot["key"]}$ext";
    final targetPath = p.join(projectDir, fileName);
    
    final file = File(targetPath);
    if (await file.exists()) await file.delete();
    await File(picked.path).copy(targetPath);
    
    final thumbPath = p.join(projectDir, "thumb_${slot["key"]}.jpg");
    final thumbFile = File(thumbPath);
    if (await thumbFile.exists()) await thumbFile.delete();
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

  Future<void> _deleteFile(FileItem item) async {
    final appState = AppScope.of(context);
    if (item.localPath != null) {
      final f = File(item.localPath!);
      if (await f.exists()) await f.delete();
    }
    if (item.thumbnailPath != null) {
      final f = File(item.thumbnailPath!);
      if (await f.exists()) await f.delete();
    }
    await appState.fileRepository.delete(item.id!);
    setState(() {});
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

  // Helper to Group Checklist Items
  Map<String, List<ChecklistItem>> _groupItems(List<ChecklistItem> items) {
    final groups = <String, List<ChecklistItem>>{};
    for (var item in items) {
      if (!groups.containsKey(item.category)) {
        groups[item.category] = [];
      }
      groups[item.category]!.add(item);
    }
    return groups;
  }

  Future<void> _deleteProject() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Projeyi Sil?"),
        content: const Text("Bu proje ve bagli tum dosyalar cihazdan silinecek. Sunucuda ise 'Silindi' olarak isaretlenecek. Emin misiniz?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Iptal")),
          TextButton(onPressed: () => Navigator.pop(context, true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text("SIL")),
        ],
      )
    );

    if (confirmed != true) return;

    final appState = AppScope.of(context);
    final project = appState.currentProject;
    if (project == null) return;

    setState(() => _loading = true);

    // 1. Delete Local Files
    final projectDir = await _resolveProjectDir(project.id);
    final dir = Directory(projectDir);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }

    // 2. Mark as Deleted in DB & Enqueue Sync
    await appState.projectRepository.markAsDeleted(project.id);
    await appState.syncEngine.enqueue(
      type: "project_delete",
      payload: {"localProjectId": project.id}
    );

    if (appState.isOnline) {
      await appState.syncEngine.syncAll(token: appState.user?.token);
    }

    if (mounted) {
      Navigator.pop(context); // Close detail screen
      appState.notifyListeners(); // Force dashboard refresh
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Proje silindi.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);
    final project = appState.currentProject;
    final isAdmin = appState.user?.role == "admin"; // Check role
    
    if (project == null) {
      return const Scaffold(body: Center(child: Text("Proje secilmedi")));
    }

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: Text(project.project),
        backgroundColor: Colors.transparent,
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
              onPressed: _loading ? null : _deleteProject,
              tooltip: "Projeyi Sil",
            )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card with Status
            _buildProjectHeader(project),
            
            const SizedBox(height: 24),

            // Photo Grid Section
            const Text(
              "Standart Fotograflar",
              style: TextStyle(color: AppTheme.paper, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<FileItem>>(
              future: appState.fileRepository.listByProject(project.id),
              builder: (context, snapshot) {
                final files = snapshot.data ?? [];
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, 
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.2,
                  ),
                  itemCount: _photoSlots.length,
                  itemBuilder: (context, index) {
                    final slot = _photoSlots[index];
                    final match = _matchSlot(files, slot);
                    return _buildPhotoCard(slot, match);
                  },
                );
              },
            ),

            const SizedBox(height: 24),

            // Accordion Checklist
            const Text(
              "QC Kontrol Listesi",
              style: TextStyle(color: AppTheme.paper, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<ChecklistItem>>(
              future: appState.checklistRepository.listByProject(project.id),
              builder: (context, snapshot) {
                final items = snapshot.data ?? [];
                if (items.isEmpty) return const Text("Checklist yok.", style: TextStyle(color: Colors.white54));
                
                final grouped = _groupItems(items);
                // Sort keys to maintain order: MEKANIK, HIDROLIK, ELEKTRIK
                final keys = grouped.keys.toList()..sort((a, b) {
                  // Custom sort if needed, simple alpha otherwise
                  // Let's force specific order
                  final order = {"MEKANIK": 1, "HIDROLIK": 2, "ELEKTRIK": 3};
                  return (order[a] ?? 99).compareTo(order[b] ?? 99);
                });

                return Column(
                  children: keys.map((cat) {
                    final catItems = grouped[cat]!;
                    final completedCount = catItems.where((i) => i.completed).length;
                    final totalCount = catItems.length;
                    final isDone = completedCount == totalCount;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: ExpansionTile(
                            backgroundColor: AppTheme.bgAccent,
                            collapsedBackgroundColor: AppTheme.bgAccent,
                            leading: Icon(
                              isDone ? Icons.check_circle : Icons.pending_actions,
                              color: isDone ? Colors.greenAccent : AppTheme.accent,
                            ),
                            title: Text(cat, style: const TextStyle(color: AppTheme.paper, fontWeight: FontWeight.bold)),
                            subtitle: Text("$completedCount / $totalCount tamamlandi", style: TextStyle(color: AppTheme.paper.withOpacity(0.6), fontSize: 12)),
                            children: catItems.map((item) => CheckboxListTile(
                              title: Text(item.itemKey, style: const TextStyle(fontSize: 14, color: AppTheme.paper)),
                              value: item.completed,
                              activeColor: AppTheme.accent,
                              checkColor: AppTheme.ink,
                              onChanged: (v) => _toggleChecklist(item, v ?? false),
                            )).toList(),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),

            const SizedBox(height: 24),

            // Document List
            const Text(
              "Dökümanlar",
              style: TextStyle(color: AppTheme.paper, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<FileItem>>(
              future: appState.fileRepository.listByProject(project.id),
              builder: (context, snapshot) {
                final items = snapshot.data ?? [];
                final docs = items.where((i) => i.type != "photo").toList();
                if (docs.isEmpty) return Text("Kayitli döküman bulunmadi.", style: TextStyle(color: AppTheme.paper.withOpacity(0.4)));
                return Column(
                  children: docs.map((doc) => Card(
                    color: AppTheme.bgAccent,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.description, color: AppTheme.paper),
                      title: Text(doc.fileName, style: const TextStyle(color: AppTheme.paper)),
                      subtitle: Text(doc.syncStatus.name, style: TextStyle(color: AppTheme.accent.withOpacity(0.7))),
                    ),
                  )).toList(),
                );
              },
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectHeader(dynamic project) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.bgAccent, AppTheme.bgAccent.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.paper.withOpacity(0.05)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  project.customer,
                  style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 4),
                Text(
                  "${project.serial} • ${project.year}",
                  style: TextStyle(color: AppTheme.paper.withOpacity(0.9), fontWeight: FontWeight.w500),
                ),
                Text(
                  project.productType ?? '-',
                  style: TextStyle(color: AppTheme.paper.withOpacity(0.6), fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: (project.status == "completed") ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: (project.status == "completed") ? Colors.green : Colors.red,
                width: 1
              )
            ),
            child: Text(
              (project.status == "completed") ? "TAMAMLANDI" : "DENETİMDE",
              style: TextStyle(
                color: (project.status == "completed") ? Colors.greenAccent : Colors.redAccent,
                fontWeight: FontWeight.bold,
                fontSize: 10
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildPhotoCard(Map<String, String> slot, FileItem? file) {
    final imagePath = file?.thumbnailPath ?? file?.localPath;
    final hasImage = imagePath != null && File(imagePath).existsSync();

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgAccent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.paper.withOpacity(0.1)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasImage)
              Image.file(File(imagePath), fit: BoxFit.cover)
            else
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.camera_alt_outlined, color: AppTheme.paper.withOpacity(0.3), size: 32),
                  const SizedBox(height: 8),
                  Text(slot["label"]!, style: TextStyle(color: AppTheme.paper.withOpacity(0.5), fontSize: 12)),
                ],
              ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _captureForSlot(slot: slot, source: ImageSource.camera),
                onLongPress: () => _captureForSlot(slot: slot, source: ImageSource.gallery),
                child: const SizedBox.expand(),
              ),
            ),
            if (hasImage)
              Positioned(
                top: 8, right: 8,
                child: Row(
                  children: [
                    _iconButton(Icons.visibility, () => _showPreview(file!)),
                    const SizedBox(width: 8),
                    _iconButton(Icons.delete, () => _deleteFile(file!), color: Colors.redAccent),
                  ],
                ),
              ),
            if (hasImage)
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  color: Colors.black54,
                  child: Text(slot["label"]!, style: const TextStyle(color: Colors.white, fontSize: 10), textAlign: TextAlign.center),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _iconButton(IconData icon, VoidCallback onTap, {Color color = Colors.white}) {
    return Container(
      height: 32, width: 32,
      decoration: BoxDecoration(
        color: Colors.black45,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: 16, color: color),
        onPressed: onTap,
      ),
    );
  }

  void _showPreview(FileItem item) {
    if (item.localPath == null) return;
    showDialog(
      context: context,
      builder: (_) => Dialog.fullscreen(
        child: Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
          body: Center(child: Image.file(File(item.localPath!))),
        ),
      ),
    );
  }
}
