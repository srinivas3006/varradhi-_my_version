import 'app_config.dart';

class NetworkConfig {
  final String baseUrl;
  final Duration connectTimeout;
  final Duration sendTimeout;
  final Duration receiveTimeout;
  final int maxRetries;
  final bool enableLogging;

  NetworkConfig({
    String? baseUrl,
    Duration? connectTimeout,
    Duration? sendTimeout,
    Duration? receiveTimeout,
    int? maxRetries,
    this.enableLogging = true,
  })  : baseUrl = baseUrl ?? AppConfig.baseUrl,
        connectTimeout = connectTimeout ?? AppConfig.connectTimeout,
        sendTimeout = sendTimeout ?? AppConfig.sendTimeout,
        receiveTimeout = receiveTimeout ?? AppConfig.receiveTimeout,
        maxRetries = maxRetries ?? AppConfig.maxRetries;

  NetworkConfig copyWith({
    String? baseUrl,
    Duration? connectTimeout,
    Duration? sendTimeout,
    Duration? receiveTimeout,
    int? maxRetries,
    bool? enableLogging,
  }) {
    return NetworkConfig(
      baseUrl: baseUrl ?? this.baseUrl,
      connectTimeout: connectTimeout ?? this.connectTimeout,
      sendTimeout: sendTimeout ?? this.sendTimeout,
      receiveTimeout: receiveTimeout ?? this.receiveTimeout,
      maxRetries: maxRetries ?? this.maxRetries,
      enableLogging: enableLogging ?? this.enableLogging,
    );
  }
}
