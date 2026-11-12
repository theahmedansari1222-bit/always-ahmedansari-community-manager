// lib/constants.dart
//
// Centralized, validated configuration access for the application.
//
// This module provides compile-time checked access to environment variables
// supplied via --dart-define. It deliberately fails fast when a required
// value is missing so the application never silently falls back to a
// hardcoded default that could point at an unknown backend.

/// The base URL of our own Supabase project.
///
/// Set with --dart-define=SUPABASE_URL=https://your-project.supabase.co
const kSupabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: '',
);

/// The client-side publishable key (or legacy anon key) for our Supabase
/// project. This is a public credential safe to ship in the app bundle.
///
/// Set with --dart-define=SUPABASE_PUBLISHABLE_KEY=your-publishable-key
const kSupabasePublishableKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
  defaultValue: '',
);

/// The DeepSeek API key used for AI features.
///
/// Set with --dart-define=DEEPSEEK_API_KEY=your-key
const kDeepSeekApiKey = String.fromEnvironment(
  'DEEPSEEK_API_KEY',
  defaultValue: '',
);

/// The DeepSeek API endpoint override (optional).
const kDeepSeekEndpoint = String.fromEnvironment(
  'DEEPSEEK_ENDPOINT',
  defaultValue: 'https://api.deepseek.com/chat/completions',
);

/// Validates that required configuration is present.
///
/// Returns a list of human-readable problems; an empty list means the
/// configuration is ready to use.
List<String> validateConfig() {
  final problems = <String>[];

  if (kSupabaseUrl.isEmpty) {
    problems.add('SUPABASE_URL is not set. Provide it via --dart-define.');
  } else {
    final uri = Uri.tryParse(kSupabaseUrl);
    if (uri == null || !uri.hasScheme) {
      problems.add('SUPABASE_URL is not a valid URL: "$kSupabaseUrl".');
    } else if (uri.scheme != 'https' && uri.scheme != 'http') {
      problems.add('SUPABASE_URL must use http or https scheme.');
    }
  }

  if (kSupabasePublishableKey.isEmpty) {
    problems.add('SUPABASE_PUBLISHABLE_KEY is not set. Provide it via --dart-define.');
  }

  if (kDeepSeekApiKey.isEmpty) {
    problems.add('DEEPSEEK_API_KEY is not set. Provide it via --dart-define.');
  }

  return problems;
}

/// Throws a [StateError] if configuration is invalid.
///
/// Call this early in [main] so the application fails loudly instead of
/// connecting to an unknown backend.
void assertValidConfig() {
  final problems = validateConfig();
  if (problems.isNotEmpty) {
    throw StateError(
      'Application configuration is incomplete:\n'
      '- ${problems.join("\n- ")}',
    );
  }
}
