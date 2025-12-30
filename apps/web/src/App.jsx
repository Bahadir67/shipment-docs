import { useEffect, useMemo, useState } from "react";
import { addUpload, listUploads, deleteUpload } from "./offlineQueue.js";

const badges = [
  "Tablet-first PWA",
  "QR-based access",
  "OneDrive / SharePoint",
  "Checklist + photos"
];

export default function App() {
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [status, setStatus] = useState({ type: "", message: "" });
  const [user, setUser] = useState(null);
  const [products, setProducts] = useState([]);
  const [productForm, setProductForm] = useState({
    serial: "",
    customer: "",
    project: "",
    productType: "",
    year: new Date().getFullYear().toString()
  });
  const [productStatus, setProductStatus] = useState({ type: "", message: "" });
  const [uploadForm, setUploadForm] = useState({
    productId: "",
    type: "photo",
    category: "Drawings",
    file: null
  });
  const [uploadStatus, setUploadStatus] = useState({ type: "", message: "" });
  const [isOnline, setIsOnline] = useState(navigator.onLine);
  const [syncing, setSyncing] = useState(false);
  const [pendingUploads, setPendingUploads] = useState(0);
  const apiBase = import.meta.env.VITE_API_URL || "http://localhost:3000";
  const tokenKey = "shipment_docs_token";
  const pendingProductsKey = "shipment_docs_pending_products";

  const handleLogout = () => {
    localStorage.removeItem(tokenKey);
    setUser(null);
    setStatus({ type: "", message: "" });
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
  };

  const refreshPendingUploads = async () => {
    try {
      const uploads = await listUploads();
      setPendingUploads(uploads.length);
    } catch (error) {
      setPendingUploads(0);
    }
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
        // Keep in queue
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
    if (field === "file") {
      const file = event.target.files && event.target.files[0];
      setUploadForm((prev) => ({ ...prev, file }));
      return;
    }
    setUploadForm((prev) => ({ ...prev, [field]: event.target.value }));
  };

  const handleCreateProduct = async (event) => {
    event.preventDefault();
    setProductStatus({ type: "", message: "" });
    const token = localStorage.getItem(tokenKey);
    if (!token) {
      setProductStatus({ type: "error", message: "Please sign in first." });
      return;
    }
    const { serial, customer, project } = productForm;
    if (!serial || !customer || !project) {
      setProductStatus({ type: "error", message: "Serial, customer, and project are required." });
      return;
    }
    if (!navigator.onLine) {
      enqueueProduct({
        serial: productForm.serial,
        customer: productForm.customer,
        project: productForm.project,
        productType: productForm.productType,
        year: productForm.year
      });
      setProductStatus({ type: "success", message: "Queued for sync." });
      setProductForm((prev) => ({
        ...prev,
        serial: "",
        customer: "",
        project: "",
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
        body: JSON.stringify({
          serial: productForm.serial,
          customer: productForm.customer,
          project: productForm.project,
          productType: productForm.productType,
          year: productForm.year
        })
      });
      if (!response.ok) {
        const payload = await response.json().catch(() => ({}));
        setProductStatus({ type: "error", message: payload.error || "Create failed." });
        return;
      }
      const payload = await response.json();
      setProductStatus({ type: "success", message: "Product created." });
      setProductForm((prev) => ({
        ...prev,
        serial: "",
        customer: "",
        project: "",
        productType: ""
      }));
      setProducts((prev) => [payload, ...prev]);
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
    if (!uploadForm.productId || !uploadForm.file) {
      setUploadStatus({ type: "error", message: "Select product and file." });
      return;
    }
    if (!navigator.onLine) {
      await addUpload({
        productId: uploadForm.productId,
        type: uploadForm.type,
        category: uploadForm.type === "project_file" ? uploadForm.category : null,
        file: uploadForm.file,
        fileName: uploadForm.file.name,
        mimeType: uploadForm.file.type
      });
      setUploadStatus({ type: "success", message: "Upload queued for sync." });
      setUploadForm((prev) => ({ ...prev, file: null }));
      refreshPendingUploads();
      return;
    }
    try {
      const form = new FormData();
      form.append("type", uploadForm.type);
      if (uploadForm.type === "project_file") {
        form.append("category", uploadForm.category);
      }
      form.append("file", uploadForm.file);
      const response = await fetch(`${apiBase}/products/${uploadForm.productId}/files`, {
        method: "POST",
        headers: { Authorization: `Bearer ${token}` },
        body: form
      });
      if (!response.ok) {
        const payload = await response.json().catch(() => ({}));
        setUploadStatus({ type: "error", message: payload.error || "Upload failed." });
        return;
      }
      setUploadStatus({ type: "success", message: "Uploaded." });
      setUploadForm((prev) => ({ ...prev, file: null }));
    } catch (error) {
      setUploadStatus({ type: "error", message: "Network error. Try again." });
    }
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

  const selectableProducts = useMemo(
    () => products.filter((item) => !String(item.id || "").startsWith("temp-")),
    [products]
  );

  return (
    <main className="shell">
      <header className="top">
        <div className="brand">
          <span className="brand-mark">SD</span>
          <div>
            <p className="brand-title">Shipment Docs</p>
            <p className="brand-sub">MVP Demo Workspace</p>
          </div>
        </div>
        <div className="status">
          <span className="pulse" aria-hidden="true" />
          Sync ready
        </div>
      </header>

      <section className="hero">
        <div className="hero-copy">
          <h1>
            Shipments documented,
            <span> clean and fast.</span>
          </h1>
          <p>
            Capture photos, checklist items, and metadata in a single product
            record. Generate a shareable packet and keep everything stored in
            OneDrive.
          </p>
          <div className="badge-row">
            {badges.map((label) => (
              <span key={label} className="badge">
                {label}
              </span>
            ))}
          </div>
          <div className="callouts">
            <div>
              <h3>Workspace</h3>
              <p>ShipmentDocs/2025/Customer/Project/Serial</p>
            </div>
            <div>
              <h3>Capture kit</h3>
              <p>Front, back, panel, label, packaging</p>
            </div>
            <div>
              <h3>Output</h3>
              <p>Print-ready view + viewer</p>
            </div>
          </div>
        </div>

        <aside className="login">
          <div className="card">
            {user ? (
              <>
                <h2>Welcome back</h2>
                <p className="card-sub">Session restored.</p>
                <div className={`sync-pill ${isOnline ? "online" : "offline"}`}>
                  {isOnline ? "Online" : "Offline"} • {pendingUploads} pending uploads
                </div>
                <div className="user-pill">
                  Signed in as <strong>{user.username}</strong>
                </div>
                <div className="session-actions">
                  <button type="button" onClick={handleLogout}>
                    Sign out
                  </button>
                  <button type="button" className="ghost" onClick={syncAll} disabled={syncing}>
                    {syncing ? "Syncing..." : "Sync now"}
                  </button>
                </div>
                <p className="card-sub">
                  Offline mode will queue products and uploads automatically.
                </p>
                <form className="product-form" onSubmit={handleCreateProduct}>
                  <label>
                    Serial number
                    <input
                      type="text"
                      placeholder="SN-1042"
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
                    Project
                    <input
                      type="text"
                      placeholder="PRJ-17"
                      value={productForm.project}
                      onChange={handleProductChange("project")}
                    />
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
                    <input
                      type="number"
                      placeholder="2025"
                      value={productForm.year}
                      onChange={handleProductChange("year")}
                    />
                  </label>
                  <button type="submit">Create product</button>
                </form>
                {productStatus.message ? (
                  <div className={`status-chip ${productStatus.type}`}>
                    {productStatus.message}
                  </div>
                ) : null}
                <form className="upload-form" onSubmit={handleUpload}>
                  <h3>Upload file</h3>
                  <label>
                    Product
                    <select
                      value={uploadForm.productId}
                      onChange={handleUploadChange("productId")}
                    >
                      <option value="">Select product</option>
                      {selectableProducts.map((item) => (
                        <option key={item.id} value={item.id}>
                          {item.serial} • {item.project}
                        </option>
                      ))}
                    </select>
                  </label>
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
                      <select
                        value={uploadForm.category}
                        onChange={handleUploadChange("category")}
                      >
                        <option value="Drawings">Drawings</option>
                        <option value="Hydraulic">Hydraulic</option>
                        <option value="Electrical">Electrical</option>
                        <option value="Software">Software</option>
                      </select>
                    </label>
                  ) : null}
                  <label>
                    File
                    <input
                      type="file"
                      accept={uploadForm.type === "photo" ? "image/*" : "*/*"}
                      capture={uploadForm.type === "photo" ? "environment" : undefined}
                      onChange={handleUploadChange("file")}
                    />
                  </label>
                  <button type="submit">Upload</button>
                </form>
                {uploadStatus.message ? (
                  <div className={`status-chip ${uploadStatus.type}`}>
                    {uploadStatus.message}
                  </div>
                ) : null}
                <div className="product-list">
                  <h3>Recent products</h3>
                  {products.length ? (
                    <ul>
                      {products.slice(0, 5).map((item) => (
                        <li key={item.id}>
                          <span>{item.serial}</span>
                          <span>{item.customer}</span>
                          <span>{item.project}</span>
                        </li>
                      ))}
                    </ul>
                  ) : (
                    <p className="card-sub">No products yet.</p>
                  )}
                </div>
              </>
            ) : (
              <>
                <h2>Sign in</h2>
                <p className="card-sub">
                  Use your username and password to access the workspace.
                </p>
                <form onSubmit={handleLogin}>
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
                <div className="divider">or</div>
                <button type="button" className="ghost">
                  Scan QR to open product
                </button>
                <p className="card-sub">Forgot password? Ask an admin to reset it.</p>
              </>
            )}
          </div>
          <div className="card mini">
            <div>
              <h4>Active lane</h4>
              <p>QC - Line B</p>
            </div>
            <div>
              <h4>Open records</h4>
              <p>12</p>
            </div>
          </div>
        </aside>
      </section>
    </main>
  );
}
