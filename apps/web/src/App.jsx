import { useEffect, useMemo, useState } from "react";
import { addUpload, listUploads, deleteUpload } from "./offlineQueue.js";

const serialRegex = /^SN-\d{5}$/;
const projectSuffixRegex = /^\d{4}$/;

const menuItems = [
  { id: "dashboard", label: "Dashboard" },
  { id: "projects", label: "Projects" },
  { id: "new", label: "New project" },
  { id: "uploads", label: "Uploads" }
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
  const [uploadForm, setUploadForm] = useState({
    type: "photo",
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

  const isAdmin = user?.role === "admin";

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
      setStatus({ type: "error", message: "Unable to restore session." });
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
      setProducts([...(pending || []), ...(payload.data || [])]);
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
      setProductStatus({ type: "error", message: "Please sign in first." });
      return;
    }
    if (!serialRegex.test(productForm.serial)) {
      setProductStatus({
        type: "error",
        message: "Serial format must be SN-12345."
      });
      return;
    }
    if (!projectSuffixRegex.test(productForm.projectSuffix)) {
      setProductStatus({
        type: "error",
        message: "Project suffix must be 4 digits."
      });
      return;
    }
    if (!productForm.customer) {
      setProductStatus({ type: "error", message: "Customer is required." });
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
      setProductStatus({ type: "success", message: "Queued for sync." });
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
        setProductStatus({ type: "error", message: result.error || "Create failed." });
        return;
      }
      const created = await response.json();
      setProductStatus({ type: "success", message: "Project created." });
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
      setProductStatus({ type: "error", message: "Network error. Try again." });
    }
  };

  const handleUpload = async (event) => {
    event.preventDefault();
    setUploadStatus({ type: "", message: "" });
    const token = localStorage.getItem(tokenKey);
    if (!token) {
      setUploadStatus({ type: "error", message: "Please sign in first." });
      return;
    }
    if (!currentProject || String(currentProject.id || "").startsWith("temp-")) {
      setUploadStatus({ type: "error", message: "Project is not synced yet." });
      return;
    }
    if (!uploadForm.files.length) {
      setUploadStatus({ type: "error", message: "Select at least one file." });
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
      setUploadStatus({ type: "success", message: "Upload queued for sync." });
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
          setUploadStatus({ type: "error", message: payload.error || "Upload failed." });
          return;
        }
      }
      setUploadStatus({ type: "success", message: "Uploaded." });
      setUploadForm((prev) => ({ ...prev, files: [] }));
    } catch (error) {
      setUploadStatus({ type: "error", message: "Network error. Try again." });
    }
  };

  const handleSaveNote = () => {
    if (!currentProject) return;
    const notes = loadNotes();
    notes[currentProject.id] = noteText;
    saveNotes(notes);
    setNoteStatus({ type: "success", message: "Note saved." });
  };

  const handleLogin = async (event) => {
    event.preventDefault();
    setStatus({ type: "", message: "" });
    if (!username || !password) {
      setStatus({ type: "error", message: "Username and password are required." });
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
        const message = payload.error || "Login failed.";
        setStatus({ type: "error", message });
        return;
      }
      const payload = await response.json();
      localStorage.setItem(tokenKey, payload.token);
      setUser(payload.user);
      fetchProducts(payload.token);
      setStatus({ type: "success", message: "Signed in successfully." });
      setPassword("");
    } catch (error) {
      setStatus({ type: "error", message: "Network error. Try again." });
    }
  };

  const handleLogout = () => {
    localStorage.removeItem(tokenKey);
    setUser(null);
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
            <p className="brand-sub">MVP Workspace</p>
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
                {isOnline ? "Online" : "Offline"} • {pendingUploads} queued
              </div>
              <div className="user-pill">
                {user.username} • {user.role}
              </div>
              <button type="button" className="ghost" onClick={syncAll} disabled={syncing}>
                {syncing ? "Syncing..." : "Sync now"}
              </button>
              <button type="button" onClick={handleLogout}>
                Sign out
              </button>
            </>
          ) : (
            <p className="card-sub">Sign in to begin.</p>
          )}
        </div>
      </aside>

      <main className="main">
        <header className="topbar">
          <div>
            <h1>{menuItems.find((item) => item.id === activePage)?.label}</h1>
            <p>Tablet and desktop ready.</p>
          </div>
          <div className="status">
            <span className="pulse" aria-hidden="true" />
            Sync ready
          </div>
        </header>

        {currentProject ? (
          <section className="project-banner">
            <div>
              <p>Active project</p>
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
            <h2>Sign in</h2>
            <p>Use your username and password to access the workspace.</p>
            <form className="form" onSubmit={handleLogin}>
              <label>
                Username
                <input
                  type="text"
                  placeholder="qc_user"
                  value={username}
                  onChange={(event) => setUsername(event.target.value)}
                />
              </label>
              <label>
                Password
                <input
                  type="password"
                  placeholder="Enter password"
                  value={password}
                  onChange={(event) => setPassword(event.target.value)}
                />
              </label>
              <button type="submit">Sign in</button>
            </form>
            {status.message ? (
              <div className={`status-chip ${status.type}`}>{status.message}</div>
            ) : null}
          </section>
        ) : null}

        {user && activePage === "dashboard" ? (
          <section className="grid">
            <div className="panel">
              <h2>Quick stats</h2>
              <div className="stats">
                <div>
                  <h3>{visibleProjects.length}</h3>
                  <p>Active projects</p>
                </div>
                <div>
                  <h3>{pendingUploads}</h3>
                  <p>Queued uploads</p>
                </div>
                <div>
                  <h3>{isOnline ? "Online" : "Offline"}</h3>
                  <p>Connectivity</p>
                </div>
              </div>
              <p className="hint">
                Use “New project” to start, then go to “Uploads” to capture files.
              </p>
            </div>
            <div className="panel">
              <h2>Recent projects</h2>
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
                      Open
                    </button>
                  </li>
                ))}
              </ul>
            </div>
          </section>
        ) : null}

        {user && activePage === "projects" ? (
          <section className="panel">
            <h2>All projects</h2>
            <p className="hint">Only admins can edit or delete records.</p>
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
                      View
                    </button>
                    {isAdmin ? (
                      <>
                        <button type="button" className="ghost" onClick={() => startEdit(item)}>
                          Edit
                        </button>
                        <button type="button" className="danger" onClick={() => deleteProject(item.id)}>
                          Delete
                        </button>
                      </>
                    ) : null}
                  </div>
                  {editingProjectId === item.id ? (
                    <div className="edit-panel">
                      <label>
                        Serial
                        <input
                          value={editForm.serial}
                          onChange={(event) => setEditForm((prev) => ({
                            ...prev,
                            serial: event.target.value
                          }))}
                        />
                      </label>
                      <label>
                        Customer
                        <input
                          value={editForm.customer}
                          onChange={(event) => setEditForm((prev) => ({
                            ...prev,
                            customer: event.target.value
                          }))}
                        />
                      </label>
                      <label>
                        Project
                        <input
                          value={editForm.project}
                          onChange={(event) => setEditForm((prev) => ({
                            ...prev,
                            project: event.target.value
                          }))}
                        />
                      </label>
                      <label>
                        Product type
                        <input
                          value={editForm.productType}
                          onChange={(event) => setEditForm((prev) => ({
                            ...prev,
                            productType: event.target.value
                          }))}
                        />
                      </label>
                      <label>
                        Year
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
                          Save
                        </button>
                        <button type="button" className="ghost" onClick={cancelEdit}>
                          Cancel
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
            <h2>New project</h2>
            <p className="hint">
              Serial format: <strong>SN-12345</strong>. Project format:
              <strong> PRJ-YYYY-####</strong>.
            </p>
            <form className="form grid-form" onSubmit={handleCreateProject}>
              <label>
                Serial number
                <input
                  type="text"
                  placeholder="SN-12345"
                  value={productForm.serial}
                  onChange={handleProductChange("serial")}
                />
              </label>
              <label>
                Customer
                <input
                  type="text"
                  placeholder="ACME"
                  value={productForm.customer}
                  onChange={handleProductChange("customer")}
                />
              </label>
              <label>
                Project suffix
                <input
                  type="text"
                  placeholder="0001"
                  value={productForm.projectSuffix}
                  onChange={handleProductChange("projectSuffix")}
                />
              </label>
              <label>
                Project code
                <input type="text" value={projectCode} readOnly />
              </label>
              <label>
                Product type
                <input
                  type="text"
                  placeholder="HGU-450"
                  value={productForm.productType}
                  onChange={handleProductChange("productType")}
                />
              </label>
              <label>
                Year
                <input type="text" value={productForm.year} readOnly />
              </label>
              <button type="submit">Create project</button>
            </form>
            {productStatus.message ? (
              <div className={`status-chip ${productStatus.type}`}>{productStatus.message}</div>
            ) : null}
          </section>
        ) : null}

        {user && activePage === "uploads" ? (
          <section className="panel">
            <h2>Uploads</h2>
            {!currentProject ? (
              <p className="hint">Select a project from the Projects menu first.</p>
            ) : null}
            <form className="form upload-grid" onSubmit={handleUpload}>
              <label>
                File type
                <select value={uploadForm.type} onChange={handleUploadChange("type")}>
                  <option value="photo">Photo</option>
                  <option value="test_report">Test report</option>
                  <option value="label">Label</option>
                  <option value="project_file">Project file</option>
                </select>
              </label>
              {uploadForm.type === "project_file" ? (
                <label>
                  Project category
                  <select value={uploadForm.category} onChange={handleUploadChange("category")}>
                    <option value="Drawings">Drawings</option>
                    <option value="Hydraulic">Hydraulic</option>
                    <option value="Electrical">Electrical</option>
                    <option value="Software">Software</option>
                  </select>
                </label>
              ) : null}
              <label>
                Select files
                <input
                  type="file"
                  accept={uploadForm.type === "photo" ? "image/*" : "*/*"}
                  capture={uploadForm.type === "photo" ? "environment" : undefined}
                  multiple
                  onChange={handleUploadChange("files")}
                />
              </label>
              <button type="submit">Upload</button>
            </form>
            {uploadStatus.message ? (
              <div className={`status-chip ${uploadStatus.type}`}>{uploadStatus.message}</div>
            ) : null}

            <div className="note-panel">
              <h3>Project notes</h3>
              <textarea
                placeholder="Add notes for this project..."
                value={noteText}
                onChange={(event) => setNoteText(event.target.value)}
              />
              <div className="row-actions">
                <button type="button" onClick={handleSaveNote}>
                  Save note
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
