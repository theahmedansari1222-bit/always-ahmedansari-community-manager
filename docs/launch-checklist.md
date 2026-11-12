# Launch checklist

## Code / deployment
- [ ] Push the complete project to GitHub `main`.
- [ ] Import GitHub repository into Vercel and set environment variables from `manual-secrets.md`.
- [ ] Deploy to Vercel and copy the final production URL into `NEXT_PUBLIC_APP_URL` and both Meta redirect URIs.
- [ ] Run `supabase/manual/001_social_credentials_rpc.sql` once in the existing Supabase SQL Editor (do not reset or recreate the existing project).
- [ ] Set Supabase Edge Function secrets from `manual-secrets.md`.
- [ ] Add GitHub Actions secrets `SUPABASE_ACCESS_TOKEN` and `SUPABASE_PROJECT_REF`.

## Meta setup
- [ ] Create/configure Instagram Login app, permission scopes and callback URL.
- [ ] Create/configure Threads app/use case, permission scopes and callback URL.
- [ ] Add own accounts as testers and complete OAuth consent.
- [ ] Configure webhook callback URLs and verify tokens; subscribe to comments/replies fields.
- [ ] Confirm Sync imports actual comments and account permissions allow comment read/reply.

## Safety and production
- [ ] Test reply generation across normal questions, criticism, sarcasm, threats, personal data, allegations and sensitive subjects.
- [ ] Test manual approval + reply publishing on a test comment on each platform.
- [ ] Confirm token refresh cron runs successfully.
- [ ] Keep `ENABLE_AUTO_REPLY=false` during initial rollout.
- [ ] Only enable automated publishing after manual reply tests and webhook delivery are confirmed.
- [ ] Review Supabase Security Advisor warning for RLS disabled on `private.social_credentials`; the suggested SQL is in `docs/manual-secrets.md`. Do not expose the `private` schema through the Data API. The app reads/writes this table only through owner-checked server-only RPCs.
- [ ] Run `npm install`, `npm run typecheck`, and `npm run build` locally after copying environment settings; commit the generated `package-lock.json`.
