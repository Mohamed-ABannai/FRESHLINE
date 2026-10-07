const String splashGifAssetPath = 'assets/branding/freshline-splash.gif';
const String appLogoAssetPath = 'assets/branding/logo-no-bg.png';
const String appIconAssetPath = 'assets/branding/app-icon.png';

const String groqApiKey =
    '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';
const String groqModel = 'llama-3.3-70b-versatile';

const String supportPhoneDisplay = '+973 3533 6641';
const String supportPhoneUri = '+97335336641';
const String supportEmail = 'salman745mohd@gmail.com';
const String supportWhatsAppUrl = 'https://wa.me/97335336641';
const String supportAddress = 'Seef District, Manama, Bahrain';
const String supportHours = 'Daily · 9:00 AM to 10:00 PM';

/// Optional: GoMaps API key used for external map services (if enabled).
///
/// Configure via: `--dart-define=GOMAPS_API_KEY=...`
const String goMapsApiKey = String.fromEnvironment(
  'GOMAPS_API_KEY',
  defaultValue: '',
);

const String supabaseUrl = 'https://ljowjubzpwlhjrgsvhth.supabase.co';
const String supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imxqb3dqdWJ6cHdsaGpyZ3N2aHRoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ3MDg3MDYsImV4cCI6MjA5MDI4NDcwNn0.li5z6clFzS1JeotfbBYmAgt7kKPfReIwmpkeFjCHGOY';
const String supabaseSalonsTable = 'salons';
const String supabaseProductsTable = 'products';
const String supabaseSalonMediaBucket = 'salon-media';
const String supabaseSalonDocumentsBucket = 'salon-documents';

/// Dev-only escape hatch: allows entering the fixed code `246810` to pass OTP
/// verification when Supabase OTP functions are not deployed/configured yet.
///
/// Set to `false` before releasing the app.
const bool _isReleaseMode = bool.fromEnvironment(
  'dart.vm.product',
  defaultValue: false,
);

/// Unsafe fallback: allows the app to generate and display OTP codes locally
/// when Supabase OTP Edge Functions are not deployed yet.
///
/// This is insecure and should be disabled before production release.
const bool allowUnsafeLocalOtpBypass =
    bool.fromEnvironment('ALLOW_UNSAFE_LOCAL_OTP_BYPASS', defaultValue: false) &&
    !_isReleaseMode;

/// Temporary escape hatch requested for the staged MVP:
/// allow local OTP fallback *only* for password reset even in release builds.
///
/// Disable before publishing to production stores.
const bool allowPasswordResetLocalOtpFallback =
    bool.fromEnvironment(
      'ALLOW_PASSWORD_RESET_LOCAL_OTP_FALLBACK',
      defaultValue: true,
    );
