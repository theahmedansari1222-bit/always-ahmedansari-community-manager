# Always Ahmed Ansari — AI Community Manager

A hosted Next.js 16 dashboard for Instagram Creator and Threads comment moderation. Uses Supabase Auth/Postgres, Google Gemini for English reply drafts, official Meta OAuth, comment sync/webhooks and server-side reply publishing.

## Current scope

Implemented in this repository:

- Supabase cookie-based Auth (password and email magic-link sign-in).
- Owner-scoped workspace dashboard and comment queue.
- Official Instagram Login and Threads OAuth flows.
- Encrypted Meta access token storage (AES-256-GCM) through server-only RPCs.
- Manual account sync for recent posts/comments/replies (up to 15 recent posts per click; Meta permissions and rate limits apply).
- Gemini classification/reply drafting via Supabase Edge Function.
- Human review, edit, skip and manual publish endpoints.
- Webhook verification/signature validation endpoints for Instagram and Threads, with server-side AI processing for supported incoming comment/reply payloads.
- Scheduled token refresh endpoint for Vercel Cron.
- GitHub Actions workflow to deploy the Supabase Edge Function.

Requires credentials and configuration from the account owner. No social platform login password or API key is included.

## Runtime and dependencies

- Node.js 22 or newer
- Next.js 16.4.6, React 19.3.1, Supabase JS 2.119.0, Supabase SSR 0.12.7
- Direct dependencies are pinned in `package.json`. Generate/commit `package-lock.json` with `npm install` on your machine before team production use.

## Local setup

```bash
npm install
cp .env.example .env.local
npm run dev
```

Populate `.env.local` using `docs/manual-secrets.md`. Sign-in relies on Supabase Auth; configure your email/password user or enable Supabase email OTP delivery.

## Existing Supabase project

This project is designed for the already-created database in the user's existing Supabase project. **Do not create a new project or reset the database.** Run `supabase/manual/001_social_credentials_rpc.sql` once in the existing project's SQL Editor. It adds owner-checked RPC functions for encrypted credentials and unique lookup indexes. Existing app tables/workspace are reused.

The `private.social_credentials` table is intended for encrypted tokens and is never queried from the browser. Supabase Security Advisor has reported RLS disabled on that private table. The private schema should remain excluded from Data API exposed schemas; review and address this security warning before production launch. The migration does not automatically enable RLS without a matching policy design. Review the recommendation in `docs/manual-secrets.md`; do not expose the `private` schema through the Data API.

## Supabase Edge Function

Set Edge Function Secrets:

- `GEMINI_API_KEY`
- `GEMINI_MODEL` (optional; set to a model enabled for your key)
- `APP_ORIGIN`
- `TOKEN_ENCRYPTION_KEY` (same base64 key as Vercel)
- `ENABLE_AUTO_REPLY=false` initially
- `INTERNAL_PROCESSING_SECRET` (same high-entropy value configured in Vercel)

Deploy:

```bash
supabase functions deploy classify-and-reply --project-ref YOUR_PROJECT_REF
```

The Gemini key is server-side only. Do not use a `NEXT_PUBLIC_` prefix.

## Meta app setup

Follow `docs/meta-app-setup.md`. Instagram API access is for professional Creator/Business accounts, not personal consumer accounts. Meta controls Standard/Advanced Access, app review and rate limits. Both OAuth callback URLs must be allow-listed exactly in their respective Meta app settings.

## Vercel

Import the GitHub repository and set variables from `.env.example` and `docs/manual-secrets.md`. `vercel.json` schedules token refresh. Set `NEXT_PUBLIC_APP_URL` after the production domain has been assigned.

## GitHub Actions

Add repository secrets `SUPABASE_ACCESS_TOKEN` and `SUPABASE_PROJECT_REF`. The workflow deploys the Supabase Edge Function when its source changes on `main`.

## Safety defaults

- English replies only.
- Low confidence, threats, personal data, serious allegations, uncertain facts, and sensitive political/religious/historical disputes are held for review.
- Manual approval is always available.
- Public automatic publishing is OFF until you explicitly set `ENABLE_AUTO_REPLY=true` in Supabase Edge Function Secrets. Keep it off until you have verified both integrations and test replies.

## Important limitation

Meta requires your app to be correctly configured and may require app review/Advanced Access for accounts outside app roles. The code cannot grant permissions or guarantee approval. Webhook payload fields can differ by product and subscription; use dashboard Sync as a recovery/import path. No real Meta account or production webhook has been available in this build environment, so complete Meta end-to-end verification after configuring your developer apps and test accounts.
