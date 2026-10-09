# Agent Uncle

Flutter client for Android, iOS, and Web backed by Supabase.

## Authentication

The app initializes Supabase with the project's public URL and publishable key,
then uses Supabase hosted OAuth for Google sign-in. Provider secrets and the
Supabase secret/service-role key must never be added to this client repository.
Kakao sign-in is temporarily commented out until Biz App registration is done.

Before Google sign-in can complete, configure the provider in Supabase:

1. In Google Cloud, create a Web OAuth client and add this authorized redirect
   URI:

   `https://auicerytbhnqeakmkscs.supabase.co/auth/v1/callback`

2. In Supabase Dashboard, open **Authentication > Providers > Google**, enable
   Google, and save the Google client ID and client secret there.
3. In **Authentication > URL Configuration**, allow these redirects:

   - `com.hanbatco.agentuncle://login-callback/`
   - The deployed Web origin
   - The local Web origin used for development, such as
     `http://localhost:3000/**`

The defaults in `SupabaseConfig` can be overridden per build:

```sh
flutter run \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=your-publishable-key
```

<!-- TODO(auth): Restore after Kakao Biz App registration.
For Kakao, configure the same Supabase callback URL in Kakao Developers, then
enable the Kakao provider with the REST API key and Kakao Login Client Secret.
Kakao returns to `com.hanbatco.agentuncle://login-callback/` on Android and iOS,
or to the current origin on Web.
-->
