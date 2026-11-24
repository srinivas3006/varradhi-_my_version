import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../core/network/dio_client.dart';

enum FeedbackType {
  general('general', 'General'),
  bug('bug', 'Bug'),
  suggestion('suggestion', 'Suggestion'),
  contentReport('content_report', 'Content report'),
  adReport('ad_report', 'Advertisement report'),
  account('account', 'Account');

  const FeedbackType(this.value, this.label);

  final String value;
  final String label;
}

enum FeedbackContentType {
  article('article'),
  ugc('ugc'),
  ad('ad'),
  poster('poster'),
  quote('quote'),
  poll('poll'),
  video('video');

  const FeedbackContentType(this.value);

  final String value;
}

class FeedbackContentReference {
  const FeedbackContentReference({
    required this.type,
    required this.id,
  });

  static final RegExp _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );

  final FeedbackContentType type;
  final String id;

  bool get isValid => _uuid.hasMatch(id);
}

class FeedbackDraft {
  const FeedbackDraft({
    this.type = FeedbackType.general,
    required this.subject,
    required this.message,
    this.content,
  });

  final FeedbackType type;
  final String subject;
  final String message;
  final FeedbackContentReference? content;

  Map<String, List<String>> validate() {
    final errors = <String, List<String>>{};
    void add(String field, String message) =>
        errors.putIfAbsent(field, () => <String>[]).add(message);

    final normalizedSubject = subject.trim();
    final normalizedMessage = message.trim();
    if (normalizedSubject.isEmpty) {
      add('subject', 'This field may not be blank.');
    } else if (normalizedSubject.length > 200) {
      add('subject', 'Ensure this field has no more than 200 characters.');
    }
    if (normalizedMessage.isEmpty) {
      add('message', 'This field may not be blank.');
    } else if (normalizedMessage.length > 2000) {
      add('message', 'Ensure this field has no more than 2000 characters.');
    }
    if (type == FeedbackType.contentReport) {
      final reference = content;
      if (reference == null) {
        add('content_type', 'Choose the content to report.');
        add('content_id', 'The content identifier is missing.');
      } else if (!reference.isValid) {
        add('content_id', 'The content identifier is invalid.');
      }
    }
    return errors;
  }
}

class FeedbackSubmission {
  const FeedbackSubmission({this.id});

  final String? id;
}

class FeedbackApiException implements Exception {
  const FeedbackApiException({
    required this.message,
    this.statusCode,
    this.fieldErrors = const {},
    this.retryAfter,
  });

  final String message;
  final int? statusCode;
  final Map<String, dynamic> fieldErrors;
  final String? retryAfter;

  factory FeedbackApiException.fromDio(DioException exception) {
    final response = exception.response;
    final body = response?.data;
    final errorObject =
        body is Map && body['errors'] is Map ? body['errors'] as Map : null;
    final rawDetails = errorObject != null && errorObject['details'] is Map
        ? errorObject['details'] as Map
        : const <Object?, Object?>{};
    final details = <String, dynamic>{
      for (final entry in rawDetails.entries)
        if (entry.key != null) entry.key.toString(): entry.value,
    };
    final message = errorObject?['message']?.toString() ??
        errorObject?['detail']?.toString() ??
        (body is Map
            ? (body['detail'] ?? body['message'])?.toString()
            : null) ??
        exception.message ??
        'Unable to submit feedback.';

    return FeedbackApiException(
      message: message,
      statusCode: response?.statusCode,
      fieldErrors: details,
      retryAfter: response?.headers.value('retry-after'),
    );
  }

  @override
  String toString() => message;
}

class FeedbackService {
  FeedbackService({
    Dio? dio,
    Future<String> Function()? appVersionProvider,
  })  : _dio = dio ?? ApiClient.instance.dio,
        _appVersionProvider = appVersionProvider ?? _installedAppVersion;

  static final FeedbackService instance = FeedbackService();

  final Dio _dio;
  final Future<String> Function() _appVersionProvider;

  static Future<String> _installedAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    final version = info.version.trim();
    final buildNumber = info.buildNumber.trim();
    final installedVersion =
        buildNumber.isEmpty ? version : '$version+$buildNumber';
    if (installedVersion.isEmpty) {
      throw const FeedbackApiException(
        message: 'The installed app version could not be determined.',
      );
    }
    if (installedVersion.length > 50) {
      throw const FeedbackApiException(
        message: 'The installed app version is longer than supported.',
      );
    }
    return installedVersion;
  }

  Future<FeedbackSubmission> submit(FeedbackDraft draft) async {
    final validationErrors = draft.validate();
    if (validationErrors.isNotEmpty) {
      throw FeedbackApiException(
        message: 'Please correct the highlighted fields.',
        statusCode: 400,
        fieldErrors: validationErrors,
      );
    }

    final appVersion = await _appVersionProvider();
    final payload = <String, dynamic>{
      'type': draft.type.value,
      'subject': draft.subject.trim(),
      'message': draft.message.trim(),
      'app_version': appVersion,
      if (draft.type == FeedbackType.contentReport) ...{
        'content_type': draft.content!.type.value,
        'content_id': draft.content!.id,
      },
    };

    try {
      final response = await _dio.post<dynamic>(
        '/api/v1/feedback/',
        data: payload,
        options: Options(contentType: Headers.jsonContentType),
      );
      if (response.statusCode != 201) {
        throw FeedbackApiException(
          message: 'The server did not confirm feedback submission.',
          statusCode: response.statusCode,
        );
      }
      final body = response.data;
      final data =
          body is Map && body['data'] is Map ? body['data'] as Map : null;
      final id = data?['id']?.toString();
      return FeedbackSubmission(id: id == null || id.isEmpty ? null : id);
    } on DioException catch (exception) {
      throw FeedbackApiException.fromDio(exception);
    }
  }
}
