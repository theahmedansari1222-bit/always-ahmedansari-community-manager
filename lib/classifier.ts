import "server-only";

export async function classifyFromWebhook(commentId: string) {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
  const internalSecret = process.env.INTERNAL_PROCESSING_SECRET;
  if (!url || !key || !internalSecret || internalSecret.length < 32) {
    console.error("Webhook comment saved but automatic classification is not configured.");
    return false;
  }
  const response = await fetch(`${url}/functions/v1/classify-and-reply`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      apikey: key,
      "x-internal-processing-secret": internalSecret,
    },
    body: JSON.stringify({ commentId }),
    cache: "no-store",
  });
  if (!response.ok) {
    console.error("Webhook classifier returned", response.status, (await response.text()).slice(0, 500));
    return false;
  }
  return true;
}
