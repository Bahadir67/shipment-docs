const badges = [
  "Tablet-first PWA",
  "QR-based access",
  "OneDrive / SharePoint",
  "Checklist + photos"
];

export default function App() {
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
            <h2>Sign in</h2>
            <p className="card-sub">
              Use your Entra ID to access the live workspace.
            </p>
            <form>
              <label>
                Work email
                <input type="email" placeholder="name@company.com" />
              </label>
              <label>
                Access code
                <input type="password" placeholder="Enter access code" />
              </label>
              <button type="button">Continue with Entra</button>
            </form>
            <div className="divider">or</div>
            <button type="button" className="ghost">
              Scan QR to open product
            </button>
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
