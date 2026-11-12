import { createClient } from "@/lib/supabase/server";
import { jsonError } from "@/lib/http";
export const dynamic = "force-dynamic";
export async function GET() {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return jsonError("Unauthorized",401);
  const { data: workspace, error: wErr } = await supabase.from("workspaces").select("id,reply_mode").eq("owner_id",user.id).single();
  if (wErr || !workspace) return jsonError("Workspace not found",404);
  const [commentsRes, accountsRes, todayRes, draftRes, reviewRes, repliedRes] = await Promise.all([
    supabase.from("comments").select("id,platform,author_handle,body,status,risk,confidence,risk_reasons,received_at,post_id,posts(caption),reply_drafts(id,reply_text,created_at)").eq("workspace_id",workspace.id).order("received_at",{ascending:false}).limit(80),
    supabase.from("social_accounts").select("platform,handle,status").eq("workspace_id",workspace.id),
    supabase.from("comments").select("id",{count:"exact",head:true}).eq("workspace_id",workspace.id).gte("received_at",new Date(new Date().setHours(0,0,0,0)).toISOString()),
    supabase.from("comments").select("id",{count:"exact",head:true}).eq("workspace_id",workspace.id).eq("status","drafted"),
    supabase.from("comments").select("id",{count:"exact",head:true}).eq("workspace_id",workspace.id).eq("status","queued_review"),
    supabase.from("comments").select("id",{count:"exact",head:true}).eq("workspace_id",workspace.id).eq("status","replied")
  ]);
  if (commentsRes.error) return jsonError(commentsRes.error.message,500);
  const comments = (commentsRes.data??[]).map((c:any)=>({ ...c, post_caption: Array.isArray(c.posts)?c.posts[0]?.caption:c.posts?.caption, drafts:c.reply_drafts??[] }));
  return Response.json({comments,accounts:accountsRes.data??[],mode:workspace.reply_mode,stats:{today:todayRes.count??0,drafts:draftRes.count??0,review:reviewRes.count??0,replied:repliedRes.count??0}},{headers:{"Cache-Control":"private, no-store"}});
}
