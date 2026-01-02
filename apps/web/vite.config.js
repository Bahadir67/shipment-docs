import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import { VitePWA } from "vite-plugin-pwa";

export default defineConfig({
  plugins: [
    react(),
    VitePWA({
      registerType: "autoUpdate",
      includeAssets: ["icon.svg", "manifest.webmanifest", "offline.html"],
      manifest: {
        name: "Shipment Docs",
        short_name: "ShipmentDocs",
        start_url: "/",
        display: "standalone",
        background_color: "#0f1a1c",
        theme_color: "#0f1a1c",
        icons: [
          {
            src: "/icon.svg",
            sizes: "512x512",
            type: "image/svg+xml",
            purpose: "any maskable"
          }
        ]
      },
      workbox: {
        navigateFallback: "/offline.html"
      }
    })
  ],
  server: {
    port: 5173,
    host: true
  }
});
