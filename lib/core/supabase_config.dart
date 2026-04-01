/// Supabase configuration.
///
/// Replace these values with your actual Supabase project credentials.
/// You can find these in your Supabase project settings > API.
class SupabaseConfig {
  SupabaseConfig._();

  /// Your Supabase project URL
  /// Example: https://xyzcompany.supabase.co
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'YOUR_SUPABASE_URL',
  );

  /// Your Supabase anon/public key
  /// This is safe to use in client-side code
  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'YOUR_SUPABASE_ANON_KEY',
  );

  /// Check if Supabase is properly configured
  static bool get isConfigured =>
      url != 'YOUR_SUPABASE_URL' && anonKey != 'YOUR_SUPABASE_ANON_KEY';
}
