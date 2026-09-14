import { createClient } from '@/lib/supabase/server';
import { notFound, redirect } from 'next/navigation';

const CONFIG: Record<string,{title:string;table:string;page:string;columns:string[]}> = {
  'purchase-requests':{title:'Purchase Request',table:'purchase_requests',page:'requests',columns:['request_no','request_date','required_date','status','priority','meal_period']},
  purchasing:{title:'Purchasing / GRN',table:'purchases',page:'purchases',columns:['grn_no','purchase_date','status','total_amount','vendor_id']},
  dispatches:{title:'Dispatch',table:'dispatches',page:'dispatches',columns:['invoice_no','dispatch_date','status','from_branch_id','to_branch_id','total_amount']},
  production:{title:'Production',table:'productions',page:'production',columns:['production_no','production_date','status','output_qty','unit_cost']},
  consumption:{title:'Consumption',table:'consumption',page:'consumption',columns:['consumption_no','date','shift','source','total_cost']},
  inventory:{title:'Inventory',table:'inventory',page:'inventory',columns:['branch_id','item_id','qty','updated_at']},
  'stock-ledger':{title:'Stock Ledger',table:'stock_ledger',page:'ledger',columns:['movement_date','movement_type','branch_id','item_id','qty_in','qty_out','balance']},
  adjustments:{title:'Stock Adjustment',table:'stock_adjustments',page:'adjustments',columns:['adjustment_no','adjustment_date','adjustment_type','branch_id','item_id','qty','reason']},
  'stock-counts':{title:'Stock Opname',table:'stock_counts',page:'counts',columns:['count_no','status','branch_id','category_id','blind','variance_value']},
  batches:{title:'Batch & Expiry',table:'batches',page:'batches',columns:['batch_no','received_date','expiry_date','qty_in','qty_remaining','status']},
  reports:{title:'Reports',table:'stock_ledger',page:'reports',columns:['movement_date','movement_type','branch_id','item_id','qty_in','qty_out','balance']},
  items:{title:'Items',table:'items',page:'items',columns:['item_code','name','item_type','unit','unit_cost','min_stock','is_active']},
  vendors:{title:'Supplier',table:'vendors',page:'vendors',columns:['name','phone','is_active','updated_at']},
  recipes:{title:'Recipe',table:'recipes',page:'recipes',columns:['name','item_id','yield_qty','yield_unit','portion_size','is_active']},
  branches:{title:'Branch',table:'branches',page:'branches',columns:['name','type','address','is_active','is_stock_location']},
  users:{title:'User',table:'profiles',page:'users',columns:['username','email','role_key','status','branch_id']},
  settings:{title:'Settings',table:'units',page:'settings',columns:['code','name','kind','base_code','factor','decimals']},
  categories:{title:'Categories',table:'categories',page:'categories',columns:['name','sort_order','storage_type','count_freq']},
  vendoritems:{title:'Vendor Items',table:'vendor_items',page:'vendoritems',columns:['vendor_id','item_id','vendor_code','price','pack_unit','pack_qty','lead_days']},
  parlevels:{title:'Par Levels',table:'par_levels',page:'parlevels',columns:['branch_id','item_id','min_qty','max_qty','reorder_qty']},
  units:{title:'Units',table:'units',page:'units',columns:['code','name','kind','base_code','factor','decimals']},
};

export default async function ModulePage({params}:{params:Promise<{module:string}>}) {
  const {module}=await params;
  const cfg=CONFIG[module];
  if(!cfg) notFound();
  const supabase=await createClient();
  const {data:{user}}=await supabase.auth.getUser();
  if(!user) redirect('/login');
  const {data:profile}=await supabase.from('profiles').select('username,role_key,status').eq('id',user.id).single();
  if(profile?.status && profile.status!=='Active') redirect('/login');
  const {data,error}=await supabase.from(cfg.table).select(cfg.columns.join(',')).limit(100);
  return <main className="shell"><header className="topbar"><div className="container topbar-inner"><div><a href="/dashboard" className="brand">Inventory OS</a><span className="muted"> / {cfg.title}</span></div><div className="user-chip">{profile?.username || user.email}</div></div></header><div className="container module-wrap"><div className="module-head"><div><h1>{cfg.title}</h1><p className="muted">Workflow workspace • role: {profile?.role_key || 'User'}</p></div><a href="/dashboard" className="button secondary">Dashboard</a></div>{error?<div className="card error">Gagal membaca data: {error.message}</div>:<div className="card table-card"><div className="table-scroll"><table><thead><tr>{cfg.columns.map(c=><th key={c}>{c.replaceAll('_',' ')}</th>)}</tr></thead><tbody>{(data||[]).map((row:any,i)=><tr key={i}>{cfg.columns.map(c=><td key={c}>{typeof row[c]==='object'&&row[c]!==null?JSON.stringify(row[c]):String(row[c]??'—')}</td>)}</tr>)}</tbody></table></div>{!data?.length&&<div className="empty">Belum ada data.</div>}</div>}</div></main>;
}
