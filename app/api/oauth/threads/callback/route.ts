import { cookies } from "next/headers";
import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";
import { saveCredential } from "@/lib/credentials";
import { getPlatformApp, oauthRedirect } from "@/lib/platforms";
export async function GET(request:Request) {
 const url=new URL(request.url);const code=url.searchParams.get("code");const state=url.searchParams.get("state");const jar=await cookies();const stored=jar.get("oauth_threads_state")?.value;jar.delete("oauth_threads_state");
 const fail=(msg:string)=>NextResponse.redirect(new URL(`/?error=${encodeURIComponent(msg)}`,url.origin));
 if(url.searchParams.get("error"))return fail(url.searchParams.get("error_description")||"Threads authorization was cancelled.");
 if(!code||!state||!stored||!stored.startsWith(`${state}:`))return fail("Threads OAuth state check failed. Please reconnect.");
 const workspaceId=stored.slice(state.length+1);const supabase=await createClient();const {data:{user}}=await supabase.auth.getUser();if(!user)return NextResponse.redirect(new URL("/login",url.origin));
 try {
  const {appId,appSecret}=getPlatformApp("threads");const form=new URLSearchParams({client_id:appId,client_secret:appSecret,grant_type:"authorization_code",redirect_uri:oauthRedirect("threads"),code});
  const tokenRes=await fetch("https://graph.threads.net/oauth/access_token",{method:"POST",headers:{"Content-Type":"application/x-www-form-urlencoded"},body:form,cache:"no-store"});const short=await tokenRes.json();if(!tokenRes.ok||!short.access_token)throw new Error(short.error?.message||"Threads token exchange failed.");
  let token=String(short.access_token);let expires=Number(short.expires_in)||3600;
  const longUrl=new URL("https://graph.threads.net/access_token");longUrl.searchParams.set("grant_type","th_exchange_token");longUrl.searchParams.set("client_secret",appSecret);longUrl.searchParams.set("access_token",token);
  const longRes=await fetch(longUrl,{cache:"no-store"});const longData=await longRes.json();if(!longRes.ok||!longData.access_token)throw new Error(longData.error?.message||"Threads could not exchange the short-lived token for a long-lived token. Please reconnect.");token=longData.access_token;expires=Number(longData.expires_in)||5184000;
  const profileUrl=new URL("https://graph.threads.net/v1.0/me");profileUrl.searchParams.set("fields","id,username");profileUrl.searchParams.set("access_token",token);
  const profileRes=await fetch(profileUrl,{cache:"no-store"});const profile=await profileRes.json();if(!profileRes.ok||!profile.id)throw new Error("Could not read the Threads profile.");
  await saveCredential({ownerId:user.id,workspaceId,platform:"threads",platformUserId:String(profile.id),handle:profile.username??null,accessToken:token,expiresIn:expires,scopes:["threads_basic","threads_read_replies","threads_manage_replies","threads_content_publish"]});
  return NextResponse.redirect(new URL("/?connected=threads",url.origin));
 }catch(e){return fail(e instanceof Error?e.message:"Threads connection failed.");}
}
