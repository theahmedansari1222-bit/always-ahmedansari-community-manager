import { randomBytes } from "node:crypto";
import { NextResponse } from "next/server";
import { cookies } from "next/headers";
import { createClient } from "@/lib/supabase/server";
import { getPlatformApp, oauthRedirect } from "@/lib/platforms";
export async function GET(request:Request) {
 const supabase=await createClient();const {data:{user}}=await supabase.auth.getUser();if(!user)return NextResponse.redirect(new URL("/login",request.url));
 const {data:workspace}=await supabase.from("workspaces").select("id").eq("owner_id",user.id).single();if(!workspace)return NextResponse.redirect(new URL("/?error=workspace",request.url));
 try {const {appId}=getPlatformApp("instagram");const state=randomBytes(24).toString("hex");const jar=await cookies();jar.set("oauth_instagram_state",`${state}:${workspace.id}`,{httpOnly:true,secure:process.env.NODE_ENV==="production",sameSite:"lax",path:"/",maxAge:600});
  const url=new URL("https://www.instagram.com/oauth/authorize");url.searchParams.set("client_id",appId);url.searchParams.set("redirect_uri",oauthRedirect("instagram"));url.searchParams.set("response_type","code");url.searchParams.set("scope","instagram_business_basic,instagram_business_manage_comments");url.searchParams.set("state",state);url.searchParams.set("force_authentication","1");
  return NextResponse.redirect(url);
 }catch(e){return NextResponse.redirect(new URL(`/?error=${encodeURIComponent(e instanceof Error?e.message:"Instagram OAuth not configured")}`,request.url));}
}
