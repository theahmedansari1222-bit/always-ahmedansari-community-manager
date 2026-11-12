import "server-only";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

export async function requireUser() {
  const supabase = await createClient();
  const { data: { user }, error } = await supabase.auth.getUser();
  if (error || !user) redirect("/login");
  const { data: workspace, error: workspaceError } = await supabase
    .from("workspaces").select("id,owner_id,name,reply_mode,reply_language").eq("owner_id", user.id).single();
  if (workspaceError || !workspace) throw new Error("Your Always Ahmed Ansari workspace was not found. Contact the administrator.");
  return { supabase, user, workspace };
}
