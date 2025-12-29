import { useEffect, useState } from "react";

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
  const apiBase = import.meta.env.VITE_API_URL || "http://localhost:3000";
  const tokenKey = "shipment_docs_token";

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
      setProducts(payload.data || []);
    } catch (error) {
      setProducts([]);
    }
  };

  const handleProductChange = (field) => (event) => {
    setProductForm((prev) => ({ ...prev, [field]: event.target.value }));
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
  }, []);

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
                <div className="user-pill">
                  Signed in as <strong>{user.username}</strong>
                </div>
                <div className="session-actions">
                  <button type="button" onClick={handleLogout}>
                    Sign out
                  </button>
                  <span className="card-sub">Ready to open a product record.</span>
                </div>
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
