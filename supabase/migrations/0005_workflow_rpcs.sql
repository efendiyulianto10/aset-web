-- Atomic workflow layer. UI should call these functions rather than performing multi-table stock changes client-side.

create or replace function public.apply_stock_movement(
  p_branch_id bigint,
  p_item_id bigint,
  p_qty_in numeric default 0,
  p_qty_out numeric default 0,
  p_movement_type text default 'ADJUSTMENT',
  p_reference_id bigint default null,
  p_movement_date timestamptz default now()
) returns numeric
language plpgsql
security definer
set search_path = public
as $$
declare v_qty numeric; v_balance numeric;
begin
  if p_qty_in < 0 or p_qty_out < 0 or (p_qty_in = 0 and p_qty_out = 0) then raise exception 'Invalid stock movement'; end if;
  if not public.is_admin() and not public.has_branch_access(p_branch_id) then raise exception 'Branch access denied'; end if;
  insert into public.inventory(branch_id,item_id,qty) values(p_branch_id,p_item_id,0)
  on conflict(branch_id,item_id) do nothing;
  select qty into v_qty from public.inventory where branch_id=p_branch_id and item_id=p_item_id for update;
  v_balance := v_qty + p_qty_in - p_qty_out;
  if v_balance < 0 then raise exception 'Insufficient stock for item %', p_item_id; end if;
  update public.inventory set qty=v_balance, updated_at=now() where branch_id=p_branch_id and item_id=p_item_id;
  insert into public.stock_ledger(branch_id,item_id,movement_type,reference_id,qty_in,qty_out,balance,movement_date)
  values(p_branch_id,p_item_id,p_movement_type,p_reference_id,p_qty_in,p_qty_out,v_balance,p_movement_date);
  return v_balance;
end;
$$;

create or replace function public.create_purchase(
  p_grn_no text, p_vendor_id bigint, p_branch_id bigint, p_purchase_date date,
  p_vendor_invoice_no text, p_notes text, p_lines jsonb
) returns bigint
language plpgsql security definer set search_path=public
as $$
declare v_id bigint; v_line jsonb; v_item bigint; v_qty numeric; v_cost numeric; v_total numeric:=0;
begin
  if not public.is_admin() and not public.can_action_page('purchases','add') then raise exception 'Permission denied'; end if;
  if not public.is_admin() and not public.has_branch_access(p_branch_id) then raise exception 'Branch access denied'; end if;
  insert into public.purchases(grn_no,vendor_id,branch_id,vendor_invoice_no,purchase_date,status,received_by,notes)
  values(p_grn_no,p_vendor_id,p_branch_id,p_vendor_invoice_no,coalesce(p_purchase_date,current_date),'RECEIVED',auth.uid(),p_notes) returning id into v_id;
  for v_line in select * from jsonb_array_elements(p_lines) loop
    v_item := (v_line->>'item_id')::bigint; v_qty := (v_line->>'qty')::numeric; v_cost := coalesce((v_line->>'unit_cost')::numeric,0);
    if v_qty <= 0 then raise exception 'Purchase quantity must be positive'; end if;
    insert into public.purchase_items(purchase_id,item_id,qty,unit_cost,amount) values(v_id,v_item,v_qty,v_cost,v_qty*v_cost);
    v_total := v_total + v_qty*v_cost;
    perform public.apply_stock_movement(p_branch_id,v_item,v_qty,0,'PURCHASE',v_id,coalesce(p_purchase_date,current_date)::timestamptz);
  end loop;
  update public.purchases set total_amount=v_total where id=v_id;
  insert into public.activity_logs(user_id,username,action,details) values(auth.uid(),coalesce((select username from public.profiles where id=auth.uid()),''),'PURCHASE_RECEIVED',jsonb_build_object('id',v_id,'branch_id',p_branch_id));
  return v_id;
end;
$$;

create or replace function public.create_dispatch(
  p_invoice_no text, p_request_id bigint, p_from_branch_id bigint, p_to_branch_id bigint,
  p_dispatch_date date, p_notes text, p_lines jsonb
) returns bigint
language plpgsql security definer set search_path=public
as $$
declare v_id bigint; v_line jsonb; v_item bigint; v_qty numeric; v_cost numeric; v_total numeric:=0;
begin
  if not public.is_admin() and not public.can_action_page('dispatches','add') then raise exception 'Permission denied'; end if;
  if not public.is_admin() and not public.has_branch_access(p_from_branch_id) then raise exception 'Branch access denied'; end if;
  insert into public.dispatches(invoice_no,request_id,from_branch_id,to_branch_id,dispatch_date,status,dispatched_by,notes)
  values(p_invoice_no,p_request_id,p_from_branch_id,p_to_branch_id,coalesce(p_dispatch_date,current_date),'DISPATCHED',auth.uid(),p_notes) returning id into v_id;
  for v_line in select * from jsonb_array_elements(p_lines) loop
    v_item := (v_line->>'item_id')::bigint; v_qty := (v_line->>'qty')::numeric; v_cost := coalesce((v_line->>'unit_cost')::numeric,0);
    if v_qty <= 0 then raise exception 'Dispatch quantity must be positive'; end if;
    insert into public.dispatch_items(dispatch_id,item_id,qty,unit_cost,amount) values(v_id,v_item,v_qty,v_cost,v_qty*v_cost);
    v_total := v_total + v_qty*v_cost;
    perform public.apply_stock_movement(p_from_branch_id,v_item,0,v_qty,'DISPATCH_OUT',v_id,coalesce(p_dispatch_date,current_date)::timestamptz);
  end loop;
  update public.dispatches set total_amount=v_total where id=v_id;
  insert into public.activity_logs(user_id,username,action,details) values(auth.uid(),coalesce((select username from public.profiles where id=auth.uid()),''),'DISPATCH_CREATED',jsonb_build_object('id',v_id));
  return v_id;
end;
$$;

create or replace function public.receive_dispatch(p_dispatch_id bigint) returns void
language plpgsql security definer set search_path=public
as $$
declare d record; x record;
begin
  if not public.is_admin() and not public.can_action_page('dispatches','edit') then raise exception 'Permission denied'; end if;
  select * into d from public.dispatches where id=p_dispatch_id for update;
  if d.id is null then raise exception 'Dispatch not found'; end if;
  if d.status='RECEIVED' then return; end if;
  if not public.is_admin() and not public.has_branch_access(d.to_branch_id) then raise exception 'Branch access denied'; end if;
  for x in select * from public.dispatch_items where dispatch_id=p_dispatch_id loop
    perform public.apply_stock_movement(d.to_branch_id,x.item_id,x.qty,0,'DISPATCH_IN',p_dispatch_id,now());
  end loop;
  update public.dispatches set status='RECEIVED',received_by=auth.uid(),received_at=now(),updated_at=now() where id=p_dispatch_id;
end;
$$;

create or replace function public.create_consumption(
  p_branch_id bigint,p_date date,p_shift text,p_source text,p_notes text,p_lines jsonb
) returns bigint
language plpgsql security definer set search_path=public
as $$
declare v_id bigint; x jsonb; v_item bigint; v_qty numeric; v_cost numeric; v_total numeric:=0;
begin
  if not public.is_admin() and not public.can_action_page('consumption','add') then raise exception 'Permission denied'; end if;
  if not public.is_admin() and not public.has_branch_access(p_branch_id) then raise exception 'Branch access denied'; end if;
  insert into public.consumption(consumption_no,branch_id,date,shift,source,total_cost,recorded_by,notes)
  values('CON-'||to_char(clock_timestamp(),'YYYYMMDDHH24MISSMS'),p_branch_id,coalesce(p_date,current_date),p_shift,p_source,0,auth.uid(),p_notes) returning id into v_id;
  for x in select * from jsonb_array_elements(p_lines) loop
    v_item := (x->>'item_id')::bigint; v_qty := (x->>'qty')::numeric; v_cost := coalesce((x->>'unit_cost')::numeric,(select unit_cost from public.items where id=v_item),0);
    if v_qty <= 0 then raise exception 'Consumption quantity must be positive'; end if;
    insert into public.consumption_lines(consumption_id,item_id,qty,unit_cost,amount) values(v_id,v_item,v_qty,v_cost,v_qty*v_cost);
    v_total := v_total + v_qty*v_cost;
    perform public.apply_stock_movement(p_branch_id,v_item,0,v_qty,'CONSUMPTION',v_id,coalesce(p_date,current_date)::timestamptz);
  end loop;
  update public.consumption set total_cost=v_total where id=v_id;
  return v_id;
end;
$$;

create or replace function public.create_adjustment(
  p_branch_id bigint,p_item_id bigint,p_adjustment_type text,p_qty numeric,p_reason text,p_reason_code text,p_shift text,p_entry_unit text,p_entry_qty numeric
) returns bigint
language plpgsql security definer set search_path=public
as $$
declare v_id bigint; v_no text;
begin
  if not public.is_admin() and not public.can_action_page('adjustments','add') then raise exception 'Permission denied'; end if;
  if not public.is_admin() and not public.has_branch_access(p_branch_id) then raise exception 'Branch access denied'; end if;
  if p_qty <= 0 then raise exception 'Adjustment quantity must be positive'; end if;
  v_no := 'ADJ-'||to_char(clock_timestamp(),'YYYYMMDDHH24MISSMS');
  insert into public.stock_adjustments(adjustment_no,branch_id,item_id,adjustment_type,qty,reason,adjustment_date,adjusted_by,reason_code,shift,entry_unit,entry_qty)
  values(v_no,p_branch_id,p_item_id,p_adjustment_type,p_qty,p_reason,current_date,auth.uid(),p_reason_code,p_shift,p_entry_unit,p_entry_qty) returning id into v_id;
  if upper(p_adjustment_type) in ('IN','ADD','PLUS') then
    perform public.apply_stock_movement(p_branch_id,p_item_id,p_qty,0,'ADJUSTMENT_IN',v_id,now());
  else
    perform public.apply_stock_movement(p_branch_id,p_item_id,0,p_qty,'ADJUSTMENT_OUT',v_id,now());
  end if;
  return v_id;
end;
$$;

create or replace function public.close_stock_count(p_count_id bigint) returns void
language plpgsql security definer set search_path=public
as $$
declare c record; x record; v_variance numeric:=0;
begin
  if not public.is_admin() and not public.can_action_page('counts','edit') then raise exception 'Permission denied'; end if;
  select * into c from public.stock_counts where id=p_count_id for update;
  if c.id is null then raise exception 'Stock count not found'; end if;
  if not public.is_admin() and not public.has_branch_access(c.branch_id) then raise exception 'Branch access denied'; end if;
  for x in select * from public.stock_count_lines where count_id=p_count_id loop
    if x.counted_qty is null then raise exception 'All count lines must be counted'; end if;
    if x.counted_qty > x.system_qty then perform public.apply_stock_movement(c.branch_id,x.item_id,x.counted_qty-x.system_qty,0,'OPNAME_IN',p_count_id,now());
    elsif x.counted_qty < x.system_qty then perform public.apply_stock_movement(c.branch_id,x.item_id,0,x.system_qty-x.counted_qty,'OPNAME_OUT',p_count_id,now()); end if;
    v_variance := v_variance + coalesce(x.variance_value,0);
  end loop;
  update public.stock_counts set status='CLOSED',closed_at=now(),approved_by=auth.uid(),variance_value=v_variance where id=p_count_id;
end;
$$;

grant execute on function public.apply_stock_movement(bigint,bigint,numeric,numeric,text,bigint,timestamptz) to authenticated;
grant execute on function public.create_purchase(text,bigint,bigint,date,text,text,jsonb) to authenticated;
grant execute on function public.create_dispatch(text,bigint,bigint,bigint,date,text,jsonb) to authenticated;
grant execute on function public.receive_dispatch(bigint) to authenticated;
grant execute on function public.create_consumption(bigint,date,text,text,text,jsonb) to authenticated;
grant execute on function public.create_adjustment(bigint,bigint,text,numeric,text,text,text,text,numeric) to authenticated;
grant execute on function public.close_stock_count(bigint) to authenticated;
