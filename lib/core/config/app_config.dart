enum Environment { dev, staging, prod }

class AppConfig {
  /// =========================================================================
  /// BACKEND ENVIRONMENT TOGGLE:
  /// Set [useRenderTestBackend] to `true` for testing with Render backend.
  /// Set [useRenderTestBackend] to `false` to switch back to AWS production backend.
  /// =========================================================================
  static const bool useRenderTestBackend = true;

  /// Render Testing Backend (available for test builds)
  static const String renderTestingUrl = 'https://incite-backend.onrender.com';

  /// Original Production Backend (AWS)
  static const String awsProductionUrl = 'https://api.vaaradhinews.com';

  static Environment environment = Environment.dev;

  static String get baseUrl {
    if (useRenderTestBackend) {
      return renderTestingUrl;
    }
    switch (environment) {
      case Environment.dev:
      case Environment.staging:
      case Environment.prod:
        return awsProductionUrl;
    }
  }

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration sendTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 10);
  static const int maxRetries = 2;
}
