import { createClient } from "@/lib/supabase/server";
import { jsonError } from "@/lib/http";
export async function POST(_request:Request,ctx:{params:Promise<{id:string}>}){
 const {id}=await ctx.params;const supabase=await createClient();const {data:{user}}=await supabase.auth.getUser();if(!user)return jsonError("Unauthorized",401);
 const {data:{session}}=await supabase.auth.getSession();if(!session?.access_token)return jsonError("Session token missing",401);
 const url=process.env.NEXT_PUBLIC_SUPABASE_URL;const key=process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;if(!url||!key)return jsonError("Supabase is not configured",500);
 const res=await fetch(`${url}/functions/v1/classify-and-reply`,{method:"POST",headers:{"Content-Type":"application/json",apikey:key,Authorization:`Bearer ${session.access_token}`},body:JSON.stringify({commentId:id}),cache:"no-store"});const data=await res.json();return Response.json(data,{status:res.status});
}
