import { useEffect, useMemo, useState } from "react";
import { addUpload, listUploads, deleteUpload } from "./offlineQueue.js";

const serialRegex = /^SN-\d{5}$/;
const projectSuffixRegex = /^\d{4}$/;

const menuItems = [
  { id: "dashboard", label: "Genel Bakis" },
  { id: "projects", label: "Projeler" },
  { id: "new", label: "Yeni Proje" },
  { id: "uploads", label: "Yuklemeler" }
];

const PHOTO_SLOTS = [
  { id: "front", label: "Onden", key: "onden" },
  { id: "right", label: "Sagdan", key: "sagdan" },
  { id: "left", label: "Soldan", key: "soldan" },
  { id: "back", label: "Arkadan", key: "arkadan" },
  { id: "label", label: "Etiket", key: "etiket" },
  { id: "general", label: "Genel", key: "genel" }
];

export default function App() {
  const [activePage, setActivePage] = useState("dashboard");
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [status, setStatus] = useState({ type: "", message: "" });
  const [user, setUser] = useState(null);
  const [products, setProducts] = useState([]);
  const [productForm, setProductForm] = useState({
    serial: "",
    customer: "",
    projectSuffix: "",
    productType: "",
    year: new Date().getFullYear().toString()
  });
  const [productStatus, setProductStatus] = useState({ type: "", message: "" });
  const [currentProject, setCurrentProject] = useState(null);
  const [checklist, setChecklist] = useState([]);
  const [projectFiles, setProjectFiles] = useState([]);
  const [photoPreviews, setPhotoPreviews] = useState({});
  const [slotPreviews, setSlotPreviews] = useState({});
  const [uploadForm, setUploadForm] = useState({
    type: "test_report", // Default to document type
    category: "Drawings",
    files: []
  });
  const [uploadStatus, setUploadStatus] = useState({ type: "", message: "" });
  const [noteStatus, setNoteStatus] = useState({ type: "", message: "" });
  const [noteText, setNoteText] = useState("");
  const [isOnline, setIsOnline] = useState(navigator.onLine);
  const [syncing, setSyncing] = useState(false);
  const [pendingUploads, setPendingUploads] = useState(0);
  const [editingProjectId, setEditingProjectId] = useState(null);
  const [editForm, setEditForm] = useState({
    serial: "",
    customer: "",
    project: "",
    productType: "",
    year: ""
  });
  const apiBase = import.meta.env.VITE_API_URL || "http://localhost:3000";
  const tokenKey = "shipment_docs_token";
  const pendingProductsKey = "shipment_docs_pending_products";
  const notesKey = "shipment_docs_notes";
  const currentProjectKey = "shipment_docs_current_project";

  const isAdmin = user?.role === "admin";
  const findSlotFile = (slot, files) =>
    files.find((file) => {
      const name = (file.fileName || "").toLowerCase();
      const category = (file.category || "").toLowerCase();
      return (
        name.includes(slot.key) ||
        category === slot.label.toLowerCase() ||
        category.includes(slot.key)
      );
    });

  const fetchChecklist = async (token, productId) => {
    try {
      const response = await fetch(`${apiBase}/products/${productId}/checklist`, {
        headers: { Authorization: `Bearer ${token}` }
      });
      if (response.ok) {
        const payload = await response.json();
        setChecklist(payload.data || []);
      }
    } catch (error) {
      console.error("Checklist fetch failed");
    }
  };

  const fetchProjectFiles = async (token, productId) => {
    try {
      const response = await fetch(`${apiBase}/products/${productId}/files`, {
        headers: { Authorization: `Bearer ${token}` }
      });
      if (response.ok) {
        const payload = await response.json();
        // Normalize fileId to fileName for frontend consistency
        const normalized = (payload.data || []).map(f => ({
          ...f,
          fileName: f.fileName || f.fileId // Fallback to fileId if fileName missing
        }));
        setProjectFiles(normalized);
      }
    } catch (error) {
      console.error("Files fetch failed");
    }
  };

  useEffect(() => {
    Object.values(photoPreviews).forEach((url) => URL.revokeObjectURL(url));
    setPhotoPreviews({});
    Object.values(slotPreviews).forEach((url) => URL.revokeObjectURL(url));
    setSlotPreviews({});
  }, [currentProject?.id]);

  useEffect(() => {
    if (!currentProject) return;
    const token = localStorage.getItem(tokenKey);
    if (!token) return;

    const controller = new AbortController();
    const slotFiles = PHOTO_SLOTS.map((slot) => findSlotFile(slot, projectFiles)).filter(
      Boolean
    );
    const missing = slotFiles.filter(
      (file) =>
        file.type === "photo" &&
        !String(file.id || "").startsWith("temp-") &&
        !photoPreviews[file.id]
    );

    if (!missing.length) return undefined;

    const loadPreviews = async () => {
      const tasks = missing.map(async (file) => {
        try {
          const response = await fetch(
            `${apiBase}/products/${currentProject.id}/files/${file.id}/thumb`,
            {
              headers: { Authorization: `Bearer ${token}` },
              signal: controller.signal
            }
          );
          if (!response.ok) return null;
          const blob = await response.blob();
          return { id: file.id, url: URL.createObjectURL(blob) };
        } catch (error) {
          if (error.name !== "AbortError") {
            console.error("Preview load failed", error);
          }
          return null;
        }
      });
      const results = await Promise.allSettled(tasks);
      const nextPreviews = {};
      for (const result of results) {
        if (result.status !== "fulfilled" || !result.value) continue;
        nextPreviews[result.value.id] = result.value.url;
      }
      if (Object.keys(nextPreviews).length) {
        setPhotoPreviews((prev) => {
          const next = { ...prev };
          for (const [id, url] of Object.entries(nextPreviews)) {
            if (next[id]) URL.revokeObjectURL(next[id]);
            next[id] = url;
          }
          return next;
        });
      }
    };

    loadPreviews();

    return () => controller.abort();
  }, [projectFiles, currentProject?.id, photoPreviews, apiBase]);

  useEffect(() => {
    if (!currentProject) return;
    setSlotPreviews((prev) => {
      let changed = false;
      const next = { ...prev };
      for (const slot of PHOTO_SLOTS) {
        const previewUrl = next[slot.key];
        if (!previewUrl) continue;
        const existingFile = findSlotFile(slot, projectFiles);
        if (!existingFile) continue;
        const hasPreview = !!photoPreviews[existingFile.id];
        if (hasPreview) {
          URL.revokeObjectURL(previewUrl);
          delete next[slot.key];
          changed = true;
        }
      }
      return changed ? next : prev;
    });
  }, [projectFiles, photoPreviews, currentProject?.id]);

  const toggleChecklistItem = async (item) => {
    const token = localStorage.getItem(tokenKey);
    if (!token) return;
    const nextStatus = !item.completed;

    setChecklist((prev) =>
      prev.map((i) => (i.id === item.id ? { ...i, completed: nextStatus } : i))
    );

    try {
      const response = await fetch(`${apiBase}/products/${currentProject.id}/checklist`, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json"
        },
        body: JSON.stringify({
          itemKey: item.itemKey,
          category: item.category,
          completed: nextStatus
        })
      });
      if (!response.ok) throw new Error();
    } catch (error) {
      setChecklist((prev) =>
        prev.map((i) => (i.id === item.id ? { ...i, completed: !nextStatus } : i))
      );
    }
  };

  const projectCode = useMemo(() => {
    if (!productForm.projectSuffix) return "";
    return `PRJ-${productForm.year}-${productForm.projectSuffix}`;
  }, [productForm.year, productForm.projectSuffix]);

  const loadPendingProducts = () => {
    try {
      return JSON.parse(localStorage.getItem(pendingProductsKey) || "[]");
    } catch (error) {
      return [];
    }
  };

  const savePendingProducts = (list) => {
    localStorage.setItem(pendingProductsKey, JSON.stringify(list));
  };

  const loadNotes = () => {
    try {
      return JSON.parse(localStorage.getItem(notesKey) || "{}");
    } catch (error) {
      return {};
    }
  };

  const saveNotes = (notes) => {
    localStorage.setItem(notesKey, JSON.stringify(notes));
  };

  const fetchMe = async (token) => {
    try {
      const response = await fetch(`${apiBase}/auth/me`, {
        headers: { Authorization: `Bearer ${token}` }
      });
      if (!response.ok) {
        localStorage.removeItem(tokenKey);
        return;
      }
      const payload = await response.json();
      setUser(payload);
      fetchProducts(token);
    } catch (error) {
      setStatus({ type: "error", message: "Oturum geri yuklenemedi." });
    }
  };

  const fetchProducts = async (token) => {
    try {
      const response = await fetch(`${apiBase}/products`, {
        headers: { Authorization: `Bearer ${token}` }
      });
      if (!response.ok) return;
      const payload = await response.json();
      const pending = loadPendingProducts();
      const combined = [...(pending || []), ...(payload.data || [])];
      setProducts(combined);
      if (!currentProject) {
        const storedId = localStorage.getItem(currentProjectKey);
        const stored = combined.find((item) => item.id === storedId);
        if (stored) setCurrentProject(stored);
      }
    } catch (error) {
      setProducts([]);
    }
  };

  const refreshPendingUploads = async () => {
    try {
      const uploads = await listUploads();
      setPendingUploads(uploads.length);
    } catch (error) {
      setPendingUploads(0);
    }
  };

  const enqueueProduct = (payload) => {
    const pending = loadPendingProducts();
    const queued = {
      ...payload,
      id: `temp-${Date.now()}`,
      status: "pending",
      createdAt: new Date().toISOString()
    };
    const next = [queued, ...pending];
    savePendingProducts(next);
    setProducts((prev) => [queued, ...prev]);
    setCurrentProject(queued);
    setActivePage("uploads");
  };

  const syncPendingProducts = async (token) => {
    const pending = loadPendingProducts();
    if (!pending.length) return;
    const remaining = [];
    for (const entry of pending) {
      try {
        const response = await fetch(`${apiBase}/products`, {
          method: "POST",
          headers: {
            Authorization: `Bearer ${token}`,
            "Content-Type": "application/json"
          },
          body: JSON.stringify({
            serial: entry.serial,
            customer: entry.customer,
            project: entry.project,
            productType: entry.productType,
            year: entry.year
          })
        });
        if (!response.ok) {
          remaining.push(entry);
        }
      } catch (error) {
        remaining.push(entry);
      }
    }
    savePendingProducts(remaining);
  };

  const syncPendingUploads = async (token) => {
    const uploads = await listUploads();
    for (const entry of uploads) {
      try {
        const form = new FormData();
        form.append("type", entry.type);
        if (entry.category) form.append("category", entry.category);
        form.append("file", entry.file, entry.fileName);
        const response = await fetch(`${apiBase}/products/${entry.productId}/files`, {
          method: "POST",
          headers: { Authorization: `Bearer ${token}` },
          body: form
        });
        if (response.ok) {
          await deleteUpload(entry.id);
        }
      } catch (error) {
        // keep in queue
      }
    }
    refreshPendingUploads();
  };

  const syncAll = async () => {
    const token = localStorage.getItem(tokenKey);
    if (!token) return;
    setSyncing(true);
    await syncPendingProducts(token);
    await fetchProducts(token);
    await syncPendingUploads(token);
    setSyncing(false);
  };

  const handleProductChange = (field) => (event) => {
    setProductForm((prev) => ({ ...prev, [field]: event.target.value }));
  };

  const handleUploadChange = (field) => (event) => {
    if (field === "files") {
      const files = Array.from(event.target.files || []);
      setUploadForm((prev) => ({ ...prev, files }));
      return;
    }
    setUploadForm((prev) => ({ ...prev, [field]: event.target.value }));
  };

  const handleCreateProject = async (event) => {
    event.preventDefault();
    setProductStatus({ type: "", message: "" });
    const token = localStorage.getItem(tokenKey);
    if (!token) {
      setProductStatus({ type: "error", message: "Once giris yapin." });
      return;
    }
    if (!serialRegex.test(productForm.serial)) {
      setProductStatus({
        type: "error",
        message: "Seri format SN-12345 olmali."
      });
      return;
    }
    if (!projectSuffixRegex.test(productForm.projectSuffix)) {
      setProductStatus({
        type: "error",
        message: "Proje soneki 4 haneli olmali."
      });
      return;
    }
    if (!productForm.customer) {
      setProductStatus({ type: "error", message: "Musteri zorunludur." });
      return;
    }
    const payload = {
      serial: productForm.serial,
      customer: productForm.customer,
      project: projectCode,
      productType: productForm.productType,
      year: productForm.year
    };
    if (!navigator.onLine) {
      enqueueProduct(payload);
      setProductStatus({ type: "success", message: "Senkron icin kuyruga alindi." });
      setProductForm((prev) => ({
        ...prev,
        serial: "",
        customer: "",
        projectSuffix: "",
        productType: ""
      }));
      return;
    }
    try {
      const response = await fetch(`${apiBase}/products`, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json"
        },
        body: JSON.stringify(payload)
      });
      if (!response.ok) {
        const result = await response.json().catch(() => ({}));
        setProductStatus({ type: "error", message: result.error || "Olusturma basarisiz." });
        return;
      }
      const created = await response.json();
      setProductStatus({ type: "success", message: "Proje olusturuldu." });
      setProductForm((prev) => ({
        ...prev,
        serial: "",
        customer: "",
        projectSuffix: "",
        productType: ""
      }));
      setProducts((prev) => [created, ...prev]);
      setCurrentProject(created);
      setActivePage("uploads");
    } catch (error) {
      setProductStatus({ type: "error", message: "Ag hatasi. Tekrar deneyin." });
    }
  };

  // Specific handler for grid photos
  const handleGridFileSelect = async (slot, event) => {
    const file = event.target.files?.[0];
    if (!file || !currentProject) return;

    // Reset value to allow re-upload
    event.target.value = "";

    // Generate new filename
    const ext = file.name.split(".").pop();
    const fileName = `${slot.key}.${ext}`;

    // Create optimistic file object for immediate preview
    const previewUrl = URL.createObjectURL(file);
    const optimisticFile = {
      id: `temp-${Date.now()}`,
      type: "photo",
      fileName: fileName,
      fileUrl: previewUrl, // Local preview URL
      createdAt: new Date().toISOString()
    };

    // Update state immediately to show thumbnail
    setProjectFiles((prev) => {
      // Remove existing file for this slot if any
      const filtered = prev.filter(f => !f.fileName.toLowerCase().startsWith(slot.key));
      return [optimisticFile, ...filtered];
    });
    setSlotPreviews((prev) => {
      const existing = prev[slot.key];
      if (existing) URL.revokeObjectURL(existing);
      return { ...prev, [slot.key]: previewUrl };
    });

    const token = localStorage.getItem(tokenKey);
    if (!token) return;

    if (!navigator.onLine) {
       await addUpload({
          productId: currentProject.id,
          type: "photo",
          category: slot.label,
          file,
          fileName: fileName,
          mimeType: file.type
       });
       refreshPendingUploads();
       return;
    }

    try {
        const form = new FormData();
        form.append("type", "photo");
        form.append("category", slot.label);
        form.append("file", file, fileName);
        
        const response = await fetch(
          `${apiBase}/products/${currentProject.id}/files`,
          {
            method: "POST",
            headers: { Authorization: `Bearer ${token}` },
            body: form
          }
        );
        
        if (response.ok) {
            // Fetch fresh list from server to get permanent URLs
            fetchProjectFiles(token, currentProject.id);
        }
    } catch (error) {
        console.error("Grid upload failed", error);
        await addUpload({
          productId: currentProject.id,
          type: "photo",
          category: slot.label,
          file,
          fileName: fileName,
          mimeType: file.type
        });
        refreshPendingUploads();
    }
  };

  const handleUpload = async (event) => {
    event.preventDefault();
    setUploadStatus({ type: "", message: "" });
    const token = localStorage.getItem(tokenKey);
    if (!token) {
      setUploadStatus({ type: "error", message: "Once giris yapin." });
      return;
    }
    if (!currentProject || String(currentProject.id || "").startsWith("temp-")) {
      setUploadStatus({ type: "error", message: "Proje henuz senkron degil." });
      return;
    }
    if (!uploadForm.files.length) {
      setUploadStatus({ type: "error", message: "En az bir dosya secin." });
      return;
    }
    if (!navigator.onLine) {
      for (const file of uploadForm.files) {
        await addUpload({
          productId: currentProject.id,
          type: uploadForm.type,
          category: uploadForm.type === "project_file" ? uploadForm.category : null,
          file,
          fileName: file.name,
          mimeType: file.type
        });
      }
      setUploadStatus({ type: "success", message: "Yukleme senkron icin kuyruga alindi." });
      setUploadForm((prev) => ({ ...prev, files: [] }));
      refreshPendingUploads();
      return;
    }
    try {
      for (const file of uploadForm.files) {
        const form = new FormData();
        form.append("type", uploadForm.type);
        if (uploadForm.type === "project_file") {
          form.append("category", uploadForm.category);
        }
        form.append("file", file);
        const response = await fetch(
          `${apiBase}/products/${currentProject.id}/files`,
          {
            method: "POST",
            headers: { Authorization: `Bearer ${token}` },
            body: form
          }
        );
        if (!response.ok) {
          const payload = await response.json().catch(() => ({}));
        setUploadStatus({ type: "error", message: payload.error || "Yukleme basarisiz." });
          return;
        }
      }
      setUploadStatus({ type: "success", message: "Yuklendi." });
      setUploadForm((prev) => ({ ...prev, files: [] }));
      fetchProjectFiles(token, currentProject.id);
    } catch (error) {
      for (const file of uploadForm.files) {
        await addUpload({
          productId: currentProject.id,
          type: uploadForm.type,
          category: uploadForm.type === "project_file" ? uploadForm.category : null,
          file,
          fileName: file.name,
          mimeType: file.type
        });
      }
      setUploadStatus({ type: "success", message: "Yukleme senkron icin kuyruga alindi." });
      setUploadForm((prev) => ({ ...prev, files: [] }));
      refreshPendingUploads();
    }
  };

  const handleSaveNote = () => {
    if (!currentProject) return;
    const notes = loadNotes();
    notes[currentProject.id] = noteText;
    saveNotes(notes);
    setNoteStatus({ type: "success", message: "Not kaydedildi." });
  };

  const handleLogin = async (event) => {
    event.preventDefault();
    setStatus({ type: "", message: "" });
    if (!username || !password) {
      setStatus({ type: "error", message: "Kullanici adi ve sifre zorunlu." });
      return;
    }
    try {
      const response = await fetch(`${apiBase}/auth/login`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ username, password })
      });
      if (!response.ok) {
        const payload = await response.json().catch(() => ({}));
        const message = payload.error || "Giris basarisiz.";
        setStatus({ type: "error", message });
        return;
      }
      const payload = await response.json();
      localStorage.setItem(tokenKey, payload.token);
      setUser(payload.user);
      fetchProducts(payload.token);
      setStatus({ type: "success", message: "Giris basarili." });
      setPassword("");
    } catch (error) {
      setStatus({ type: "error", message: "Ag hatasi. Tekrar deneyin." });
    }
  };

  const handleLogout = () => {
    localStorage.removeItem(tokenKey);
    localStorage.removeItem(currentProjectKey);
    setUser(null);
    setCurrentProject(null);
    setStatus({ type: "", message: "" });
  };

  const startEdit = (item) => {
    setEditingProjectId(item.id);
    setEditForm({
      serial: item.serial,
      customer: item.customer,
      project: item.project,
      productType: item.productType || "",
      year: String(item.year || "")
    });
  };

  const cancelEdit = () => {
    setEditingProjectId(null);
    setEditForm({ serial: "", customer: "", project: "", productType: "", year: "" });
  };

  const saveEdit = async () => {
    const token = localStorage.getItem(tokenKey);
    if (!token || !editingProjectId) return;
    try {
      const response = await fetch(`${apiBase}/products/${editingProjectId}`, {
        method: "PUT",
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json"
        },
        body: JSON.stringify(editForm)
      });
      if (!response.ok) return;
      const updated = await response.json();
      setProducts((prev) => prev.map((item) => (item.id === updated.id ? updated : item)));
      cancelEdit();
    } catch (error) {
      // ignore for now
    }
  };

  const deleteProject = async (id) => {
    const token = localStorage.getItem(tokenKey);
    if (!token) return;
    try {
      const response = await fetch(`${apiBase}/products/${id}`, {
        method: "DELETE",
        headers: { Authorization: `Bearer ${token}` }
      });
      if (!response.ok) return;
      setProducts((prev) => prev.filter((item) => item.id !== id));
    } catch (error) {
      // ignore for now
    }
  };

  useEffect(() => {
    const stored = localStorage.getItem(tokenKey);
    if (stored) {
      fetchMe(stored);
    }
    refreshPendingUploads();
  }, []);

  useEffect(() => {
    const handleOnline = () => {
      setIsOnline(true);
      syncAll();
    };
    const handleOffline = () => setIsOnline(false);
    window.addEventListener("online", handleOnline);
    window.addEventListener("offline", handleOffline);
    return () => {
      window.removeEventListener("online", handleOnline);
      window.removeEventListener("offline", handleOffline);
    };
  }, []);

  useEffect(() => {
    if (!currentProject) return;
    const notes = loadNotes();
    setNoteText(notes[currentProject.id] || "");
    setNoteStatus({ type: "", message: "" });
  }, [currentProject]);

  useEffect(() => {
    const token = localStorage.getItem(tokenKey);
    if (!currentProject) {
      setChecklist([]);
      setProjectFiles([]);
      return;
    }
    localStorage.setItem(currentProjectKey, currentProject.id);
    if (!token) return;
    fetchChecklist(token, currentProject.id);
    fetchProjectFiles(token, currentProject.id);
  }, [currentProject?.id]);

  const selectableProducts = useMemo(
    () => products.filter((item) => !String(item.id || "").startsWith("temp-")),
    [products]
  );

  const visibleProjects = useMemo(
    () => products.filter((item) => item.status !== "deleted"),
    [products]
  );

  return (
    <div className="app">
      <aside className="nav">
        <div className="brand">
          <span className="brand-mark">SD</span>
          <div>
            <p className="brand-title">Shipment Docs</p>
            <p className="brand-sub">MVP Calisma Alani</p>
          </div>
        </div>
        <nav className="menu">
          {menuItems.map((item) => (
            <button
              key={item.id}
              type="button"
              className={activePage === item.id ? "active" : ""}
              onClick={() => setActivePage(item.id)}
            >
              {item.label}
            </button>
          ))}
        </nav>
        <div className="nav-footer">
          {user ? (
            <>
              <div className="sync-pill">
                {isOnline ? "Cevrimici" : "Cevrimdisi"} • {pendingUploads} kuyrukta
              </div>
              <div className="user-pill">
                {user.username} • {user.role}
              </div>
              <button type="button" className="ghost" onClick={syncAll} disabled={syncing}>
                {syncing ? "Senkron..." : "Simdi senkronla"}
              </button>
              <button type="button" onClick={handleLogout}>
                Cikis
              </button>
            </>
          ) : (
            <p className="card-sub">Baslamak icin giris yapin.</p>
          )}
        </div>
      </aside>

      <main className="main">
        <header className="topbar">
          <div>
            <h1>{menuItems.find((item) => item.id === activePage)?.label}</h1>
            <p>Tablet ve masaustu uyumlu.</p>
          </div>
          <div className="status">
            <span className="pulse" aria-hidden="true" />
            Senkron hazir
          </div>
        </header>

        {currentProject ? (
          <section className="project-banner">
            <div>
              <p>Aktif proje</p>
              <h2>{currentProject.project}</h2>
            </div>
            <div>
              <span>{currentProject.serial}</span>
              <span>{currentProject.customer}</span>
              <span>{currentProject.status || "open"}</span>
            </div>
          </section>
        ) : null}

        {!user ? (
          <section className="panel">
            <h2>Giris</h2>
            <p>Calisma alanina ulasmak icin giris yapin.</p>
            <form className="form" onSubmit={handleLogin}>
              <label>
                Kullanici adi
                <input
                  type="text"
                  placeholder="qc_user"
                  value={username}
                  onChange={(event) => setUsername(event.target.value)}
                />
              </label>
              <label>
                Sifre
                <input
                  type="password"
                  placeholder="Sifre girin"
                  value={password}
                  onChange={(event) => setPassword(event.target.value)}
                />
              </label>
              <button type="submit">Giris</button>
            </form>
            {status.message ? (
              <div className={`status-chip ${status.type}`}>{status.message}</div>
            ) : null}
          </section>
        ) : null}

        {user && activePage === "dashboard" ? (
          <section className="grid">
            <div className="panel">
              <h2>Hizli ozet</h2>
              <div className="stats">
                <div>
                  <h3>{visibleProjects.length}</h3>
                  <p>Aktif projeler</p>
                </div>
                <div>
                  <h3>{pendingUploads}</h3>
                  <p>Kuyruktaki yuklemeler</p>
                </div>
                <div>
                  <h3>{isOnline ? "Cevrimici" : "Cevrimdisi"}</h3>
                  <p>Baglanti</p>
                </div>
              </div>
              <p className="hint">
                "Yeni Proje" ile baslayin, sonra "Yuklemeler" ile dosya ekleyin.
              </p>
            </div>
            <div className="panel">
              <h2>Son projeler</h2>
              <ul className="list">
                {visibleProjects.slice(0, 5).map((item) => (
                  <li key={item.id}>
                    <span>{item.serial}</span>
                    <span>{item.project}</span>
                    <span>{item.customer}</span>
                    <button type="button" onClick={() => {
                      setCurrentProject(item);
                      setActivePage("uploads");
                    }}>
                      Ac
                    </button>
                  </li>
                ))}
              </ul>
            </div>
          </section>
        ) : null}

        {user && activePage === "projects" ? (
          <section className="panel">
            <h2>Tum projeler</h2>
            <p className="hint">Yalnizca admin duzenleyebilir veya silebilir.</p>
            <div className="table">
              {visibleProjects.map((item) => (
                <div key={item.id} className="row">
                  <div>
                    <strong>{item.serial}</strong>
                    <span>{item.project}</span>
                  </div>
                  <div>
                    <span>{item.customer}</span>
                    <span>{item.status || "open"}</span>
                  </div>
                  <div className="row-actions">
                    <button type="button" onClick={() => {
                      setCurrentProject(item);
                      setActivePage("uploads");
                    }}>
                      Goruntule
                    </button>
                    {isAdmin ? (
                      <>
                        <button type="button" className="ghost" onClick={() => startEdit(item)}>
                          Duzenle
                        </button>
                        <button type="button" className="danger" onClick={() => deleteProject(item.id)}>
                          Sil
                        </button>
                      </>
                    ) : null}
                  </div>
                  {editingProjectId === item.id ? (
                    <div className="edit-panel">
                      <label>
                        Seri
                        <input
                          value={editForm.serial}
                          onChange={(event) => setEditForm((prev) => ({
                            ...prev,
                            serial: event.target.value
                          }))}
                        />
                      </label>
                      <label>
                        Musteri
                        <input
                          value={editForm.customer}
                          onChange={(event) => setEditForm((prev) => ({
                            ...prev,
                            customer: event.target.value
                          }))}
                        />
                      </label>
                      <label>
                        Proje
                        <input
                          value={editForm.project}
                          onChange={(event) => setEditForm((prev) => ({
                            ...prev,
                            project: event.target.value
                          }))}
                        />
                      </label>
                      <label>
                        Urun tipi
                        <input
                          value={editForm.productType}
                          onChange={(event) => setEditForm((prev) => ({
                            ...prev,
                            productType: event.target.value
                          }))}
                        />
                      </label>
                      <label>
                        Yil
                        <input
                          value={editForm.year}
                          onChange={(event) => setEditForm((prev) => ({
                            ...prev,
                            year: event.target.value
                          }))}
                        />
                      </label>
                      <div className="row-actions">
                        <button type="button" onClick={saveEdit}>
                          Kaydet
                        </button>
                        <button type="button" className="ghost" onClick={cancelEdit}>
                          Iptal
                        </button>
                      </div>
                    </div>
                  ) : null}
                </div>
              ))}
            </div>
          </section>
        ) : null}

        {user && activePage === "new" ? (
          <section className="panel">
            <h2>Yeni proje</h2>
            <p className="hint">
              Seri format: <strong>SN-12345</strong>. Proje format:
              <strong> PRJ-YYYY-####</strong>.
            </p>
            <form className="form grid-form" onSubmit={handleCreateProject}>
              <label>
                Seri numarasi
                <input
                  type="text"
                  placeholder="SN-12345"
                  value={productForm.serial}
                  onChange={handleProductChange("serial")}
                />
              </label>
              <label>
                Musteri
                <input
                  type="text"
                  placeholder="ACME"
                  value={productForm.customer}
                  onChange={handleProductChange("customer")}
                />
              </label>
              <label>
                Proje soneki
                <input
                  type="text"
                  placeholder="0001"
                  value={productForm.projectSuffix}
                  onChange={handleProductChange("projectSuffix")}
                />
              </label>
              <label>
                Proje kodu
                <input type="text" value={projectCode} readOnly />
              </label>
              <label>
                Urun tipi
                <input
                  type="text"
                  placeholder="HGU-450"
                  value={productForm.productType}
                  onChange={handleProductChange("productType")}
                />
              </label>
              <label>
                Yil
                <input type="text" value={productForm.year} readOnly />
              </label>
              <button type="submit">Proje olustur</button>
            </form>
            {productStatus.message ? (
              <div className={`status-chip ${productStatus.type}`}>{productStatus.message}</div>
            ) : null}
          </section>
        ) : null}

        {user && activePage === "uploads" ? (
          <section className="grid detay-grid">
            <div className="panel">
              <h2>Kontrol Listesi</h2>
              {!currentProject ? <p className="hint">Once proje secin.</p> : null}
              <ul className="checklist">
                {checklist.map((item) => (
                  <li key={item.id} className={item.completed ? "done" : ""}>
                    <label>
                      <input
                        type="checkbox"
                        checked={item.completed}
                        onChange={() => toggleChecklistItem(item)}
                      />
                      <span>{item.itemKey.replace(/_/g, " ").toUpperCase()}</span>
                    </label>
                  </li>
                ))}
              </ul>
              {currentProject && checklist.length === 0 && <p className="hint">Liste yukleniyor veya bos...</p>}
            </div>

            <div className="panel">
              <h2>Fotograflar</h2>
              {!currentProject ? <p className="hint">Once Projeler menuden bir proje secin.</p> : (
                <div className="photo-grid-container">
                  {PHOTO_SLOTS.map((slot) => {
                    // Find uploaded file that matches this slot key (check for timestamp prefix too)
                    // Matches: "onden.jpg", "123456_onden.jpg", "onden_old.png"
                    const existingFile = findSlotFile(slot, projectFiles);

                    // Use local slot preview first, then cached thumbnail preview
                    const displayUrl =
                      slotPreviews[slot.key] ||
                      photoPreviews[existingFile?.id] ||
                      (existingFile?.fileUrl?.startsWith("blob:") ? existingFile.fileUrl : null);
                    const isLoadingPreview = !!existingFile && !displayUrl;

                    return (
                      <label key={slot.id} className={`photo-slot ${existingFile ? "has-photo" : ""}`}>
                        <input
                           type="file"
                           className="visually-hidden"
                           accept="image/*"
                           capture="environment"
                           onChange={(e) => handleGridFileSelect(slot, e)}
                        />
                        {existingFile && displayUrl ? (
                          <>
                            <img src={displayUrl} alt={slot.label} />
                            <div className="slot-overlay">
                              <span className="material-icons-round">photo_camera</span>
                            </div>
                          </>
                        ) : (
                          <div className="slot-content">
                            <span className="slot-icon">photo_camera</span>
                            <span className="slot-label">
                              {isLoadingPreview ? "Yukleniyor..." : slot.label}
                            </span>
                          </div>
                        )}
                      </label>
                    );
                  })}
                </div>
              )}

              <h2>Diger Dosyalar</h2>
              {!currentProject ? (
                <p className="hint">Once Projeler menuden bir proje secin.</p>
              ) : null}
              <form className="form upload-grid" onSubmit={handleUpload}>
                <label>
                  Dosya tipi
                  <select value={uploadForm.type} onChange={handleUploadChange("type")}>
                    <option value="test_report">Test raporu</option>
                    <option value="label">Etiket (PDF vb)</option>
                    <option value="project_file">Proje dosyasi</option>
                    <option value="photo">Diger Foto</option>
                  </select>
                </label>
                {uploadForm.type === "project_file" ? (
                  <label>
                    Proje kategorisi
                    <select value={uploadForm.category} onChange={handleUploadChange("category")}>
                      <option value="Drawings">Cizimler</option>
                      <option value="Hydraulic">Hidrolik</option>
                      <option value="Electrical">Elektrik</option>
                      <option value="Software">Yazilim</option>
                    </select>
                  </label>
                ) : null}
                <div className="file-input-group">
                  <span className="input-label">Dosya sec</span>
                  <label className={`file-drop-zone ${uploadForm.files.length ? "has-files" : ""}`}>
                    <input
                      type="file"
                      className="visually-hidden"
                      accept={uploadForm.type === "photo" ? "image/*" : "*/*"}
                      capture={uploadForm.type === "photo" ? "environment" : undefined}
                      multiple
                      onChange={handleUploadChange("files")}
                    />
                    <div className="drop-content">
                      <span className="drop-icon">{uploadForm.files.length ? "check_circle" : "cloud_upload"}</span>
                      <span className="drop-text">
                        {uploadForm.files.length > 0
                          ? `${uploadForm.files.length} dosya hazir`
                          : "Dosyalari secin veya buraya birakin"}
                      </span>
                    </div>
                  </label>
                </div>
                <button type="submit">Yukle</button>
              </form>
              {uploadStatus.message ? (
                <div className={`status-chip ${uploadStatus.type}`}>{uploadStatus.message}</div>
              ) : null}
            </div>

            <div className="panel">
              <h2>Yuklenen Dosyalar</h2>
              <ul className="list file-list">
                {projectFiles.map((file) => (
                  <li key={file.id}>
                    <div>
                      <strong>{file.type.toUpperCase()}</strong>
                      <span>{file.fileName}</span>
                    </div>
                    <a
                      href={file.fileUrl}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="button ghost"
                    >
                      Goruntule
                    </a>
                  </li>
                ))}
                {projectFiles.length === 0 && <p className="hint">Henuz dosya yuklenmemis.</p>}
              </ul>
            </div>

            <div className="panel">
              <h3>Proje Notlari</h3>
              <textarea
                placeholder="Proje notlarini ekleyin..."
                value={noteText}
                onChange={(event) => setNoteText(event.target.value)}
              />
              <div className="row-actions">
                <button type="button" onClick={handleSaveNote}>
                  Notu kaydet
                </button>
                {noteStatus.message ? (
                  <span className={`status-chip ${noteStatus.type}`}>{noteStatus.message}</span>
                ) : null}
              </div>
            </div>
          </section>
        ) : null}
      </main>
    </div>
  );
}
