import React from "react";
import ReactDOM from "react-dom/client";
import App from "./App.jsx";
import "./styles.css";
import { registerSW } from "virtual:pwa-register";

if ("serviceWorker" in navigator) {
  window.addEventListener("load", () => {
    registerSW({
      immediate: true,
      onOfflineReady() {
        localStorage.setItem("shipment_docs_offline_ready", "true");
        window.dispatchEvent(new Event("pwa-offline-ready"));
      }
    });
  });
}

ReactDOM.createRoot(document.getElementById("root")).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
