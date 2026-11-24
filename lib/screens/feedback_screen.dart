import 'dart:async';
import 'dart:io' show HttpDate;

import 'package:flutter/material.dart';

import '../services/feedback_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({
    super.key,
    this.content,
    this.initialType = FeedbackType.general,
    this.service,
  });

  final FeedbackContentReference? content;
  final FeedbackType initialType;
  final FeedbackService? service;

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _message = TextEditingController();
  late final FeedbackService _service;
  late FeedbackType _type;
  Map<String, dynamic> _fieldErrors = {};
  String? _errorMessage;
  String? _submissionId;
  bool _isSubmitting = false;
  bool _submitted = false;
  int _retrySeconds = 0;
  Timer? _retryTimer;

  bool get _isTelugu => AppState.instance.language == 'Telugu';

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? FeedbackService.instance;
    _type = widget.initialType;
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  String _text(String english, String telugu) => _isTelugu ? telugu : english;

  String? _fieldError(String field) {
    final value = _fieldErrors[field];
    if (value == null) return null;
    if (value is List) {
      return value.map((item) => item.toString()).join('\n');
    }
    return value.toString();
  }

  void _clearFieldError(String field) {
    if (!_fieldErrors.containsKey(field) && _errorMessage == null) return;
    setState(() {
      _fieldErrors.remove(field);
      _errorMessage = null;
    });
  }

  Future<void> _submit() async {
    if (_isSubmitting || _retrySeconds > 0) return;
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _fieldErrors = {};
    });
    try {
      final result = await _service.submit(FeedbackDraft(
        type: _type,
        subject: _subject.text,
        message: _message.text,
        content: widget.content,
      ));
      if (!mounted) return;
      _subject.clear();
      _message.clear();
      setState(() {
        _isSubmitting = false;
        _submitted = true;
        _submissionId = result.id;
      });
    } on FeedbackApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _fieldErrors = error.fieldErrors;
        _errorMessage = error.fieldErrors.isEmpty
            ? _errorForStatus(error)
            : _unmappedFieldErrors(error.fieldErrors).isEmpty
                ? null
                : _unmappedFieldErrors(error.fieldErrors);
      });
      if (error.statusCode == 429) _startRetryDelay(error.retryAfter);
    } catch (error) {
      if (!mounted) return;
      debugPrint('[FeedbackScreen] Feedback submission failed: $error');
      setState(() {
        _isSubmitting = false;
        _errorMessage = _text(
          'Could not submit feedback. Check your connection and try again.',
          'అభిప్రాయాన్ని పంపలేకపోయాము. ఇంటర్నెట్‌ను తనిఖీ చేసి మళ్లీ ప్రయత్నించండి.',
        );
      });
    }
  }

  String _errorForStatus(FeedbackApiException error) {
    if (error.statusCode == 401) {
      return _text(
        'Your session expired. Please sign in and retry.',
        'మీ సెషన్ ముగిసింది. సైన్ ఇన్ చేసి మళ్లీ ప్రయత్నించండి.',
      );
    }
    if (error.statusCode == 403) return error.message;
    if (error.statusCode == 429) return error.message;
    if ((error.statusCode ?? 0) >= 500) return error.message;
    return error.message;
  }

  String _unmappedFieldErrors(Map<String, dynamic> errors) {
    final visibleFields = {'type', 'subject', 'message'};
    final values = <String>[];
    for (final entry in errors.entries) {
      if (visibleFields.contains(entry.key)) continue;
      final value = entry.value;
      if (value is List) {
        values.addAll(value.map((item) => item.toString()));
      } else {
        values.add(value.toString());
      }
    }
    return values.join('\n');
  }

  void _startRetryDelay(String? value) {
    final parsed = int.tryParse(value?.trim() ?? '');
    DateTime? retryDate;
    if (parsed == null && value != null) {
      try {
        retryDate = HttpDate.parse(value);
      } on FormatException {
        retryDate = DateTime.tryParse(value);
      }
    }
    final seconds = parsed ??
        (retryDate == null
            ? 0
            : retryDate.difference(DateTime.now()).inSeconds);
    if (seconds <= 0) return;
    _retryTimer?.cancel();
    setState(() => _retrySeconds = seconds);
    _retryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _retrySeconds--;
        if (_retrySeconds <= 0) {
          _retrySeconds = 0;
          timer.cancel();
        }
      });
    });
  }

  void _startNewSubmission() {
    setState(() {
      _submitted = false;
      _submissionId = null;
      _errorMessage = null;
      _fieldErrors = {};
      _type = widget.initialType;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_text('Feedback', 'అభిప్రాయం')),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (_submitted) ...[
              _messageCard(
                color: Colors.green,
                icon: Icons.check_circle_outline_rounded,
                message: _text(
                  'Thank you. Your feedback has been submitted.',
                  'ధన్యవాదాలు. మీ అభిప్రాయం సమర్పించబడింది.',
                ),
              ),
              if (_submissionId?.isNotEmpty ?? false) ...[
                const SizedBox(height: 8),
                Text(
                  '${_text('Reference', 'సూచన')}  $_submissionId',
                  key: const Key('feedback_submission_reference'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: const Key('feedback_new_submission'),
                  onPressed: _startNewSubmission,
                  child: Text(_text('Send another', 'మరొకటి పంపండి')),
                ),
              ),
            ],
            if (_errorMessage != null) ...[
              _messageCard(
                color: AppColors.error,
                icon: Icons.error_outline_rounded,
                message: _errorMessage!,
              ),
              const SizedBox(height: 16),
            ],
            if (_retrySeconds > 0) ...[
              _messageCard(
                color: AppColors.primary,
                icon: Icons.hourglass_bottom_rounded,
                message: _text(
                  'Please wait $_retrySeconds seconds before retrying.',
                  'మళ్లీ ప్రయత్నించే ముందు $_retrySeconds సెకన్లు వేచి ఉండండి.',
                ),
              ),
              const SizedBox(height: 16),
            ],
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<FeedbackType>(
                    key: const Key('feedback_type'),
                    initialValue: _type,
                    decoration: InputDecoration(
                      labelText: _text('Feedback type', 'అభిప్రాయం రకం'),
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      for (final type in FeedbackType.values)
                        DropdownMenuItem(
                          value: type,
                          child: Text(type.label),
                        ),
                    ],
                    onChanged: _isSubmitting
                        ? null
                        : (value) {
                            if (value == null) return;
                            setState(() {
                              _type = value;
                              _fieldErrors.remove('type');
                              _errorMessage = null;
                            });
                          },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('feedback_subject'),
                    controller: _subject,
                    maxLength: 200,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: _text('Subject', 'విషయం'),
                      border: const OutlineInputBorder(),
                      errorText: _fieldError('subject'),
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) {
                        return _text(
                          'This field may not be blank.',
                          'ఈ ఫీల్డ్ ఖాళీగా ఉండకూడదు.',
                        );
                      }
                      if (text.length > 200) {
                        return _text(
                          'Use no more than 200 characters.',
                          '200 అక్షరాలకు మించకూడదు.',
                        );
                      }
                      return null;
                    },
                    onChanged: (_) => _clearFieldError('subject'),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    key: const Key('feedback_message'),
                    controller: _message,
                    minLines: 5,
                    maxLines: 8,
                    maxLength: 2000,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: _text('Message', 'సందేశం'),
                      alignLabelWithHint: true,
                      border: const OutlineInputBorder(),
                      errorText: _fieldError('message'),
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) {
                        return _text(
                          'This field may not be blank.',
                          'ఈ ఫీల్డ్ ఖాళీగా ఉండకూడదు.',
                        );
                      }
                      if (text.length > 2000) {
                        return _text(
                          'Use no more than 2,000 characters.',
                          '2,000 అక్షరాలకు మించకూడదు.',
                        );
                      }
                      return null;
                    },
                    onChanged: (_) => _clearFieldError('message'),
                  ),
                  if (_fieldError('type') != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _fieldError('type')!,
                      style: TextStyle(color: colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      key: const Key('feedback_submit'),
                      onPressed:
                          _isSubmitting || _retrySeconds > 0 ? null : _submit,
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(_retrySeconds > 0
                              ? _text('Please wait', 'వేచి ఉండండి')
                              : _text('Submit feedback', 'పంపండి')),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _messageCard({
    required Color color,
    required IconData icon,
    required String message,
  }) {
    return Container(
      key: Key(color == Colors.green ? 'feedback_success' : 'feedback_error'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}
