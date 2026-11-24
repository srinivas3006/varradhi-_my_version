import 'dart:io' show HttpDate;

import 'package:dio/dio.dart';

import '../state/app_state.dart';

typedef PollReader = ({
  bool authenticated,
  String? account,
  String? session,
  String device,
  String? secret,
  String? stateId,
  String? districtId,
  String? subdistrictId,
  String? villageId,
  String state,
  String district,
  String subdistrict,
  String village,
});

typedef PollVoter = ({bool authenticated, String? id});

extension PollReaderIdentity on PollReader {
  PollVoter get voter => (
        authenticated: authenticated,
        id: authenticated ? account ?? session : device,
      );
}

PollReader get currentPollReader {
  final app = AppState.instance;
  final place = app.feedPlace;
  return (
    authenticated: app.isLoggedIn,
    account: app.isLoggedIn ? app.userId : null,
    session: app.isLoggedIn ? app.sessionId : null,
    device: app.deviceId,
    secret: app.isLoggedIn ? null : app.installationSecret,
    stateId: app.hasValidLocation ? app.stateId : null,
    districtId: app.hasValidLocation ? app.districtId : null,
    subdistrictId: app.hasValidLocation ? app.subdistrictId : null,
    villageId: app.hasValidLocation ? app.villageId : null,
    state: place.state,
    district: place.district,
    subdistrict: place.subdistrict,
    village: place.village,
  );
}

enum PollProblem {
  duplicate,
  expired,
  unavailable,
  invalidOption,
  eligibility,
  credential,
  unauthorized,
  throttled,
  uncertain,
  invalid,
  readerChanged,
}

class PollFailure implements Exception {
  const PollFailure(this.problem, {this.message, this.retryAfter});
  final PollProblem problem;
  final String? message;
  final Duration? retryAfter;

  factory PollFailure.fromDio(DioException error, PollReader reader) {
    final response = error.response;
    final envelope = response?.data;
    final errors = envelope is Map ? envelope['errors'] : null;
    final details = errors is Map ? errors['details'] : null;
    final message = errors is Map ? errors['message'] : errors;
    final messages = [
      ..._messages(details),
      if (message is String && message.trim().isNotEmpty) message.trim(),
    ];
    final description = [
      ...messages,
      ..._fieldNames(details),
    ].join(' ').toLowerCase().replaceAll('_', ' ');
    final problem = switch (response?.statusCode) {
      _ when error.type == DioExceptionType.cancel => PollProblem.readerChanged,
      401 => PollProblem.unauthorized,
      403
          when description.contains('credential') ||
              description.contains('installation') ||
              description.contains('device identity') =>
        PollProblem.credential,
      403 => PollProblem.eligibility,
      404 => PollProblem.unavailable,
      429 => PollProblem.throttled,
      400
          when description.contains('already') &&
                  (description.contains('vote') ||
                      description.contains('voted')) ||
              description.contains('duplicate') =>
        PollProblem.duplicate,
      400
          when description.contains('expired') ||
              description.contains('ended') ||
              description.contains('closed') =>
        PollProblem.expired,
      400
          when description.contains('inactive') ||
              description.contains('not active') ||
              description.contains('no longer active') ||
              description.contains('poll not found') ||
              description.contains('unavailable') =>
        PollProblem.unavailable,
      400 when description.contains('provide option id or legacy choice') =>
        PollProblem.invalid,
      400
          when description.contains('option') ||
              description.contains('choice') =>
        PollProblem.invalidOption,
      final status when status == null || status >= 500 =>
        PollProblem.uncertain,
      _ => PollProblem.invalid,
    };
    var display = messages.firstOrNull;
    for (final value in [
      reader.secret,
      reader.device,
      AppState.instance.authToken,
      AppState.instance.refreshToken,
    ]) {
      if (value != null && value.isNotEmpty) {
        display = display?.replaceAll(value, '[redacted]');
      }
    }
    return PollFailure(problem,
        message: display,
        retryAfter: problem == PollProblem.throttled
            ? _retryDelay(response?.headers.value('retry-after'))
            : null);
  }

  static Iterable<String> _messages(Object? node) sync* {
    if (node is String && node.trim().isNotEmpty) yield node.trim();
    if (node is Iterable) {
      for (final value in node) {
        yield* _messages(value);
      }
    }
    if (node is Map) {
      for (final entry in node.entries) {
        final key = entry.key.toString().toLowerCase();
        if (key.contains('secret') ||
            key.contains('token') ||
            key.contains('authorization') ||
            key.contains('trace') ||
            key.contains('stack') ||
            key.contains('exception') ||
            key == 'device_id') {
          continue;
        }
        yield* _messages(entry.value);
      }
    }
  }

  static Iterable<String> _fieldNames(Object? node) sync* {
    if (node is Map) {
      for (final entry in node.entries) {
        yield entry.key.toString();
        yield* _fieldNames(entry.value);
      }
    } else if (node is Iterable) {
      for (final entry in node) {
        yield* _fieldNames(entry);
      }
    }
  }

  static Duration _retryDelay(String? header) {
    if (header != null) {
      final seconds = int.tryParse(header.trim());
      if (seconds != null && seconds >= 0) return Duration(seconds: seconds);
      try {
        final delta = HttpDate.parse(header).difference(DateTime.now());
        return delta.isNegative ? Duration.zero : delta;
      } catch (_) {
        // Fall back to a short cooldown when the server omits a valid value.
      }
    }
    return const Duration(minutes: 1);
  }
}
