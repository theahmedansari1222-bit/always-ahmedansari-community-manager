import { after } from "next/server";
import { createHmac, timingSafeEqual } from "node:crypto";
import { createAdminClient } from "@/lib/supabase/admin";
import { jsonError } from "@/lib/http";
import { classifyFromWebhook } from "@/lib/classifier";

export const maxDuration = 60;

export async function GET(request: Request) {
  const url = new URL(request.url);
  const mode = url.searchParams.get("hub.mode");
  const token = url.searchParams.get("hub.verify_token");
  const challenge = url.searchParams.get("hub.challenge");
  if (mode === "subscribe" && token && token === process.env.INSTAGRAM_WEBHOOK_VERIFY_TOKEN && challenge) {
    return new Response(challenge, { status: 200, headers: { "Cache-Control": "no-store" } });
  }
  return jsonError("Webhook verification failed", 403);
}

function validSignature(raw: string, signature: string | null, secret: string) {
  if (!signature?.startsWith("sha256=")) return false;
  const hex = signature.slice(7);
  if (!/^[0-9a-f]{64}$/i.test(hex)) return false;
  const expected = createHmac("sha256", secret).update(raw).digest();
  try { return timingSafeEqual(expected, Buffer.from(hex, "hex")); } catch { return false; }
}

export async function POST(request: Request) {
  const raw = await request.text();
  const secret = process.env.INSTAGRAM_APP_SECRET;
  if (!secret || !validSignature(raw, request.headers.get("x-hub-signature-256"), secret)) {
    return jsonError("Invalid webhook signature", 401);
  }
  let body: any;
  try { body = JSON.parse(raw); } catch { return jsonError("Invalid JSON", 400); }
  if (!Array.isArray(body.entry)) return jsonError("Unexpected webhook payload", 400);

  const admin = createAdminClient();
  const pendingClassification: string[] = [];
  let inserted = 0;

  for (const entry of body.entry) {
    const { data: account } = await admin.from("social_accounts")
      .select("id,workspace_id,handle")
      .eq("platform", "instagram")
      .eq("platform_user_id", String(entry.id))
      .eq("status", "connected")
      .maybeSingle();
    if (!account) continue;

    for (const change of Array.isArray(entry.changes) ? entry.changes : []) {
      if (change.field !== "comments") continue;
      const value = change.value ?? {};
      if (!value.id || typeof value.text !== "string") continue;
      const author = String(value.from?.username ?? value.username ?? "").replace(/^@/, "").toLowerCase();
      const ownHandle = String(account.handle ?? "").replace(/^@/, "").toLowerCase();
      if (ownHandle && author === ownHandle) continue;

      const mediaId = value.media?.id ?? value.media_id ?? null;
      let postId: string | null = null;
      if (mediaId) {
        const { data: post } = await admin.from("posts").select("id")
          .eq("social_account_id", account.id).eq("platform_post_id", String(mediaId)).maybeSingle();
        postId = post?.id ?? null;
      }
      const platformCommentId = String(value.id);
      const { data: existing } = await admin.from("comments").select("id")
        .eq("social_account_id", account.id).eq("platform_comment_id", platformCommentId).maybeSingle();
      if (existing) continue;

      const { data: created, error } = await admin.from("comments").insert({
        workspace_id: account.workspace_id,
        social_account_id: account.id,
        post_id: postId,
        platform: "instagram",
        platform_comment_id: platformCommentId,
        author_handle: value.from?.username ?? value.username ?? null,
        body: value.text,
        status: "new",
      }).select("id").single();
      if (error) {
        if (error.code !== "23505") console.error("Instagram webhook insert failed", error.message);
        continue;
      }
      inserted++;
      if (created?.id) pendingClassification.push(created.id);
    }
  }

  if (pendingClassification.length) {
    after(async () => {
      await Promise.all(pendingClassification.map((id) => classifyFromWebhook(id)));
    });
  }
  return Response.json({ received: true, inserted });
}
