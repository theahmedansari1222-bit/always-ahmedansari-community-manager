import { createClient } from "@/lib/supabase/server";
import { jsonError } from "@/lib/http";
export async function POST(_request: Request, ctx: { params: Promise<{ id: string }> }) {
  const { id } = await ctx.params;
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return jsonError("Unauthorized", 401);
  const { data: workspace } = await supabase.from("workspaces").select("id").eq("owner_id", user.id).single();
  if (!workspace) return jsonError("Workspace not found", 404);
  const { data: comment, error: readError } = await supabase.from("comments")
    .select("id,status").eq("id", id).eq("workspace_id", workspace.id).maybeSingle();
  if (readError || !comment) return jsonError("Comment not found", 404);
  if (comment.status === "replied") return jsonError("A replied comment cannot be skipped.", 409);
  if (comment.status === "ignored") return Response.json({ message: "Comment is already skipped." });
  const { error } = await supabase.from("comments").update({ status: "ignored" })
    .eq("id", id).eq("workspace_id", workspace.id);
  if (error) return jsonError(error.message, 400);
  await supabase.from("audit_events").insert({ workspace_id: workspace.id, actor_type: "user", actor_id: user.id, action: "comment_skipped", entity_type: "comment", entity_id: id });
  return Response.json({ message: "Comment skipped." });
}
