import { createClient } from "@/lib/supabase/server";
import { jsonError, parseJson } from "@/lib/http";
export async function POST(request:Request) {
 const supabase=await createClient(); const {data:{user}}=await supabase.auth.getUser(); if(!user)return jsonError("Unauthorized",401);
 try {const body=await parseJson(request);const mode=body.reply_mode;if(!["auto","review_only","off"].includes(mode))return jsonError("Invalid reply mode");
  const {error}=await supabase.from("workspaces").update({reply_mode:mode}).eq("owner_id",user.id);if(error)return jsonError(error.message,400);
  return Response.json({message:"Automation mode updated."});
 } catch(e){return jsonError(e instanceof Error?e.message:"Invalid request",400);}
}
