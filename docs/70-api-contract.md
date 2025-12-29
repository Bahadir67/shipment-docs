# API Contract (Draft)

Backend provides two groups of endpoints: product API and Graph proxy API.

## Product API (apps/api)

POST /products
- Create a product record and create the OneDrive folder
- Request body:
  - serial
  - customer
  - project
  - product_type (optional)
  - year
- Response:
  - product id
  - onedrive_folder_id

GET /products/:id
- Fetch product details, checklist, and files

POST /products/:id/photos
- Upload photo and save metadata
- Request body:
  - category
  - index
  - file (multipart)

POST /products/:id/checklist
- Update checklist state
- Request body:
  - category
  - completed

POST /products/:id/files
- Upload test report, label, or project file
- Request body:
  - type (test_report | label | project_file)
  - category (optional: drawings | hydraulic | electrical | software)
  - file (multipart)

POST /products/:id/close
- Validate required photo categories
- Set status to closed

POST /products/:id/view
- Generate print-ready HTML view (no PDF required)

GET /products/:id/files/:fileId/view
- View a file through the app (logs view event + admin email)

GET /products/:id/files/:fileId/download
- Admin-only download (required for software source archives)

## Graph Proxy API

POST /graph/folders
- Create product folder and subfolders

POST /graph/uploads
- Upload to target folder

POST /graph/share-link
- Create anonymous share link (if policy allows)

GET /graph/items/:itemId
- Fetch metadata for validation/debug

GET /graph/health
- Token and permission check
