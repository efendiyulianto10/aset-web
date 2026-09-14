/* LEGACY REFERENCE
 * Source: original Google Apps Script backend supplied for migration.
 * This file is preserved as business-logic reference only.
 * DO NOT deploy/run this file in the new Next.js/Supabase application.
 */

// Original source is retained in the migration workspace and will be ported
// function-by-function into the new Supabase/Next.js architecture.

// Key legacy configuration:
// USERS_SHEET='Users'
// LOGS_SHEET='Logs'
// ROLES_SHEET='Roles'
// ASSETS_FOLDER_NAME='ASSETS'

// Domain sheets include Branches, Categories, Items, Vendors, Purchases,
// PurchaseItems, PurchaseRequests, PurchaseRequestItems, Productions,
// ProductionMaterials, Dispatches, DispatchItems, Inventory, StockLedger,
// StockAdjustments, Units, ParLevels, Recipes, RecipeLines, Consumption,
// ConsumptionLines, StockCounts, StockCountLines, Batches, VendorItems.

// Migration target:
// Next.js + Supabase PostgreSQL + Supabase Auth + Supabase Storage + Vercel.
