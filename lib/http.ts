export function jsonError(message: string, status = 400) {
  return Response.json({ error: message }, { status, headers: { "Cache-Control": "no-store" } });
}
export async function parseJson(request: Request) {
  try { return await request.json(); } catch { throw new Error("Request body must be valid JSON."); }
}
