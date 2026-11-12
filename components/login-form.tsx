"use client";
import { useState } from "react";
import { createClient } from "@/lib/supabase/client";
export default function LoginForm() {
  const [email,setEmail]=useState(""); const [password,setPassword]=useState("");
  const [mode,setMode]=useState<"password"|"magic">("password"); const [busy,setBusy]=useState(false); const [message,setMessage]=useState("");
  async function submit(e:React.FormEvent) {
    e.preventDefault(); setBusy(true); setMessage("");
    try { const supabase=createClient();
      if (mode === "password") { const {error}=await supabase.auth.signInWithPassword({email,password}); if(error) throw error; window.location.assign("/"); }
      else { const {error}=await supabase.auth.signInWithOtp({email,options:{emailRedirectTo:`${window.location.origin}/auth/callback`}}); if(error) throw error; setMessage("Check your email for the secure sign-in link."); }
    } catch(err) { setMessage(err instanceof Error ? err.message : "Could not sign in."); } finally { setBusy(false); }
  }
  return <form className="auth-form" onSubmit={submit}><label>Email address<input type="email" required autoComplete="email" value={email} onChange={e=>setEmail(e.target.value)} /></label>{mode==="password"&&<label>Password<input type="password" required autoComplete="current-password" value={password} onChange={e=>setPassword(e.target.value)} /></label>}<button disabled={busy}>{busy?"Please wait…":mode==="password"?"Sign in":"Send secure sign-in link"}</button><button type="button" className="link-button" onClick={()=>{setMode(mode==="password"?"magic":"password");setMessage("");}}>{mode==="password"?"Use an email sign-in link instead":"Use password instead"}</button>{message&&<p className="notice">{message}</p>}</form>;
}
