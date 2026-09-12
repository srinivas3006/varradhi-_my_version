enum Environment { dev, staging, prod }

class AppConfig {
  static Environment environment = Environment.prod;

  static String get baseUrl {
    switch (environment) {
      case Environment.dev:
        return 'https://incite-backend.onrender.com';
      case Environment.staging:
        return 'https://incite-backend.onrender.com';
      case Environment.prod:
        return 'https://incite-backend.onrender.com';
    }
  }

  static const Duration connectTimeout = Duration(seconds: 35);
  static const Duration sendTimeout = Duration(seconds: 35);
  static const Duration receiveTimeout = Duration(seconds: 35);
  static const int maxRetries = 3;
}
