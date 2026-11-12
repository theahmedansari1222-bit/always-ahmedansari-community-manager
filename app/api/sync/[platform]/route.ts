import { createClient } from "@/lib/supabase/server";
import { createAdminClient } from "@/lib/supabase/admin";
import { getCredential } from "@/lib/credentials";
import { graphVersion, type Platform } from "@/lib/platforms";
import { jsonError } from "@/lib/http";

export const dynamic = "force-dynamic";

type MetaPage = { data?: Array<Record<string, any>>; paging?: { next?: string } };

async function fetchJson(url: URL) {
  const response = await fetch(url, { cache: "no-store" });
  const body = await response.json();
  if (!response.ok) {
    throw new Error(body.error?.message || body.error_message || `Meta API returned ${response.status}`);
  }
  return body as MetaPage;
}

async function fetchPages(firstUrl: URL, maxPages = 3) {
  const rows: Array<Record<string, any>> = [];
  let next: string | undefined = firstUrl.toString();
  for (let page = 0; page < maxPages && next; page++) {
    const pageUrl = new URL(next);
    if (pageUrl.protocol !== "https:" || !["graph.instagram.com", "graph.threads.net"].includes(pageUrl.hostname)) {
      throw new Error("Meta returned an unexpected pagination URL.");
    }
    const result = await fetchJson(pageUrl);
    rows.push(...(result.data ?? []));
    next = result.paging?.next;
  }
  return rows;
}

export async function POST(_request: Request, ctx: { params: Promise<{ platform: string }> }) {
  const { platform: raw } = await ctx.params;
  if (raw !== "instagram" && raw !== "threads") return jsonError("Unsupported platform", 404);
  const platform = raw as Platform;
  const auth = await createClient();
  const { data: { user } } = await auth.auth.getUser();
  if (!user) return jsonError("Unauthorized", 401);
  const { data: workspace } = await auth.from("workspaces").select("id").eq("owner_id", user.id).single();
  if (!workspace) return jsonError("Workspace not found", 404);

  try {
    const credential = await getCredential(user.id, workspace.id, platform);
    if (!credential) return jsonError(`${platform} is not connected.`, 409);
    const admin = createAdminClient();
    const { data: account, error: accountError } = await admin.from("social_accounts")
      .select("id,handle")
      .eq("workspace_id", workspace.id)
      .eq("platform", platform)
      .eq("status", "connected")
      .single();
    if (accountError || !account) return jsonError(`Connected ${platform} account record was not found. Reconnect it.`, 409);

    const host = platform === "instagram" ? "https://graph.instagram.com" : "https://graph.threads.net";
    const version = platform === "instagram" ? graphVersion() : "v1.0";
    const postsUrl = new URL(`${host}/${version}/me/${platform === "instagram" ? "media" : "threads"}`);
    postsUrl.searchParams.set("fields", platform === "instagram" ? "id,caption,permalink,timestamp" : "id,text,permalink,timestamp,media_type,has_replies");
    postsUrl.searchParams.set("limit", "50");
    postsUrl.searchParams.set("access_token", credential.access_token);
    const posts = (await fetchJson(postsUrl)).data ?? [];
    let importedPosts = 0;
    let importedComments = 0;

    for (const post of posts.slice(0, 15)) {
      if (!post.id) continue;
      const postIdOnPlatform = String(post.id);
      const postRow = {
        workspace_id: workspace.id,
        social_account_id: account.id,
        platform_post_id: postIdOnPlatform,
        permalink: post.permalink ?? null,
        caption: post.caption ?? post.text ?? null,
        published_at: post.timestamp ?? null,
      };
      const { data: existingPost } = await admin.from("posts").select("id")
        .eq("social_account_id", account.id)
        .eq("platform_post_id", postIdOnPlatform)
        .maybeSingle();
      let localPostId = existingPost?.id as string | undefined;
      if (localPostId) {
        const { error } = await admin.from("posts").update(postRow).eq("id", localPostId);
        if (error) throw new Error(error.message);
      } else {
        const { data: inserted, error } = await admin.from("posts").insert(postRow).select("id").single();
        if (error) throw new Error(error.message);
        localPostId = inserted.id;
        importedPosts++;
      }

      // Instagram's comments edge and Threads' replies edge both return comment-like objects.
      const edge = platform === "instagram" ? "comments" : "replies";
      const fields = platform === "instagram"
        ? "id,text,username,timestamp"
        : "id,text,username,timestamp,permalink,is_reply,is_reply_owned_by_me,root_post,replied_to";
      const commentsUrl = new URL(`${host}/${version}/${encodeURIComponent(postIdOnPlatform)}/${edge}`);
      commentsUrl.searchParams.set("fields", fields);
      commentsUrl.searchParams.set("limit", "50");
      commentsUrl.searchParams.set("access_token", credential.access_token);
      const commentRows = await fetchPages(commentsUrl, 3);

      for (const comment of commentRows) {
        if (!comment.id || typeof comment.text !== "string") continue;
        const author = String(comment.username ?? "").replace(/^@/, "").toLowerCase();
        const ownHandle = String(account.handle ?? "").replace(/^@/, "").toLowerCase();
        if ((ownHandle && author === ownHandle) || comment.is_reply_owned_by_me === true) continue;
        const platformCommentId = String(comment.id);
        const { data: old } = await admin.from("comments").select("id")
          .eq("social_account_id", account.id)
          .eq("platform_comment_id", platformCommentId)
          .maybeSingle();
        if (old) continue;
        const { error } = await admin.from("comments").insert({
          workspace_id: workspace.id,
          social_account_id: account.id,
          post_id: localPostId,
          platform,
          platform_comment_id: platformCommentId,
          author_handle: comment.username ?? null,
          body: comment.text,
          status: "new",
        });
        if (error && error.code !== "23505") throw new Error(error.message);
        if (!error) importedComments++;
      }
    }

    return Response.json({
      message: `Sync complete: ${importedPosts} new posts and ${importedComments} new comments imported.`,
      importedPosts,
      importedComments,
    });
  } catch (error) {
    console.error("platform sync failed", platform, error);
    return jsonError(error instanceof Error ? error.message : "Sync failed", 502);
  }
}
