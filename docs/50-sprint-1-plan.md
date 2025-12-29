# Sprint-1 Plan

This document captures the minimal technical scope for Sprint-1 (working skeleton).

## Graph API endpoint list (backend proxy)
- POST /graph/folders
  - Create product folder at `/ShipmentDocs/{YEAR}/{CUSTOMER}/{PROJECT}/{SERIAL}/`
  - Create subfolders: Photos, Docs, Test, Label
- POST /graph/uploads
  - Upload file to target folder (photo, test report, label, PDF)
- POST /graph/share-link
  - Create internal sharing link for a file or folder
- GET /graph/items/:itemId
  - Fetch item metadata for validation/debug
- GET /graph/health
  - Validate Graph auth and token status

## Minimal DB schema
- products
  - id (uuid, pk)
  - serial (string, unique)
  - customer (string)
  - project (string)
  - product_type (string, optional)
  - year (int)
  - onedrive_folder_id (string)
  - status (enum: open, closed)
  - created_at, updated_at
- photos
  - id (uuid, pk)
  - product_id (fk)
  - category (enum)
  - index (int)
  - file_id (string)
  - file_url (string, optional)
  - created_at
- checklist_items
  - id (uuid, pk)
  - product_id (fk)
  - category (enum)
  - completed (bool)
  - updated_at
- files
  - id (uuid, pk)
  - product_id (fk)
  - type (enum: test_report, label, shipment_pdf)
  - file_id (string)
  - file_url (string, optional)
  - created_at

## Minimal API routes (apps/api)
- GET /health
- POST /products
  - Create product record
  - Create OneDrive folder
  - Persist onedrive_folder_id
- GET /products/:id
  - Fetch product + checklist + files
- POST /products/:id/photos
  - Upload photo to OneDrive
  - Save photo metadata
- POST /products/:id/checklist
  - Update checklist state
- POST /products/:id/files
  - Upload test report or label
- POST /products/:id/close
  - Validate required photo categories
  - Set status closed
- POST /products/:id/pdf
  - Generate shipment PDF
  - Upload to OneDrive
  - Save file record

## Notes
- Keep Graph calls behind the backend for client secret security.
- Store a meta.json in the product folder (optional, but recommended).
