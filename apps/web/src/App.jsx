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
    } catch (error) {
      setStatus({ type: "error", message: "Unable to restore session." });
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
                <button type="button" onClick={handleLogout}>
                  Sign out
                </button>
                <p className="card-sub">Ready to open a product record.</p>
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
