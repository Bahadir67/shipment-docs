import "package:flutter/material.dart";
import "../../data/models/project.dart";
import "../../state/app_scope.dart";

class NewProjectTab extends StatefulWidget {
  const NewProjectTab({super.key});

  @override
  State<NewProjectTab> createState() => _NewProjectTabState();
}

class _NewProjectTabState extends State<NewProjectTab> {
  final _formKey = GlobalKey<FormState>();
  final _serialController = TextEditingController();
  final _customerController = TextEditingController();
  final _projectController = TextEditingController();
  final _productTypeController = TextEditingController();
  final _yearController = TextEditingController(
    text: DateTime.now().year.toString()
  );
  bool _saving = false;

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
      serial: _serialController.text.trim(),
      customer: _customerController.text.trim(),
      project: _projectController.text.trim(),
      productType: _productTypeController.text.trim().isEmpty
          ? null
          : _productTypeController.text.trim(),
      year: int.parse(_yearController.text.trim()),
      status: "open"
    );
    final localProjectId = await appState.projectRepository.save(project);
    appState.setCurrentProject(project);
    await appState.syncEngine.enqueue(
      type: "project_create",
      payload: {
        "localProjectId": localProjectId,
        "serial": project.serial,
        "customer": project.customer,
        "project": project.project,
        "productType": project.productType,
        "year": project.year
      }
    );
    if (appState.isOnline) {
      await appState.syncEngine.syncAll(token: appState.user?.token);
    }
    if (mounted) {
      _formKey.currentState!.reset();
      _serialController.clear();
      _customerController.clear();
      _projectController.clear();
      _productTypeController.clear();
      _yearController.text = DateTime.now().year.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Proje kaydedildi."))
      );
    }
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _serialController,
              decoration: const InputDecoration(labelText: "Seri numarasi"),
              validator: (value) {
                if (value == null || value.isEmpty) return "Zorunlu";
                if (!RegExp(r"^SN-\\d{5}\$").hasMatch(value)) {
                  return "SN-12345 formatinda olmalidir";
                }
                return null;
              }
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _customerController,
              decoration: const InputDecoration(labelText: "Musteri"),
              validator: (value) =>
                  value == null || value.isEmpty ? "Zorunlu" : null
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _projectController,
              decoration: const InputDecoration(labelText: "Proje"),
              validator: (value) =>
                  value == null || value.isEmpty ? "Zorunlu" : null
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _productTypeController,
              decoration: const InputDecoration(labelText: "Urun tipi")
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _yearController,
              decoration: const InputDecoration(labelText: "Yil"),
              keyboardType: TextInputType.number,
              validator: (value) =>
                  value == null || value.isEmpty ? "Zorunlu" : null
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _submit,
                child: Text(_saving ? "Kaydediliyor..." : "Kaydet")
              )
            )
          ],
        )
      ),
    );
  }
}
