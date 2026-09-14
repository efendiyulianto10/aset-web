-- Secure mutation layer and Supabase Auth profile bootstrap.

create or replace function public.can_action_page(p_page text, p_action text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select case p_action
    when 'add' then exists(select 1 from public.role_permissions rp where rp.role_key = public.current_role() and rp.page_key = p_page and rp.can_add)
    when 'edit' then exists(select 1 from public.role_permissions rp where rp.role_key = public.current_role() and rp.page_key = p_page and rp.can_edit)
    when 'delete' then exists(select 1 from public.role_permissions rp where rp.role_key = public.current_role() and rp.page_key = p_page and rp.can_delete)
    else false
  end;
$$;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles(id, username, email, role_key, status)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'username', split_part(new.email, '@', 1)),
    new.email,
    'Pending',
    'Pending'
  )
  on conflict (id) do update set email = excluded.email;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

-- Master-data writes. Admin is intentionally broad; other roles follow page permissions.
create policy branches_insert on public.branches for insert to authenticated
with check (public.is_admin() or public.can_action_page('branches','add'));
create policy branches_update on public.branches for update to authenticated
using (public.is_admin() or public.can_action_page('branches','edit'))
with check (public.is_admin() or public.can_action_page('branches','edit'));
create policy branches_delete on public.branches for delete to authenticated
using (public.is_admin() or public.can_action_page('branches','delete'));

create policy categories_insert on public.categories for insert to authenticated
with check (public.is_admin() or public.can_action_page('categories','add'));
create policy categories_update on public.categories for update to authenticated
using (public.is_admin() or public.can_action_page('categories','edit'))
with check (public.is_admin() or public.can_action_page('categories','edit'));
create policy categories_delete on public.categories for delete to authenticated
using (public.is_admin() or public.can_action_page('categories','delete'));

create policy vendors_insert on public.vendors for insert to authenticated
with check (public.is_admin() or public.can_action_page('vendors','add'));
create policy vendors_update on public.vendors for update to authenticated
using (public.is_admin() or public.can_action_page('vendors','edit'))
with check (public.is_admin() or public.can_action_page('vendors','edit'));
create policy vendors_delete on public.vendors for delete to authenticated
using (public.is_admin() or public.can_action_page('vendors','delete'));

create policy items_insert on public.items for insert to authenticated
with check (public.is_admin() or public.can_action_page('items','add'));
create policy items_update on public.items for update to authenticated
using (public.is_admin() or public.can_action_page('items','edit'))
with check (public.is_admin() or public.can_action_page('items','edit'));
create policy items_delete on public.items for delete to authenticated
using (public.is_admin() or public.can_action_page('items','delete'));

create policy vendor_items_insert on public.vendor_items for insert to authenticated
with check (public.is_admin() or public.can_action_page('vendoritems','add'));
create policy vendor_items_update on public.vendor_items for update to authenticated
using (public.is_admin() or public.can_action_page('vendoritems','edit'))
with check (public.is_admin() or public.can_action_page('vendoritems','edit'));
create policy vendor_items_delete on public.vendor_items for delete to authenticated
using (public.is_admin() or public.can_action_page('vendoritems','delete'));

create policy par_levels_insert on public.par_levels for insert to authenticated
with check (public.is_admin() or public.can_action_page('parlevels','add'));
create policy par_levels_update on public.par_levels for update to authenticated
using (public.is_admin() or public.can_action_page('parlevels','edit'))
with check (public.is_admin() or public.can_action_page('parlevels','edit'));
create policy par_levels_delete on public.par_levels for delete to authenticated
using (public.is_admin() or public.can_action_page('parlevels','delete'));

create policy recipes_insert on public.recipes for insert to authenticated
with check (public.is_admin() or public.can_action_page('recipes','add'));
create policy recipes_update on public.recipes for update to authenticated
using (public.is_admin() or public.can_action_page('recipes','edit'))
with check (public.is_admin() or public.can_action_page('recipes','edit'));
create policy recipes_delete on public.recipes for delete to authenticated
using (public.is_admin() or public.can_action_page('recipes','delete'));

create policy recipe_lines_insert on public.recipe_lines for insert to authenticated
with check (public.is_admin() or public.can_action_page('recipes','add'));
create policy recipe_lines_update on public.recipe_lines for update to authenticated
using (public.is_admin() or public.can_action_page('recipes','edit'))
with check (public.is_admin() or public.can_action_page('recipes','edit'));
create policy recipe_lines_delete on public.recipe_lines for delete to authenticated
using (public.is_admin() or public.can_action_page('recipes','delete'));

-- Logs are append-only from authenticated application users; server-side audit code should set the actor.
create policy activity_logs_insert on public.activity_logs for insert to authenticated with check (user_id = auth.uid() or public.is_admin());

-- Profiles: users can update only their presentation fields; Admin can manage role/status/branch.
create policy profiles_update_self on public.profiles for update to authenticated
using (id = auth.uid() or public.is_admin())
with check (id = auth.uid() or public.is_admin());

-- Units are controlled master data. Only Admin may mutate them.
create policy units_insert_admin on public.units for insert to authenticated with check (public.is_admin());
create policy units_update_admin on public.units for update to authenticated using (public.is_admin()) with check (public.is_admin());
create policy units_delete_admin on public.units for delete to authenticated using (public.is_admin());
