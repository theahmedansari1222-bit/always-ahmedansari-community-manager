# Values Ahmed must add manually

Never paste these secrets into chat or commit them to GitHub.

## Existing service accounts and environment

The existing Supabase project is `zhentropic_ai` (`xqdmduepioiympjbzobp`, region `ap-northeast-1`). Keep using it; do not reset or replace it. The app's workspace and database tables already exist there. In Supabase → Authentication → URL Configuration, set the production Site URL and allow the exact redirect `https://YOUR_DOMAIN/auth/callback` for email magic links.

## Vercel project environment variables

You will need a Vercel account and must import the public GitHub repository after you push the ZIP contents. Add the values below under Project → Settings → Environment Variables for Production (and Preview only when you intend to test there).

Copy from Supabase Project → Connect / API Keys:

- `NEXT_PUBLIC_SUPABASE_URL`
- `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`
- `SUPABASE_SECRET_KEY` (server only; legacy `service_role` JWT is an alternative)

Generate a 32-byte encryption key locally (terminal):

```bash
openssl rand -base64 32
```

Add its output as `TOKEN_ENCRYPTION_KEY`. Never rotate this without a migration/re-encryption plan, or stored tokens become unreadable.

Create separate Meta Developer app credentials, if using separate apps:

- `INSTAGRAM_APP_ID`, `INSTAGRAM_APP_SECRET`
- `THREADS_APP_ID`, `THREADS_APP_SECRET`
- `INSTAGRAM_REDIRECT_URI`, `THREADS_REDIRECT_URI` using your final Vercel domain
- `INSTAGRAM_WEBHOOK_VERIFY_TOKEN`, `THREADS_WEBHOOK_VERIFY_TOKEN` (you choose long random strings and enter the same values in Meta)

Also set:

- `NEXT_PUBLIC_APP_URL` to the deployed HTTPS origin
- `CRON_SECRET` to a long random value for token refresh cron
- `INTERNAL_PROCESSING_SECRET` to a random 32+ character value shared only with Supabase Edge Function Secrets

## Supabase Edge Function Secrets

Create a Gemini key in Google AI Studio, then set in Supabase → Edge Functions → Secrets:

- `GEMINI_API_KEY` (the key from Google AI Studio; do not put it in GitHub or browser code)
- `GEMINI_MODEL=gemini-3.8-flash` (stable model currently listed by Google; change only if your key supports a different model)
- `APP_ORIGIN` (the deployed Vercel origin)
- `TOKEN_ENCRYPTION_KEY` (same key as Vercel)
- `ENABLE_AUTO_REPLY=false` initially
- `INTERNAL_PROCESSING_SECRET` (same server-to-server secret as Vercel)

Keep auto-reply disabled until account connection, webhook delivery, manual reply publishing and safety tests have all passed. Then explicitly decide whether to enable it.

## Existing database security warning

The current Supabase Security Advisor reports that `private.social_credentials` has RLS disabled. I have not changed this live setting. Review this recommendation in the Supabase Dashboard. Supabase's suggested SQL is:

```sql
ALTER TABLE private.social_credentials ENABLE ROW LEVEL SECURITY;
```

The application accesses this table only through owner-checked `SECURITY DEFINER` RPCs granted to `service_role` / the new secret key; do not expose the `private` schema through the Data API. Test the OAuth save/read/disconnect flows after deciding to enable RLS. Supabase injects `SUPABASE_SECRET_KEYS` and `SUPABASE_PUBLISHABLE_KEYS` automatically into Edge Functions; these reserved `SUPABASE_` variables are not added as custom secrets.

## GitHub Actions repository secrets

For automatic Supabase Edge Function deployment:

- `SUPABASE_ACCESS_TOKEN` from Supabase Account → Access Tokens
- `SUPABASE_PROJECT_REF` = `xqdmduepioiympjbzobp` (the existing project)

## Meta app setup

Read `meta-app-setup.md`. You must configure OAuth redirect URIs, add your own IG Creator/Threads accounts as testers, and obtain whatever Meta permissions/app review is needed for your intended use.
