# Architecture Decisions

This document captures MVP architectural decisions for the demo.

## Database
- Preferred: PostgreSQL
- Recommendation: Neon (lightweight hosted Postgres)
- Alternative: Supabase (if future auth/row-level access is needed)

## Auth and Roles
- App-managed login (username + password)
- Everyone can view project files and diagrams
- Admin can delete and reset user passwords
- Admin-only download for software source code archives
- Soft delete recommended

## Storage Target
- Phase 1: Personal OneDrive (demo)
- Phase 2: SharePoint site drive (production)
- Configurable drive target (personal vs sharepoint)

## Sharing and Access
- Files must be accessible from anywhere
- Viewing goes through the app so access can be logged
- Use anonymous share links only if policy allows

## Audit Logging
- Log every view event (user + timestamp)
- Retention: 5 years
- Send admin email on view events (SMTP)

## PDF Output
- PDF generation is optional
- Use print-ready HTML view + PDF viewer
- Revisit PDF generation if required later
