# Meta developer app setup

This app uses official OAuth flows; it never asks for your Instagram or Threads password.

## Before connecting

- Instagram must be a professional Creator or Business account. Consumer/personal Instagram accounts are not supported by the Instagram Platform API.
- Create/configure an Instagram app with Instagram Login (Business Login for Instagram) and request `instagram_business_basic` and `instagram_business_manage_comments`.
- Create/configure a Threads app/use case and request `threads_basic`, `threads_read_replies`, `threads_manage_replies`, and `threads_content_publish`.
- Configure OAuth redirect URIs exactly as shown below after your Vercel domain exists (scheme, host, path and trailing slash must match):
  - `https://YOUR_DOMAIN/api/oauth/instagram/callback`
  - `https://YOUR_DOMAIN/api/oauth/threads/callback`
- Use the app's Meta Login/OAuth product setup; Meta may require app review / Advanced Access before accounts outside app roles can authorize. Start in Development mode with your own account added as an app tester.

## Meta environment variables

Set `INSTAGRAM_APP_ID`, `INSTAGRAM_APP_SECRET`, `THREADS_APP_ID`, `THREADS_APP_SECRET`, `INSTAGRAM_REDIRECT_URI`, and `THREADS_REDIRECT_URI` in Vercel. If using a single Meta app, the IDs/secrets may be the same, but configure the products and permissions for both flows.

## Webhooks

After deployment, configure each product's webhook callback URL:

- Instagram: `https://YOUR_DOMAIN/api/webhooks/instagram`
- Threads: `https://YOUR_DOMAIN/api/webhooks/threads`

Set the corresponding verify token in `INSTAGRAM_WEBHOOK_VERIFY_TOKEN` and `THREADS_WEBHOOK_VERIFY_TOKEN` in Vercel and enter the same token in Meta's webhook setup. Subscribe to the relevant comments/replies fields offered by the product. Meta signs delivery requests with `X-Hub-Signature-256`; this app validates the signature against each product's app secret.

Payload field availability may vary by product/version and webhook subscription. Use the Sync buttons in the dashboard for initial import and as a fallback while webhook permissions/subscriptions are being reviewed.

## Permissions and production

Meta controls product access, review, allowed users, app mode, rate limits and available webhook fields. App Review / Advanced Access is required if your use case exceeds Standard Access for app-role users. Approval is not guaranteed by code alone.
