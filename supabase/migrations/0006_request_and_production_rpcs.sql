create or replace function public.create_purchase_request(
  p_request_no text,p_branch_id bigint,p_to_branch_id bigint,p_required_date date,
  p_priority text,p_meal_period text,p_covers numeric,p_notes text,p_lines jsonb
) returns bigint
language plpgsql security definer set search_path=public
as $$
declare v_id bigint; x jsonb;
begin
  if not public.is_admin() and not public.can_action_page('requests','add') then raise exception 'Permission denied'; end if;
  if not public.is_admin() and not public.has_branch_access(p_branch_id) then raise exception 'Branch access denied'; end if;
  insert into public.purchase_requests(request_no,branch_id,to_branch_id,request_date,required_date,status,requested_by,priority,meal_period,covers,notes)
  values(p_request_no,p_branch_id,p_to_branch_id,current_date,p_required_date,'SUBMITTED',auth.uid(),p_priority,p_meal_period,p_covers,p_notes) returning id into v_id;
  for x in select * from jsonb_array_elements(p_lines) loop
    if (x->>'requested_qty')::numeric <= 0 then raise exception 'Requested quantity must be positive'; end if;
    insert into public.purchase_request_items(request_id,item_id,requested_qty,unit_cost,line_note)
    values(v_id,(x->>'item_id')::bigint,(x->>'requested_qty')::numeric,coalesce((x->>'unit_cost')::numeric,0),x->>'line_note');
  end loop;
  return v_id;
end;
$$;

create or replace function public.approve_purchase_request(p_request_id bigint,p_lines jsonb,p_reject_reason text default null) returns void
language plpgsql security definer set search_path=public
as $$
declare r record; x jsonb; v_qty numeric;
begin
  if not public.is_admin() and not public.can_action_page('requests','edit') then raise exception 'Permission denied'; end if;
  select * into r from public.purchase_requests where id=p_request_id for update;
  if r.id is null then raise exception 'Request not found'; end if;
  if not public.is_admin() and not public.has_branch_access(r.branch_id) then raise exception 'Branch access denied'; end if;
  if p_reject_reason is not null and length(trim(p_reject_reason))>0 then
    update public.purchase_requests set status='REJECTED',reject_reason=p_reject_reason,approved_by=auth.uid(),approved_at=now(),updated_at=now() where id=p_request_id;
    return;
  end if;
  for x in select * from jsonb_array_elements(p_lines) loop
    v_qty:=coalesce((x->>'approved_qty')::numeric,0);
    if v_qty < 0 then raise exception 'Approved quantity cannot be negative'; end if;
    update public.purchase_request_items set approved_qty=v_qty,amount=v_qty*unit_cost where request_id=p_request_id and item_id=(x->>'item_id')::bigint;
  end loop;
  update public.purchase_requests set status='APPROVED',approved_by=auth.uid(),approved_at=now(),updated_at=now() where id=p_request_id;
end;
$$;

create or replace function public.create_production(
  p_production_no text,p_branch_id bigint,p_item_id bigint,p_output_qty numeric,p_production_date date,
  p_notes text,p_lines jsonb
) returns bigint
language plpgsql security definer set search_path=public
as $$
declare v_id bigint; x jsonb; v_material bigint; v_qty numeric; v_cost numeric; v_total numeric:=0; v_unit_cost numeric;
begin
  if not public.is_admin() and not public.can_action_page('production','add') then raise exception 'Permission denied'; end if;
  if not public.is_admin() and not public.has_branch_access(p_branch_id) then raise exception 'Branch access denied'; end if;
  if p_output_qty<=0 then raise exception 'Output quantity must be positive'; end if;
  insert into public.productions(production_no,branch_id,item_id,output_qty,production_date,status,produced_by,notes)
  values(p_production_no,p_branch_id,p_item_id,p_output_qty,coalesce(p_production_date,current_date),'COMPLETED',auth.uid(),p_notes) returning id into v_id;
  for x in select * from jsonb_array_elements(p_lines) loop
    v_material:=(x->>'item_id')::bigint; v_qty:=(x->>'qty_used')::numeric; v_cost:=coalesce((x->>'unit_cost')::numeric,(select unit_cost from public.items where id=v_material),0);
    if v_qty<=0 then raise exception 'Material quantity must be positive'; end if;
    insert into public.production_materials(production_id,item_id,qty_used,unit_cost,amount) values(v_id,v_material,v_qty,v_cost,v_qty*v_cost);
    v_total:=v_total+v_qty*v_cost;
    perform public.apply_stock_movement(p_branch_id,v_material,0,v_qty,'PRODUCTION_OUT',v_id,now());
  end loop;
  v_unit_cost:=case when p_output_qty=0 then 0 else v_total/p_output_qty end;
  update public.productions set unit_cost=v_unit_cost where id=v_id;
  perform public.apply_stock_movement(p_branch_id,p_item_id,p_output_qty,0,'PRODUCTION_IN',v_id,now());
  return v_id;
end;
$$;

grant execute on function public.create_purchase_request(text,bigint,bigint,date,text,text,numeric,text,jsonb) to authenticated;
grant execute on function public.approve_purchase_request(bigint,jsonb,text) to authenticated;
grant execute on function public.create_production(text,bigint,bigint,numeric,date,text,jsonb) to authenticated;
