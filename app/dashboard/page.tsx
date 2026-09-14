import { createClient } from '@/lib/supabase/server';
import { redirect } from 'next/navigation';

const modules = [
  ['Purchase Request','/purchase-requests'],['Purchasing','/purchasing'],['Dispatch','/dispatches'],['Production','/production'],
  ['Consumption','/consumption'],['Inventory','/inventory'],['Stock Ledger','/stock-ledger'],['Stock Adjustment','/adjustments'],
  ['Stock Opname','/stock-counts'],['Batch & Expiry','/batches'],['Reports','/reports'],['Items','/items'],['Supplier','/vendors'],
  ['Recipe','/recipes'],['Branch','/branches'],['User','/users'],['Settings','/settings']
];

export default async function DashboardPage() {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect('/login');
  const { data: profile } = await supabase.from('profiles').select('username,role_key,branch_id,status').eq('id',user.id).single();
  if (profile?.status && profile.status !== 'Active') redirect('/login');

  return <main className="shell"><header style={{background:'#111827',color:'#fff',padding:'18px 0'}}><div className="container" style={{display:'flex',justifyContent:'space-between',alignItems:'center',gap:16}}><div><strong>Inventory Management System</strong><div style={{fontSize:13,opacity:.75}}>Dashboard</div></div><div style={{fontSize:13}}>{profile?.username || user.email} · {profile?.role_key || 'User'}</div></div></header><section className="container" style={{padding:'24px 0'}}><div className="card"><h2 style={{marginTop:0}}>Operational Dashboard</h2><p style={{color:'#6b7280'}}>Foundation berhasil terhubung ke Supabase. Modul akan diaktifkan bertahap sesuai business logic legacy.</p><div style={{display:'grid',gridTemplateColumns:'repeat(auto-fit,minmax(180px,1fr))',gap:12,marginTop:20}}>{modules.map(([name,path])=><a key={path} href={path} className="card" style={{padding:16}}><strong>{name}</strong><div style={{fontSize:12,color:'#6b7280',marginTop:5}}>{path}</div></a>)}</div></div></section></main>;
}
