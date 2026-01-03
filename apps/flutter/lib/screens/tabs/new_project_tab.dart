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

    // 1. Save Project
    final localProjectId = await appState.projectRepository.save(project);
    project.id = localProjectId;

    // 2. Create Default Checklist Items
    // Format: key (unique per project), label (display text), category (grouping)
    final defaultChecklist = [
      // MECHANICAL
      {"key": "mech_cleanliness", "label": "Genel Temizlik ve Yag Kacagi Kontrolu", "cat": "MEKANIK"},
      {"key": "mech_paint", "label": "Boya ve Kaplama Kontrolu", "cat": "MEKANIK"},
      {"key": "mech_label", "label": "Etiket ve Nameplate Dogrulugu", "cat": "MEKANIK"},
      {"key": "mech_torque", "label": "Civata Tork Kontrolu ve Isaretleme", "cat": "MEKANIK"},
      {"key": "mech_packaging", "label": "Nakliye Takozlari ve Ambalaj", "cat": "MEKANIK"},

      // HYDRAULIC
      {"key": "hyd_leak", "label": "Rakor ve Baglanti Sizdirmazlik", "cat": "HIDROLIK"},
      {"key": "hyd_hoses", "label": "Hortum Yonlendirmesi ve Kelepceler", "cat": "HIDROLIK"},
      {"key": "hyd_filters", "label": "Filtre Elemanlari ve Gostergeler", "cat": "HIDROLIK"},
      {"key": "hyd_oil_level", "label": "Yag Seviyesi ve Gosterge Cami", "cat": "HIDROLIK"},
      {"key": "hyd_test_ports", "label": "Test Portlari ve Kapaklar", "cat": "HIDROLIK"},

      // ELECTRICAL
      {"key": "elec_cabling", "label": "Kablo Yonlendirmesi ve Spiral", "cat": "ELEKTRIK"},
      {"key": "elec_terminals", "label": "Klemens Baglantilari ve Numaralandirma", "cat": "ELEKTRIK"},
      {"key": "elec_grounding", "label": "Topraklama Baglantisi", "cat": "ELEKTRIK"},
      {"key": "elec_motor", "label": "Motor Klemens Kutusu Sizdirmazlik", "cat": "ELEKTRIK"},
      {"key": "elec_sensors", "label": "Sensor Montaj ve Baglantilari", "cat": "ELEKTRIK"},
    ];

    final List<ChecklistItem> checklistItems = defaultChecklist.map((item) {
      return ChecklistItem(
        projectId: localProjectId,
        projectServerId: null,
        itemKey: item["key"]!,
        category: item["cat"]!, // Store category group here
        // We can store the detailed label in a description field if we had one,
        // or just use itemKey mapping. Ideally model should have 'label'.
        // For now, let's use 'itemKey' to store the label since key is unique anyway 
        // OR better: Update ChecklistItem model to support 'label'.
        // But to stick to existing schema: We'll put label in itemKey for display? 
        // No, itemKey is for ID. Let's use 'category' for Group and format itemKey as 'label|key'.
        // Actually, looking at schema: itemKey, category, completed.
        // Let's use: category = "MEKANIK", itemKey = "Genel Temizlik..." (Display Text)
        // Ideally we need a separate label field, but reusing itemKey as display text is easiest now.
        completed: false
      )..itemKey = item["label"]!; // Use label as the key/display text for now
    }).toList();

    await appState.checklistRepository.upsertRemote(
      projectId: localProjectId, 
      items: checklistItems
    );

    appState.setCurrentProject(project);

    // 3. Sync
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Proje ve Checklist olusturuldu."))
      );
      
      // Reset form and generate next serial
      _formKey.currentState!.reset();
      _customerController.clear();
      _projectController.clear();
      _productTypeController.clear();
      final currentYear = DateTime.now().year;
      _yearController.text = currentYear.toString();
      _generateNextSerial(currentYear);
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