import { createClient } from '@/lib/supabase/server';
import { redirect } from 'next/navigation';

const modules=[['Purchase Request','/purchase-requests'],['Purchasing','/purchasing'],['Dispatch','/dispatches'],['Production','/production'],['Consumption','/consumption'],['Inventory','/inventory'],['Stock Ledger','/stock-ledger'],['Stock Adjustment','/adjustments'],['Stock Opname','/stock-counts'],['Batch & Expiry','/batches'],['Reports','/reports'],['Items','/items'],['Supplier','/vendors'],['Recipe','/recipes'],['Branch','/branches'],['User','/users'],['Settings','/settings']];

export default async function DashboardPage(){
 const supabase=await createClient();
 const {data:{user}}=await supabase.auth.getUser(); if(!user) redirect('/login');
 const {data:profile}=await supabase.from('profiles').select('username,role_key,branch_id,status').eq('id',user.id).single();
 if(profile?.status && profile.status!=='Active') redirect('/login');
 const [items,inventory,requests,expiring]=await Promise.all([
  supabase.from('items').select('id',{count:'exact',head:true}).eq('is_deleted',false),
  supabase.from('inventory').select('id,qty,item_id,branch_id').gt('qty',0),
  supabase.from('purchase_requests').select('id',{count:'exact',head:true}).in('status',['DRAFT','SUBMITTED','APPROVED']),
  supabase.from('batches').select('id',{count:'exact',head:true}).lte('expiry_date',new Date(Date.now()+7*86400000).toISOString().slice(0,10)).gt('qty_remaining',0).eq('is_deleted',false)
 ]);
 const totalUnits=(inventory.data||[]).reduce((s:number,r:any)=>s+Number(r.qty||0),0);
 return <main className="shell"><header className="topbar"><div className="container topbar-inner"><div><strong>Inventory OS</strong><div className="topbar .muted">Operational Control Center</div></div><div className="user-chip">{profile?.username||user.email} · {profile?.role_key||'User'}</div></div></header><section className="container module-wrap"><div className="module-head"><div><h1>Dashboard</h1><p className="muted">Live operational overview from Supabase.</p></div></div><div style={{display:'grid',gridTemplateColumns:'repeat(auto-fit,minmax(190px,1fr))',gap:12,marginBottom:22}}>{[['Active Items',items.count??0],['Inventory Units',Math.round(totalUnits*100)/100],['Open Requests',requests.count??0],['Expiring ≤ 7 Days',expiring.count??0]].map(([label,value])=><div className="card" key={String(label)}><div className="muted" style={{fontSize:12}}>{label}</div><div style={{fontSize:28,fontWeight:800,marginTop:6}}>{value}</div></div>)}</div><div className="card"><h2 style={{marginTop:0}}>Modules</h2><div style={{display:'grid',gridTemplateColumns:'repeat(auto-fit,minmax(180px,1fr))',gap:12,marginTop:16}}>{modules.map(([name,path])=><a key={path} href={path} className="card" style={{padding:16}}><strong>{name}</strong><div className="muted" style={{fontSize:12,marginTop:5}}>{path}</div></a>)}</div></div></section></main>;
}
