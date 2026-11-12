import { createClient } from "@/lib/supabase/server";
import { createAdminClient } from "@/lib/supabase/admin";
import { getCredential } from "@/lib/credentials";
import { graphVersion, type Platform } from "@/lib/platforms";
import { jsonError, parseJson } from "@/lib/http";
async function publish(platform:Platform,commentId:string,text:string,credential:{access_token:string;platform_user_id:string}){
 if(platform==="instagram"){
  const url=new URL(`https://graph.instagram.com/${graphVersion()}/${encodeURIComponent(commentId)}/replies`);url.searchParams.set("access_token",credential.access_token);
  const form=new URLSearchParams({message:text});const res=await fetch(url,{method:"POST",headers:{"Content-Type":"application/x-www-form-urlencoded"},body:form,cache:"no-store"});const data=await res.json();if(!res.ok||data.error)throw new Error(data.error?.message||"Instagram rejected the reply.");return String(data.id??data.comment_id??"");
 }
 const host="https://graph.threads.net/v1.0";const createUrl=new URL(`${host}/${encodeURIComponent(credential.platform_user_id)}/threads`);createUrl.searchParams.set("access_token",credential.access_token);
 const form=new URLSearchParams({media_type:"TEXT",text,reply_to_id:commentId});const createRes=await fetch(createUrl,{method:"POST",headers:{"Content-Type":"application/x-www-form-urlencoded"},body:form,cache:"no-store"});const container=await createRes.json();if(!createRes.ok||!container.id)throw new Error(container.error?.message||"Threads could not create the reply container.");
 const publishUrl=new URL(`${host}/${encodeURIComponent(credential.platform_user_id)}/threads_publish`);publishUrl.searchParams.set("access_token",credential.access_token);const publishForm=new URLSearchParams({creation_id:String(container.id)});const publishRes=await fetch(publishUrl,{method:"POST",headers:{"Content-Type":"application/x-www-form-urlencoded"},body:publishForm,cache:"no-store"});const result=await publishRes.json();if(!publishRes.ok||!result.id)throw new Error(result.error?.message||"Threads could not publish the reply.");return String(result.id);
}
export async function POST(request:Request,ctx:{params:Promise<{id:string}>}){
 const {id}=await ctx.params;const auth=await createClient();const {data:{user}}=await auth.auth.getUser();if(!user)return jsonError("Unauthorized",401);
 try{const body=await parseJson(request);const text=typeof body.reply_text==="string"?body.reply_text.trim():"";if(!text||text.length>1000)return jsonError("Reply must be between 1 and 1000 characters.");
  const {data:workspace}=await auth.from("workspaces").select("id").eq("owner_id",user.id).single();if(!workspace)return jsonError("Workspace not found",404);
  const admin=createAdminClient();const {data:comment,error}=await admin.from("comments").select("id,workspace_id,platform,platform_comment_id,social_account_id,status").eq("id",id).eq("workspace_id",workspace.id).single();if(error||!comment)return jsonError("Comment not found",404);
  if(comment.status === "replied" || comment.status === "ignored") return jsonError("This comment is already replied to or skipped.",409);
  const {data:already}=await admin.from("reply_events").select("id").eq("comment_id",id).eq("outcome","sent").maybeSingle();if(already)return jsonError("This comment already has a recorded reply.",409);
  const platform=comment.platform as Platform;const credential=await getCredential(user.id,workspace.id,platform);if(!credential)return jsonError(`${platform} account is not connected.`,409);
  const {data:reservation,error:reservationError}=await admin.from("reply_events").insert({workspace_id:workspace.id,comment_id:id,platform,idempotency_key:`manual:${id}`,reply_text:text,outcome:"held"}).select("id").single();
  if(reservationError||!reservation)return jsonError("A reply is already being processed for this comment. Refresh the dashboard before trying again.",409);
  let replyId="";try{replyId=await publish(platform,id,text,credential);}catch(e){await admin.from("reply_events").update({outcome:"failed",idempotency_key:`manual-failed:${id}:${Date.now()}`,error_code:(e instanceof Error?e.message:"provider_error").slice(0,200)}).eq("id",reservation.id);throw e;}
  const {error:eventError}=await admin.from("reply_events").update({outcome:"sent",platform_reply_id:replyId||null}).eq("id",reservation.id);if(eventError)console.error("reply event log update failed",eventError.message);
  await admin.from("comments").update({status:"replied"}).eq("id",id);
  await admin.from("reply_drafts").update({reply_text:text,approved_by:user.id,approved_at:new Date().toISOString()}).eq("comment_id",id);
  await admin.from("audit_events").insert({workspace_id:workspace.id,actor_type:"user",actor_id:user.id,action:"reply_sent",entity_type:"comment",entity_id:id,details:{platform,platform_reply_id:replyId}});
  return Response.json({message:"Reply successfully published."});
 }catch(e){return jsonError(e instanceof Error?e.message:"Reply could not be sent.",502);}
}
