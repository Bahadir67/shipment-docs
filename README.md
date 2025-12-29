# shipment-docs
Sevkiyat dokumantasyon sistemi (MVP). This repo currently contains the project skeleton and baseline documentation only (no runtime code yet).

## Goal
Capture photos + metadata + checklists for shipment-ready products, store per-product folders on OneDrive/SharePoint, and generate a Shipment Package PDF.

## Status
Sprint-0: repo structure and documentation templates.

## Monorepo layout
- `apps/web` - Tablet PWA (React/Vite target)
- `apps/api` - Graph proxy + PDF + DB API
- `packages/shared` - Shared types and utilities
- `docs` - Product, storage, and process documentation

## Branch strategy
- `main` and `dev` are protected branches
- Development flow: `feature/*` -> PR -> `dev` -> PR -> `main`
- Allowed merges: squash or rebase (no merge commits)

## Next steps
See `docs/00-overview.md` and Sprint-1 plan at the bottom of this file.

## Sprint-1 starter plan (draft)
- Define Graph API routes for folder, upload, and sharing link
- Draft DB schema for Products, Photos, Checklists, and Files
- Define minimal API endpoints for product create and file upload
