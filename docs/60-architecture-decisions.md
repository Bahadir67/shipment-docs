# Architecture Decisions

This document captures MVP architectural decisions for the demo.

## Database
- Preferred: PostgreSQL
- Recommendation: Neon (lightweight hosted Postgres)
- Alternative: Supabase (if future auth/row-level access is needed)

## Auth and Roles
- Entra ID only
- No role management for now
- Admin delete capability only (soft delete recommended)

## Storage Target
- Phase 1: Personal OneDrive (demo)
- Phase 2: SharePoint site drive (production)
- Configurable drive target (personal vs sharepoint)

## Sharing and Access
- Files must be accessible from anywhere
- Use anonymous share links if policy allows

## PDF Output
- PDF generation is optional
- Use print-ready HTML view + PDF viewer
- Revisit PDF generation if required later
