abstract final class SupabaseConfig {
  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://auicerytbhnqeakmkscs.supabase.co',
  );

  // Supabase publishable keys are designed to be included in client apps.
  // Authorization must always be enforced with RLS, never with this key.
  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_mOfMxJwI_iWlc7_JQ1MuVA_ApBXJPEd',
  );

  static const mobileAuthCallback = 'com.hanbatco.agentuncle://login-callback/';
  static String get webAuthCallback {
    const configured = String.fromEnvironment('AUTH_WEB_REDIRECT_URL');
    return configured.isNotEmpty ? configured : '${Uri.base.origin}/';
  }
}
