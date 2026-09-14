'use client';

import { FormEvent, useState } from 'react';
import { createClient } from '@/lib/supabase/client';

export default function LoginPage() {
  const supabase = createClient();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  async function submit(e: FormEvent) {
    e.preventDefault(); setError(''); setLoading(true);
    const { error } = await supabase.auth.signInWithPassword({ email, password });
    if (error) setError(error.message); else window.location.href = '/dashboard';
    setLoading(false);
  }

  return <main style={{minHeight:'100vh',display:'grid',placeItems:'center',padding:20}}>
    <form onSubmit={submit} className="card" style={{width:'100%',maxWidth:420}}>
      <div style={{marginBottom:24}}><h1 style={{margin:'0 0 6px'}}>Inventory System</h1><p style={{margin:0,color:'#6b7280'}}>Login ke sistem manajemen inventory.</p></div>
      <label>Email</label><input value={email} onChange={e=>setEmail(e.target.value)} type="email" required style={{width:'100%',padding:12,margin:'6px 0 16px',border:'1px solid #d1d5db',borderRadius:10}} />
      <label>Password</label><input value={password} onChange={e=>setPassword(e.target.value)} type="password" required style={{width:'100%',padding:12,margin:'6px 0 16px',border:'1px solid #d1d5db',borderRadius:10}} />
      {error && <p style={{color:'#dc2626',fontSize:14}}>{error}</p>}
      <button disabled={loading} style={{width:'100%',padding:12,border:0,borderRadius:10,background:'#111827',color:'#fff',cursor:'pointer'}}>{loading?'Memproses...':'Login'}</button>
    </form>
  </main>;
}
