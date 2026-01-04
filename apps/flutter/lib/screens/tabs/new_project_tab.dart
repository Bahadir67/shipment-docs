import "package:flutter/material.dart";
import "package:isar/isar.dart";
import "../../data/models/project.dart";
import "../../data/models/checklist_item.dart";
import "../../state/app_scope.dart";

class NewProjectTab extends StatefulWidget {
  const NewProjectTab({super.key});

  @override
  State<NewProjectTab> createState() => _NewProjectTabState();
}

class _NewProjectTabState extends State<NewProjectTab> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _serialController;
  final _customerController = TextEditingController();
  final _projectController = TextEditingController();
  final _productTypeController = TextEditingController();
  late final TextEditingController _yearController;
  bool _saving = false;
  bool _loadingSerial = true;

  @override
  void initState() {
    super.initState();
    final currentYear = DateTime.now().year;
    _yearController = TextEditingController(text: currentYear.toString());
    _serialController = TextEditingController();
    
    // Auto-generate serial on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _generateNextSerial(currentYear);
    });
  }

  Future<void> _generateNextSerial(int year) async {
    setState(() => _loadingSerial = true);
    final appState = AppScope.of(context);
    
    // Fetch all projects
    final allProjects = await appState.projectRepository.listAll();
    
    int maxSeq = 0;
    final prefix = "PRJ-$year-";

    for (final p in allProjects) {
      if (p.serial.startsWith(prefix)) {
        final part = p.serial.substring(prefix.length); // get "0042"
        final seq = int.tryParse(part);
        if (seq != null && seq > maxSeq) {
          maxSeq = seq;
        }
      }
    }

    final nextSeq = maxSeq + 1;
    final formattedSeq = nextSeq.toString().padLeft(4, '0'); // "0043"
    
    if (mounted) {
      _serialController.text = "$prefix$formattedSeq";
      setState(() => _loadingSerial = false);
    }
  }

  @override
  void dispose() {
    _serialController.dispose();
    _customerController.dispose();
    _projectController.dispose();
    _productTypeController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final appState = AppScope.of(context);
    
    final project = Project(
      serverId: null,
      serial: _serialController.text.trim().toUpperCase(),
      customer: _customerController.text.trim(),
      project: _projectController.text.trim(),
      productType: _productTypeController.text.trim().isEmpty
          ? null
          : _productTypeController.text.trim(),
      year: int.parse(_yearController.text.trim()),
      status: "open"
    );

    // 1. Save Project (Checklist is now handled by checklistMask field with default "0")
    final localProjectId = await appState.projectRepository.save(project);
    project.id = localProjectId;

    appState.setCurrentProject(project);

    // 2. Sync
    await appState.syncEngine.enqueue(
      type: "project_create",
      payload: {
        "localProjectId": localProjectId,
        "serial": project.serial,
        "customer": project.customer,
        "project": project.project,
        "productType": project.productType,
        "year": project.year,
        // Server will set default checklistMask
      }
    );

    if (appState.isOnline) {
      await appState.syncEngine.syncAll(token: appState.user?.token);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Proje olusturuldu."))
      );
      
      // Reset form
      _formKey.currentState!.reset();
      _customerController.clear();
      _projectController.clear();
      _productTypeController.clear();
      final currentYear = DateTime.now().year;
      _yearController.text = currentYear.toString();
      _generateNextSerial(currentYear);

      // Navigate to Dashboard Tab (Index 0)
      DefaultTabController.of(context).animateTo(0);
    }
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            Stack(
              alignment: Alignment.centerRight,
              children: [
                TextFormField(
                  controller: _serialController,
                  style: const TextStyle(color: Color(0xFF0B0F10)),
                  decoration: const InputDecoration(
                    labelText: "Proje Kodu (Otomatik)", 
                    hintText: "PRJ-YYYY-####"
                  ),
                  readOnly: true, // User generally shouldn't edit this if auto-generated
                  validator: (value) {
                    if (value == null || value.isEmpty) return "Zorunlu";
                    return null;
                  }
                ),
                if (_loadingSerial)
                  const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: SizedBox(
                      width: 20, height: 20, 
                      child: CircularProgressIndicator(strokeWidth: 2)
                    ),
                  )
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _customerController,
              style: const TextStyle(color: Color(0xFF0B0F10)),
              decoration: const InputDecoration(labelText: "Musteri"),
              validator: (value) =>
                  value == null || value.isEmpty ? "Zorunlu" : null
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _projectController,
              style: const TextStyle(color: Color(0xFF0B0F10)),
              decoration: const InputDecoration(labelText: "Proje Ismi"),
              validator: (value) =>
                  value == null || value.isEmpty ? "Zorunlu" : null
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _productTypeController,
              style: const TextStyle(color: Color(0xFF0B0F10)),
              decoration: const InputDecoration(labelText: "Urun tipi")
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _yearController,
              style: const TextStyle(color: Color(0xFF0B0F10)),
              decoration: const InputDecoration(labelText: "Yil"),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                final y = int.tryParse(value);
                if (y != null && y > 2000) {
                  _generateNextSerial(y);
                }
              },
              validator: (value) =>
                  value == null || value.isEmpty ? "Zorunlu" : null
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _submit,
                child: Text(_saving ? "Olusturuluyor..." : "Proje Olustur")
              )
            )
          ],
        )
      ),
    );
  }
}