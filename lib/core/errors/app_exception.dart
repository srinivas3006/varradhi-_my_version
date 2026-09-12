abstract class AppException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic technicalDetails;

  AppException(this.message, [this.statusCode, this.technicalDetails]);

  @override
  String toString() => message;
}

/// Generic API error
class ApiException extends AppException {
  ApiException([
    super.message = 'నెట్‌వర్క్ అభ్యర్థన విఫలమైంది',
    super.statusCode,
    super.technicalDetails,
  ]);
}

/// Network unreachable or no internet connection
class NetworkException extends AppException {
  NetworkException([
    super.message = 'ఇంటర్నెట్ కనెక్షన్ లేదు. దయచేసి నెట్‌వర్క్ తనిఖీ చేయండి.',
    super.statusCode,
    super.technicalDetails,
  ]);
}

/// Connection, send, or receive timeout
class TimeoutException extends AppException {
  TimeoutException([
    super.message = 'సర్వర్ స్పందించడానికి ఎక్కువ సమయం పట్టింది. దయచేసి మళ్ళీ ప్రయత్నించండి.',
    super.statusCode,
    super.technicalDetails,
  ]);
}

/// 401 Unauthorized
class UnauthorizedException extends AppException {
  UnauthorizedException([
    super.message = 'సెషన్ గడువు ముగిసింది. దయచేసి మళ్లీ లాగిన్ అవ్వండి.',
    super.statusCode = 401,
    super.technicalDetails,
  ]);
}

/// 403 Forbidden
class ForbiddenException extends AppException {
  ForbiddenException([
    super.message = 'ఈ విభాగాన్ని యాక్సెస్ చేయడానికి మీకు అనుమతి లేదు.',
    super.statusCode = 403,
    super.technicalDetails,
  ]);
}

/// 404 Not Found
class NotFoundException extends AppException {
  NotFoundException([
    super.message = 'అభ్యర్థించిన కంటెంట్ కనుగొనబడలేదు.',
    super.statusCode = 404,
    super.technicalDetails,
  ]);
}

/// 422 / 400 Validation Error
class ValidationException extends AppException {
  final Map<String, dynamic>? errors;

  ValidationException(
    super.message, [
    super.statusCode = 422,
    this.errors,
    super.technicalDetails,
  ]);
}

/// 500+ Server Error
class ServerException extends AppException {
  ServerException([
    super.message = 'సర్వర్ లోపం సంభవించింది. దయచేసి కాసేపటి తర్వాత ప్రయత్నించండి.',
    super.statusCode = 500,
    super.technicalDetails,
  ]);
}

/// JSON deserialization or schema mismatch error
class ParsingException extends AppException {
  ParsingException([
    super.message = 'డేటాను ప్రాసెస్ చేయడంలో లోపం సంభవించింది.',
    super.statusCode,
    super.technicalDetails,
  ]);
}
