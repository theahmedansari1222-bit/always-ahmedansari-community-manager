import "server-only";
import { createAdminClient } from "@/lib/supabase/admin";
import { decryptToken, encryptToken } from "@/lib/crypto";
import type { Credential, Platform } from "@/lib/platforms";

export async function saveCredential(input: {
  ownerId: string; workspaceId: string; platform: Platform; platformUserId: string;
  handle: string | null; accessToken: string; expiresIn?: number; scopes: string[];
}) {
  const admin = createAdminClient();
  const expiry = input.expiresIn ? new Date(Date.now() + input.expiresIn * 1000).toISOString() : null;
  const { error } = await admin.rpc("save_social_credential", {
    p_owner_id: input.ownerId, p_workspace_id: input.workspaceId, p_platform: input.platform,
    p_platform_user_id: input.platformUserId, p_handle: input.handle,
    p_access_token_hex: encryptToken(input.accessToken), p_token_expires_at: expiry, p_scopes: input.scopes
  });
  if (error) throw new Error(`Could not store encrypted ${input.platform} token: ${error.message}`);
  const row = await admin.from("social_accounts").select("id").eq("workspace_id", input.workspaceId).eq("platform", input.platform).maybeSingle();
  const accountData = { workspace_id: input.workspaceId, platform: input.platform, platform_user_id: input.platformUserId, handle: input.handle, status: "connected", connected_at: new Date().toISOString() };
  const accountWrite = row.data?.id
    ? await admin.from("social_accounts").update(accountData).eq("id", row.data.id)
    : await admin.from("social_accounts").insert(accountData);
  if (accountWrite.error) throw new Error(`Connected token was stored but account status update failed: ${accountWrite.error.message}`);
}

export async function getCredential(ownerId: string, workspaceId: string, platform: Platform): Promise<(Credential & { access_token: string }) | null> {
  const admin = createAdminClient();
  const { data, error } = await admin.rpc("read_social_credential", { p_owner_id: ownerId, p_workspace_id: workspaceId, p_platform: platform });
  if (error) throw new Error(`Could not read ${platform} credentials: ${error.message}`);
  const row = Array.isArray(data) ? data[0] : data;
  if (!row?.access_token_hex) return null;
  return { ...row, access_token: decryptToken(row.access_token_hex) } as Credential & { access_token: string };
}

export async function deleteCredential(ownerId: string, workspaceId: string, platform: Platform) {
  const admin = createAdminClient();
  const { error } = await admin.rpc("delete_social_credential", { p_owner_id: ownerId, p_workspace_id: workspaceId, p_platform: platform });
  if (error) throw new Error(error.message);
  await admin.from("social_accounts").update({ status: "disconnected" }).eq("workspace_id", workspaceId).eq("platform", platform);
}
