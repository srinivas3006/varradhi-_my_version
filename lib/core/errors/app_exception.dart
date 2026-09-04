abstract class AppException implements Exception {
  final String message;
  final int? statusCode;

  AppException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}

class NetworkException extends AppException {
  NetworkException([super.message = 'No Internet Connection']);
}

class ServerException extends AppException {
  ServerException(super.message, [super.statusCode]);
}

class TimeoutException extends AppException {
  TimeoutException([super.message = 'Connection Timeout. Please try again.']);
}
