create or replace function public.current_profile()
returns public.profiles
language sql stable security definer set search_path=public
as $$ select p from public.profiles p where p.id=auth.uid() limit 1 $$;

create or replace function public.current_role()
returns text
language sql stable security definer set search_path=public
as $$ select role_key from public.profiles where id=auth.uid() $$;

create or replace function public.is_admin()
returns boolean
language sql stable security definer set search_path=public
as $$ select exists(select 1 from public.profiles p join public.roles r on r.key=p.role_key where p.id=auth.uid() and r.is_super=true and p.status='Active') $$;

create or replace function public.can_view_page(p_page text)
returns boolean
language sql stable security definer set search_path=public
as $$ select public.is_admin() or exists(select 1 from public.profiles p join public.role_permissions rp on rp.role_key=p.role_key where p.id=auth.uid() and p.status='Active' and rp.page_key=p_page and rp.can_view=true) $$;

create or replace function public.has_branch_access(p_branch_id bigint)
returns boolean
language sql stable security definer set search_path=public
as $$
  select public.is_admin() or exists(
    select 1 from public.profiles p
    where p.id=auth.uid() and p.status='Active' and (
      p.branch_id=p_branch_id or
      exists(select 1 from public.branches child where child.id=p_branch_id and child.parent_id=p.branch_id)
    )
  )
$$;

-- Profiles: users may read their own profile; admins manage profiles through server-side admin workflows.
drop policy if exists profiles_select_own on public.profiles;
create policy profiles_select_own on public.profiles for select to authenticated using (id=auth.uid() or public.is_admin());

drop policy if exists roles_select_auth on public.roles;
create policy roles_select_auth on public.roles for select to authenticated using (true);

drop policy if exists role_permissions_select_auth on public.role_permissions;
create policy role_permissions_select_auth on public.role_permissions for select to authenticated using (true);

-- Branch reference data is readable by authenticated users; mutations will be routed through authorized server actions.
drop policy if exists branches_select_auth on public.branches;
create policy branches_select_auth on public.branches for select to authenticated using (public.is_admin() or public.has_branch_access(id));

drop policy if exists categories_select_auth on public.categories;
create policy categories_select_auth on public.categories for select to authenticated using (true);

drop policy if exists vendors_select_auth on public.vendors;
create policy vendors_select_auth on public.vendors for select to authenticated using (true);

drop policy if exists units_select_auth on public.units;
create policy units_select_auth on public.units for select to authenticated using (true);

drop policy if exists items_select_auth on public.items;
create policy items_select_auth on public.items for select to authenticated using (true);

drop policy if exists inventory_select_scope on public.inventory;
create policy inventory_select_scope on public.inventory for select to authenticated using (public.has_branch_access(branch_id));

drop policy if exists ledger_select_scope on public.stock_ledger;
create policy ledger_select_scope on public.stock_ledger for select to authenticated using (public.has_branch_access(branch_id));

drop policy if exists batches_select_scope on public.batches;
create policy batches_select_scope on public.batches for select to authenticated using (public.has_branch_access(branch_id));

drop policy if exists adjustments_select_scope on public.stock_adjustments;
create policy adjustments_select_scope on public.stock_adjustments for select to authenticated using (public.has_branch_access(branch_id));

drop policy if exists requests_select_scope on public.purchase_requests;
create policy requests_select_scope on public.purchase_requests for select to authenticated using (public.has_branch_access(branch_id) or public.has_branch_access(to_branch_id));

drop policy if exists purchases_select_scope on public.purchases;
create policy purchases_select_scope on public.purchases for select to authenticated using (public.has_branch_access(branch_id));

drop policy if exists dispatches_select_scope on public.dispatches;
create policy dispatches_select_scope on public.dispatches for select to authenticated using (public.has_branch_access(from_branch_id) or public.has_branch_access(to_branch_id));

drop policy if exists productions_select_scope on public.productions;
create policy productions_select_scope on public.productions for select to authenticated using (public.has_branch_access(branch_id));

drop policy if exists consumption_select_scope on public.consumption;
create policy consumption_select_scope on public.consumption for select to authenticated using (public.has_branch_access(branch_id));

drop policy if exists counts_select_scope on public.stock_counts;
create policy counts_select_scope on public.stock_counts for select to authenticated using (public.has_branch_access(branch_id));

drop policy if exists par_levels_select_scope on public.par_levels;
create policy par_levels_select_scope on public.par_levels for select to authenticated using (public.has_branch_access(branch_id));

drop policy if exists logs_select_admin on public.activity_logs;
create policy logs_select_admin on public.activity_logs for select to authenticated using (public.is_admin());

-- Child tables are scoped through their parent branch/document rather than exposing all rows.
drop policy if exists purchase_items_select_auth on public.purchase_items;
create policy purchase_items_select_auth on public.purchase_items for select to authenticated using (exists(select 1 from public.purchases p where p.id=purchase_id and public.has_branch_access(p.branch_id)));

drop policy if exists request_items_select_auth on public.purchase_request_items;
create policy request_items_select_auth on public.purchase_request_items for select to authenticated using (exists(select 1 from public.purchase_requests r where r.id=request_id and (public.has_branch_access(r.branch_id) or public.has_branch_access(r.to_branch_id))));

drop policy if exists dispatch_items_select_auth on public.dispatch_items;
create policy dispatch_items_select_auth on public.dispatch_items for select to authenticated using (exists(select 1 from public.dispatches d where d.id=dispatch_id and (public.has_branch_access(d.from_branch_id) or public.has_branch_access(d.to_branch_id))));

drop policy if exists production_materials_select_auth on public.production_materials;
create policy production_materials_select_auth on public.production_materials for select to authenticated using (exists(select 1 from public.productions p where p.id=production_id and public.has_branch_access(p.branch_id)));

drop policy if exists consumption_lines_select_auth on public.consumption_lines;
create policy consumption_lines_select_auth on public.consumption_lines for select to authenticated using (exists(select 1 from public.consumption c where c.id=consumption_id and public.has_branch_access(c.branch_id)));

drop policy if exists count_lines_select_auth on public.stock_count_lines;
create policy count_lines_select_auth on public.stock_count_lines for select to authenticated using (exists(select 1 from public.stock_counts c where c.id=count_id and public.has_branch_access(c.branch_id)));

drop policy if exists recipe_lines_select_auth on public.recipe_lines;
create policy recipe_lines_select_auth on public.recipe_lines for select to authenticated using (exists(select 1 from public.recipes r where r.id=recipe_id));

drop policy if exists vendor_items_select_auth on public.vendor_items;
create policy vendor_items_select_auth on public.vendor_items for select to authenticated using (true);
