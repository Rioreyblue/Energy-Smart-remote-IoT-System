/// Cloudinary configuration
///
/// NOTE: For production builds, prefer passing secrets via environment:
///   flutter build apk --dart-define=CLOUDINARY_API_KEY=xxx --dart-define=CLOUDINARY_API_SECRET=yyy
/// or by setting `CLOUDINARY_URL`.
class CloudinaryConfig {
  /// Cloud name / account identifier
  static const String cloudName = 'duza86enw';

  /// Unsigned upload preset
  static const String uploadPreset = 'energysmart_upload';

  /// Default folder to store assets in Cloudinary
  static const String defaultFolder = 'test/data';

  /// API key (optional for unsigned uploads, required for signed requests)
  static const String apiKey = String.fromEnvironment(
    'CLOUDINARY_API_KEY',
    defaultValue: '199568522614648',
  );

  /// API secret (avoid using fallback in production; use env overrides)
  static const String apiSecret = String.fromEnvironment(
    'CLOUDINARY_API_SECRET',
    defaultValue: 'WqTTy_PBHMZUIhJ3ZzY4Pdouhvk',
  );

  /// Full Cloudinary URL (used by some SDKs or server-side integrations)
  static const String cloudinaryUrl = String.fromEnvironment(
    'CLOUDINARY_URL',
    defaultValue:
        'cloudinary://199568522614648:WqTTy_PBHMZUIhJ3ZzY4Pdouhvk@duza86enw',
  );
}
