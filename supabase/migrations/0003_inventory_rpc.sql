create or replace function public.apply_stock_movement(
  p_branch_id bigint,
  p_item_id bigint,
  p_qty_in numeric default 0,
  p_qty_out numeric default 0,
  p_movement_type text default 'ADJUSTMENT',
  p_reference_id bigint default null
)
returns public.inventory
language plpgsql
security invoker
set search_path=public
as $$
declare v_inventory public.inventory;
       v_new_qty numeric;
begin
  if not public.has_branch_access(p_branch_id) then raise exception 'Branch access denied'; end if;
  if p_qty_in < 0 or p_qty_out < 0 then raise exception 'Movement quantity must be positive'; end if;
  if p_qty_in = 0 and p_qty_out = 0 then raise exception 'Movement cannot be zero'; end if;

  insert into public.inventory(branch_id,item_id,qty)
  values(p_branch_id,p_item_id,0)
  on conflict(branch_id,item_id) do nothing;

  select * into v_inventory from public.inventory where branch_id=p_branch_id and item_id=p_item_id for update;
  v_new_qty := v_inventory.qty + p_qty_in - p_qty_out;
  if v_new_qty < 0 then raise exception 'Insufficient stock'; end if;

  update public.inventory set qty=v_new_qty,updated_at=now() where id=v_inventory.id returning * into v_inventory;

  insert into public.stock_ledger(branch_id,item_id,movement_type,reference_id,qty_in,qty_out,balance)
  values(p_branch_id,p_item_id,p_movement_type,p_reference_id,p_qty_in,p_qty_out,v_new_qty);

  return v_inventory;
end;
$$;

revoke all on function public.apply_stock_movement(bigint,bigint,numeric,numeric,text,bigint) from public;
grant execute on function public.apply_stock_movement(bigint,bigint,numeric,numeric,text,bigint) to authenticated;
