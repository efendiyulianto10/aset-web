import { createClient } from '@/lib/supabase/server';

export type MovementInput = {
  branchId:number;
  itemId:number;
  qtyIn?:number;
  qtyOut?:number;
  movementType:string;
  referenceId?:number|null;
};

export async function applyStockMovement(input:MovementInput){
  const supabase=await createClient();
  const {data,error}=await supabase.rpc('apply_stock_movement',{
    p_branch_id:input.branchId,p_item_id:input.itemId,p_qty_in:input.qtyIn??0,
    p_qty_out:input.qtyOut??0,p_movement_type:input.movementType,p_reference_id:input.referenceId??null
  });
  if(error) throw new Error(error.message);
  return data;
}
