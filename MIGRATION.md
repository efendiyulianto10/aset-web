# Apps Script → Next.js + Supabase + Vercel

## Prinsip

Source Apps Script lama dipakai sebagai **reference/blueprint**, bukan production runtime.

- `legacy-reference/Code.gs` — referensi backend/business logic lama
- `legacy-reference/index.html` — referensi frontend/UI/UX lama
- New runtime — Next.js
- Database — Supabase PostgreSQL
- Authentication — Supabase Auth
- File storage — Supabase Storage
- Deployment — Vercel

## Functional scope

The migration must preserve the existing workflows and permissions, including:

1. Login / authentication
2. Dashboard
3. Purchase Request
4. Purchasing
5. Dispatch
6. Production
7. Consumption
8. Inventory
9. Stock Ledger
10. Stock Adjustment
11. Stock Opname
12. Batch & Expiry
13. Reports
14. Items
15. Supplier / Vendors
16. Recipe
17. Branch
18. User / RBAC
19. Settings
20. Logs

## Important

Do not copy Apps Script APIs directly into production. Re-implement business rules in a typed, server-safe Next.js/Supabase architecture.

Passwords from the legacy system must not be migrated as plaintext credentials; use Supabase Auth.

## Migration order

Reference → database schema → auth/RBAC → core business logic → modules → UI → validation/testing → Vercel deployment.
