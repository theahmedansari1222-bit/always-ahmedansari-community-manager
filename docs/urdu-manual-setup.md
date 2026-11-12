# دستی سیٹ اپ گائیڈ — Always Ahmed Ansari

یہ ZIP مکمل سورس کوڈ پیکج ہے۔ اسے چلانے کے لیے کچھ اکاؤنٹس، keys اور Meta permissions آپ کو اپنے dashboards سے خود حاصل کرکے درج کرنا ہوں گے۔ **اپنا پاس ورڈ، access token یا API key کسی چیٹ میں نہ بھیجیں اور GitHub پر commit نہ کریں۔**

## 1) Google Gemini

1. Google AI Studio میں API key بنائیں: https://aistudio.google.com/apikey
2. Supabase Dashboard → Edge Functions → Secrets میں یہ values شامل کریں:
   - `GEMINI_API_KEY` = آپ کی Google AI Studio key
   - `GEMINI_MODEL` = `gemini-3.8-flash`
   - `APP_ORIGIN` = Vercel پر deploy ہونے کے بعد آپ کی site کا HTTPS origin

## 2) Supabase — موجودہ پروجیکٹ ہی استعمال کریں

موجودہ پروجیکٹ: `zhentropic_ai`، Project Ref: `xqdmduepioiympjbzobp`۔ اسے delete، reset یا replace نہ کریں۔ موجودہ tables اور workspace پہلے سے موجود ہیں۔

1. Supabase → Project → Connect / API Keys سے یہ حاصل کریں:
   - Project URL
   - Publishable key
   - Server-only Secret key (یا پرانی `service_role` key)
2. `supabase/manual/001_social_credentials_rpc.sql` کو موجودہ پروجیکٹ کے SQL Editor میں **ایک مرتبہ** چلائیں۔ یہ encrypted social credentials کے لیے owner-checked RPC functions اور duplicate-protection indexes بناتا ہے۔
3. 32-byte encryption key اپنے کمپیوٹر کے terminal میں بنائیں:

   ```bash
   openssl rand -base64 32
   ```

   اس value کو `TOKEN_ENCRYPTION_KEY` کہیں۔ یہی value Vercel اور Supabase Edge Function دونوں میں رکھنی ہے۔ اسے بعد میں تبدیل نہ کریں جب تک stored tokens کو re-encrypt کرنے کا منصوبہ نہ ہو۔
4. ایک الگ random، کم از کم 32 characters والا secret بنائیں۔ اسے `INTERNAL_PROCESSING_SECRET` کہیں اور Vercel اور Supabase Edge Function دونوں میں ایک ہی value رکھیں۔
5. Supabase → Authentication → URL Configuration میں بعد میں اپنی Vercel production URL کو Site URL بنائیں اور `https://YOUR_DOMAIN/auth/callback` کو Redirect URLs میں شامل کریں۔

### Supabase Security Advisor کی اہم تنبیہ

موجودہ `private.social_credentials` table پر RLS بند ہونے کی Security Advisor warning موجود ہے۔ اس ZIP نے اسے خود سے تبدیل نہیں کیا۔ Supabase کی تجویز یہ SQL ہے:

```sql
ALTER TABLE private.social_credentials ENABLE ROW LEVEL SECURITY;
```

اسے چلانے سے پہلے اپنی table/API exposure settings کا جائزہ لیں۔ `private` schema کو Data API کے exposed schemas میں شامل نہ کریں۔ اس ایپ کا server-side code credentials تک صرف owner-checked RPCs کے ذریعے پہنچتا ہے۔ تبدیلی کے بعد OAuth connect، read اور disconnect flows کو دوبارہ test کریں۔

## 3) Meta Developer App — Instagram اور Threads

یہ ایپ Instagram/Threads کا password نہیں مانگتی؛ official Meta OAuth استعمال کرتی ہے۔ آپ کو Meta Developer account میں app(s) بنانا اور متعلقہ products/use cases فعال کرنا ہوں گے۔

- Instagram اکاؤنٹ **Professional Creator یا Business** ہونا چاہیے؛ عام personal account اس API flow کے لیے supported نہیں۔
- Instagram permissions: `instagram_business_basic`, `instagram_business_manage_comments`.
- Threads permissions: `threads_basic`, `threads_read_replies`, `threads_manage_replies`, `threads_content_publish`.
- Instagram OAuth callback: `https://YOUR_DOMAIN/api/oauth/instagram/callback`
- Threads OAuth callback: `https://YOUR_DOMAIN/api/oauth/threads/callback`
- Instagram webhook: `https://YOUR_DOMAIN/api/webhooks/instagram`
- Threads webhook: `https://YOUR_DOMAIN/api/webhooks/threads`

اپنے اکاؤنٹس کو Meta app کے testers میں شامل کریں۔ Meta App Review یا Advanced Access کی ضرورت آپ کے access level/use case کے مطابق ہو سکتی ہے؛ approval کی ضمانت کوڈ نہیں دے سکتا۔ مکمل ہدایات `meta-app-setup.md` میں ہیں۔

## 4) Vercel Environment Variables

GitHub repository کو Vercel میں import کرنے کے بعد Project → Settings → Environment Variables میں یہ values درج کریں:

- `NEXT_PUBLIC_SUPABASE_URL`
- `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`
- `SUPABASE_SECRET_KEY` (صرف server-side؛ اسے `NEXT_PUBLIC_` نہ بنائیں)
- `NEXT_PUBLIC_APP_URL` = آپ کی Vercel HTTPS site
- `TOKEN_ENCRYPTION_KEY` = وہی 32-byte Base64 key جو Supabase میں ہے
- `INTERNAL_PROCESSING_SECRET` = وہی random secret جو Supabase میں ہے
- `INSTAGRAM_APP_ID`, `INSTAGRAM_APP_SECRET`
- `THREADS_APP_ID`, `THREADS_APP_SECRET` (اگر ایک Meta app دونوں products کے لیے استعمال ہو تو IDs/secrets ایک جیسے ہو سکتے ہیں)
- `INSTAGRAM_REDIRECT_URI`, `THREADS_REDIRECT_URI` = اوپر کے exact callback URLs
- `INSTAGRAM_WEBHOOK_VERIFY_TOKEN`, `THREADS_WEBHOOK_VERIFY_TOKEN` = دو الگ random strings؛ انہی کو Meta webhook setup میں بھی درج کریں
- `CRON_SECRET` = ایک الگ random secret
- `META_GRAPH_VERSION` = `v27.0`

پہلی deployment کے بعد اصل Vercel domain معلوم ہوگا۔ اسی domain کو ان callback URLs، `NEXT_PUBLIC_APP_URL` اور Supabase کے `APP_ORIGIN` میں بالکل ایک جیسا استعمال کریں۔

## 5) Supabase Edge Function Secrets

Supabase → Edge Functions → Secrets میں یہ رکھیں:

- `GEMINI_API_KEY`
- `GEMINI_MODEL=gemini-3.8-flash`
- `APP_ORIGIN`
- `TOKEN_ENCRYPTION_KEY`
- `INTERNAL_PROCESSING_SECRET`
- `ENABLE_AUTO_REPLY=false`

`SUPABASE_URL`، `SUPABASE_SECRET_KEYS` اور `SUPABASE_PUBLISHABLE_KEYS` Supabase کے runtime environment میں دستیاب ہوتے ہیں؛ `SUPABASE_` prefix والے custom variables بنانے کی کوشش نہ کریں۔

## 6) GitHub Actions Secrets

GitHub repository → Settings → Secrets and variables → Actions میں:

- `SUPABASE_ACCESS_TOKEN` = Supabase Account Access Token
- `SUPABASE_PROJECT_REF` = `xqdmduepioiympjbzobp`

اس کے بعد `main` پر function source میں تبدیلی push ہونے پر workflow Supabase Edge Function deploy کر سکتی ہے۔ پہلی دفعہ deployment آپ Supabase CLI سے بھی کر سکتے ہیں:

```bash
supabase functions deploy classify-and-reply --project-ref xqdmduepioiympjbzobp
```

## 7) پہلی deployment اور test کا آرڈر

1. ZIP extract کریں اور repository کی `main` branch میں تمام project files push کریں۔
2. GitHub repository کو Vercel میں import کرکے environment variables درج کریں؛ deployment کریں۔
3. اصل Vercel domain ملنے پر Meta callback URLs، Supabase Auth URLs اور `APP_ORIGIN` درست کریں، پھر redeploy کریں۔
4. Supabase SQL Editor میں RPC SQL چلائیں اور Edge Function Secrets درج کریں۔
5. Meta OAuth اور webhook setup مکمل کریں۔
6. Login، Instagram/Threads connect، Sync، Gemini draft، manual approve/send، webhook delivery اور weekly token refresh کو test کریں۔
7. ابتدا میں `ENABLE_AUTO_REPLY=false` ہی رکھیں۔ تمام tests کامیاب ہونے اور آپ کی واضح منظوری کے بعد ہی اسے `true` کرنے پر غور کریں۔

## 8) اپنے کمپیوٹر پر build check

Node.js 22 یا اس سے جدید version استعمال کریں:

```bash
npm install
npm run typecheck
npm run build
```

`npm install` سے `package-lock.json` بنے گا؛ اسے GitHub پر push کریں تاکہ آئندہ installs lockfile کے مطابق ہوں۔ اس موجودہ build environment میں npm registry سے package download timeout ہوا، اس لیے یہاں مکمل dependency install اور production build verify نہیں ہو سکی؛ TypeScript/TSX syntax parse الگ سے چیک کیا گیا ہے۔
