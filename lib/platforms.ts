export type Platform = "instagram" | "threads";
export type Credential = { platform_user_id: string; handle: string | null; access_token_hex: string; token_expires_at: string | null; scopes: string[] };

export function baseUrl() {
  const value = process.env.NEXT_PUBLIC_APP_URL || process.env.VERCEL_PROJECT_PRODUCTION_URL || process.env.VERCEL_URL;
  if (!value) throw new Error("NEXT_PUBLIC_APP_URL is required.");
  return value.startsWith("http") ? value.replace(/\/$/, "") : `https://${value.replace(/\/$/, "")}`;
}
export function oauthRedirect(platform: Platform) {
  const explicit = platform === "instagram" ? process.env.INSTAGRAM_REDIRECT_URI : process.env.THREADS_REDIRECT_URI;
  return explicit || `${baseUrl()}/api/oauth/${platform}/callback`;
}
export function getPlatformApp(platform: Platform) {
  const appId = platform === "instagram" ? process.env.INSTAGRAM_APP_ID : process.env.THREADS_APP_ID;
  const appSecret = platform === "instagram" ? process.env.INSTAGRAM_APP_SECRET : process.env.THREADS_APP_SECRET;
  if (!appId || !appSecret) throw new Error(`${platform} Meta App ID/Secret are not configured.`);
  return { appId, appSecret };
}
export function graphVersion() { return process.env.META_GRAPH_VERSION || "v27.0"; }
