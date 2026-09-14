# Migration Plan — Legacy Apps Script → Next.js + Supabase

## Reference
The original Google Apps Script backend and HTML frontend supplied in the conversation remain the authoritative reference for legacy behavior. They are not production runtime.

## Target
- Next.js / React
- Supabase PostgreSQL
- Supabase Auth
- Supabase Storage
- Vercel

## Functional scope
Login, Dashboard, Purchase Requests, Purchasing/GRN, Dispatches & Invoices, Production, Consumption, Inventory, Stock Ledger, Stock Adjustments, Stock Counts/Opname, Batches & Expiry, Reports, Items, Categories, Vendors, Vendor Price List, Branches & Locations, Recipes, Par Levels, Units, Users, Settings, Activity Logs, AI Assistant.

## Security migration
Legacy plaintext passwords must NOT be copied into production. User authentication is migrated to Supabase Auth. Branch scoping and role/page permissions are enforced server-side and through PostgreSQL RLS.

## Business rules to preserve
- Stock quantities use base units GRM / ML / PCS.
- Unit conversion uses the legacy unit registry and per-item pack quantity for count-based pack units.
- Item cost is stored per stock/display unit; base-unit cost is derived for ledger/value calculations.
- Branch scope includes the user's own site plus its direct child locations; Admin is global.
- Admin RBAC is super-user and its permissions are locked; non-super roles use page permissions v/a/e/d.
- Documents use yearly prefixes and four-digit sequence numbers.
- Soft deletion is used by legacy master/transaction entities where specified.
- Inventory and Stock Ledger are the stock-control spine; transaction migration must preserve movement semantics.
- Batch/expiry, stock adjustment approval, stock count variance, recipes, consumption and par levels remain separate domain concepts.

## Implementation order
1. Database schema + seed + RLS helpers
2. Supabase Auth + profiles + RBAC
3. Master data: branches, categories, units, vendors, items, vendor items
4. Inventory + ledger + conversion utilities
5. Purchase Requests
6. Purchasing / GRN
7. Dispatch
8. Production + recipes
9. Consumption
10. Stock Adjustments
11. Stock Counts / Opname
12. Batches / Expiry
13. Reports + Dashboard
14. Users + Settings + Logs
15. AI Assistant integration
16. Storage uploads
17. UI parity and mobile polish
18. Vercel deployment + smoke tests

## Rule
Do not treat a successful UI render as migration completion. A module is complete only when its workflow, validations, permissions, stock effects, audit/log behavior and relevant calculations match the legacy reference.
