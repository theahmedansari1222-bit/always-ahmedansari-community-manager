import { randomBytes } from "node:crypto";
import { NextResponse } from "next/server";
import { cookies } from "next/headers";
import { createClient } from "@/lib/supabase/server";
import { getPlatformApp, oauthRedirect } from "@/lib/platforms";
export async function GET(request:Request) {
 const supabase=await createClient();const {data:{user}}=await supabase.auth.getUser();if(!user)return NextResponse.redirect(new URL("/login",request.url));
 const {data:workspace}=await supabase.from("workspaces").select("id").eq("owner_id",user.id).single();if(!workspace)return NextResponse.redirect(new URL("/?error=workspace",request.url));
 try {const {appId}=getPlatformApp("threads");const state=randomBytes(24).toString("hex");const jar=await cookies();jar.set("oauth_threads_state",`${state}:${workspace.id}`,{httpOnly:true,secure:process.env.NODE_ENV==="production",sameSite:"lax",path:"/",maxAge:600});
  const url=new URL("https://threads.net/oauth/authorize");url.searchParams.set("client_id",appId);url.searchParams.set("redirect_uri",oauthRedirect("threads"));url.searchParams.set("response_type","code");url.searchParams.set("scope","threads_basic,threads_read_replies,threads_manage_replies,threads_content_publish");url.searchParams.set("state",state);return NextResponse.redirect(url);
 }catch(e){return NextResponse.redirect(new URL(`/?error=${encodeURIComponent(e instanceof Error?e.message:"Threads OAuth not configured")}`,request.url));}
}
