# Zhentropic — Clarity in Complexity

Flutter app (Android + iOS) with Supabase and the DeepSeek API.

## One-time setup
1. Supabase > SQL Editor: run `sql_schema.sql`.
2. Supabase > Authentication: enable Google and add the redirect URL `io.supabase.zhentropic://login-callback/`.
3. GitHub repo > Settings > Secrets and variables > Actions, add one secret: `DEEPSEEK_API_KEY`.
   The Supabase URL and publishable key are already built in (they are public by design; Row Level Security
   from `sql_schema.sql` protects the data). Never put a Supabase secret/service_role key in the app.

## Automatic builds
- Every push to `main` builds a release APK: Actions tab > latest run > Artifacts > `zhentropic-apk`.
- Push a tag such as `v1.0.0` and the APK is also attached to a GitHub Release.
- Actions > Build Zhentropic > Run workflow > tick "build_ios" for an unsigned iOS compile check.

The repo only holds the Dart code: `tool/setup_platforms.sh` creates `android/` and `ios/` in CI and adds the
permissions, deep link and app name. APKs are signed with Flutter's debug key (fine for testing); add your own
keystore before publishing to Google Play.

## Local run
    flutter create --platforms=android,ios --org com.zhentropic --project-name zhentropic .   # first time only
    python3 tool/patch_platforms.py
    flutter run --dart-define=DEEPSEEK_API_KEY=...
