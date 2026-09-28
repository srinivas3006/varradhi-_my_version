import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/errors/ugc_error.dart';
import '../core/utils/media_picker_helper.dart';
import '../core/utils/media_validator.dart';
import '../models/news_article.dart';
import '../models/submission_status.dart';
import '../repositories/ugc_repository.dart';
import '../services/api_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'create_post_screen.dart';
import 'news_detail_screen.dart';
import 'ugc_phone_verify_screen.dart';

/// Tracks one citizen submission (handover §10). Every decision — status,
/// what the reporter can do next, whether media may be re-uploaded — comes
/// from the backend's status payload; nothing here invents a transition.
class SubmissionStatusScreen extends StatefulWidget {
  const SubmissionStatusScreen({
    super.key,
    required this.submissionId,
    this.initialTitle = '',
    this.statusLoader,
  });

  final String submissionId;
  final String initialTitle;

  /// Test seam; defaults to [ApiService.getSubmissionStatus].
  final Future<SubmissionStatus> Function(String id)? statusLoader;

  @override
  State<SubmissionStatusScreen> createState() => _SubmissionStatusScreenState();
}

class _SubmissionStatusScreenState extends State<SubmissionStatusScreen>
    with WidgetsBindingObserver {
  SubmissionStatus? _status;
  String? _error;
  bool _loading = true;
  bool _uploading = false;
  double _progress = 0;
  Timer? _poll;
  int _pollCount = 0;

  /// Poll every 5s while media processes, for at most ~2 minutes; after that
  /// the reader refreshes by pulling down.
  static const _pollEvery = Duration(seconds: 5);
  static const _maxPolls = 24;

  static bool get _te => AppState.instance.language == 'Telugu';
  static String _t(String te, String en) => _te ? te : en;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    super.dispose();
  }

  /// Handover §6: stop polling while the app is in the background; pick up
  /// with a fresh read when the reader comes back.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final s = _status;
      if (s != null && s.isProcessing && _poll == null) _load(fromPoll: true);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _poll?.cancel();
      _poll = null;
    }
  }

  Future<void> _load({bool fromPoll = false}) async {
    if (!fromPoll) setState(() => _loading = _status == null);
    try {
      final loader =
          widget.statusLoader ?? ApiService.instance.getSubmissionStatus;
      final status = await loader(widget.submissionId);
      if (!mounted) return;
      setState(() {
        _status = status;
        _error = null;
        _loading = false;
      });
      _schedulePoll(status);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = UgcApiError.from(e).message;
        _loading = false;
      });
    }
  }

  void _schedulePoll(SubmissionStatus status) {
    _poll?.cancel();
    _poll = null;
    if (!status.isProcessing || _pollCount >= _maxPolls) return;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle == AppLifecycleState.paused ||
        lifecycle == AppLifecycleState.hidden) {
      return; // resumed() restarts it
    }
    _poll = Timer(_pollEvery, () {
      _poll = null;
      _pollCount++;
      _load(fromPoll: true);
    });
  }

  Future<void> _refresh() async {
    _pollCount = 0;
    await _load();
  }

  // --- next_action handlers -------------------------------------------------

  void _viewInFeed() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => NewsDetailScreen(
        article: NewsArticle.fromJson({
          'id': widget.submissionId,
          'title': _status?.title ?? widget.initialTitle,
          'feed_item_type': 'ugc',
        }),
      ),
    ));
  }

  void _createNew() {
    Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const CreatePostScreen()));
  }

  /// `upload_failed_retry_media`: re-upload to the same submission. Needs
  /// the verified UGC mobile, like every upload call.
  Future<void> _retryMedia() async {
    final status = _status;
    if (status == null || !status.canUploadMedia || _uploading) return;

    if (!AppState.instance.uploadVerified) {
      final mobile = await UgcPhoneVerifyScreen.open(context);
      if (mobile == null || !mounted) return;
    }

    final isVideo = status.contentType == 'VIDEO';
    final picker = MediaPickerHelper();
    final paths = <String>[];
    if (isVideo) {
      final f = await picker.pickVideoFromGallery();
      if (f != null) paths.add(f.path);
    } else {
      final files = await picker.pickPhotosFromGallery(
          maxItems: MediaValidator.maxMediaItems);
      paths.addAll(files.map((f) => f.path));
    }
    if (paths.isEmpty || !mounted) return;

    final validation = isVideo
        ? await MediaValidator.validateVideo(paths.single)
        : await MediaValidator.validateImagesBatch(paths);
    if (!mounted) return;
    if (!validation.isValid) {
      _toast(validation.errorMessage ?? _t('మీడియా చెల్లదు.', 'Invalid media.'));
      return;
    }

    setState(() {
      _uploading = true;
      _progress = 0;
    });
    try {
      await UgcRepository.instance.uploadMediaBatch(
        submissionId: widget.submissionId,
        mobile: AppState.instance.ugcVerifiedMobile,
        filePaths: paths,
        mediaTypes: List.filled(paths.length, isVideo ? 'VIDEO' : 'IMAGE'),
        onSendProgress: (sent, total) {
          if (total > 0 && mounted) setState(() => _progress = sent / total);
        },
      );
      if (!mounted) return;
      _toast(_t('మీడియా అప్‌లోడ్ అయింది. ప్రాసెస్ అవుతోంది…',
          'Media uploaded. Processing…'));
      _pollCount = 0;
      await _load();
    } catch (e) {
      final err = UgcApiError.from(e);
      if (err.invalidatesLocalVerification) {
        await AppState.instance.clearUgcVerification();
      }
      _toast(err.message);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
    ));
  }

  // --- UI --------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_t('వార్త స్థితి', 'Submission status')),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: AppColors.primary,
        child: _body(),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final status = _status;
    if (status == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(32),
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 48, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text(_error ?? _t('స్థితి లోడ్ కాలేదు.', 'Could not load status.'),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Center(
            child: OutlinedButton(
              onPressed: _refresh,
              child: Text(_t('మళ్లీ ప్రయత్నించండి', 'Try again')),
            ),
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        _header(status),
        const SizedBox(height: 16),
        _nextActionCard(status),
        if (status.reviewNote.isNotEmpty) ...[
          const SizedBox(height: 12),
          _noteCard(status.reviewNote),
        ],
        if (status.timeline.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(_t('సమీక్ష చరిత్ర', 'Review history'),
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          for (final e in status.timeline) _timelineRow(e),
        ],
      ],
    );
  }

  Widget _header(SubmissionStatus s) {
    final (label, color) = switch (s.reporterStatus) {
      'published' => (_t('ప్రచురించబడింది', 'Published'), Colors.green),
      'rejected' => (_t('తిరస్కరించబడింది', 'Rejected'), AppColors.primary),
      _ => (_t('సమీక్షలో ఉంది', 'In review'), Colors.amber.shade800),
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 72,
            height: 72,
            child: s.thumbnailUrl.isEmpty
                ? Container(
                    color: AppColors.chipBg,
                    child: const Icon(Icons.article_outlined,
                        color: AppColors.textMuted))
                : CachedNetworkImage(
                    imageUrl: s.thumbnailUrl,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) =>
                        Container(color: AppColors.chipBg),
                  ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.title.isNotEmpty ? s.title : widget.initialTitle,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 6, children: [
                _chip(label, color),
                if (s.uploadStatus.isNotEmpty)
                  _chip(_uploadLabel(s.uploadStatus),
                      s.uploadStatus == 'FAILED'
                          ? AppColors.primary
                          : AppColors.textMuted),
              ]),
            ],
          ),
        ),
      ],
    );
  }

  String _uploadLabel(String u) => switch (u) {
        'READY' => _t('మీడియా సిద్ధం', 'Media ready'),
        'FAILED' => _t('మీడియా విఫలమైంది', 'Media failed'),
        'PROCESSING' => _t('మీడియా ప్రాసెస్ అవుతోంది', 'Media processing'),
        _ => _t('మీడియా వేచి ఉంది', 'Media pending'),
      };

  Widget _chip(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: color)),
      );

  Widget _nextActionCard(SubmissionStatus s) {
    final (IconData icon, String text, Widget? action) = switch (s.nextAction) {
      SubmissionStatus.viewInFeed => (
          Icons.check_circle_outline_rounded,
          _t('మీ వార్త ప్రచురించబడింది.', 'Your story is live.'),
          FilledButton(
            key: const Key('status_view_in_feed'),
            onPressed: _viewInFeed,
            child: Text(_t('వార్తను చూడండి', 'View story')),
          ),
        ),
      SubmissionStatus.createNew => (
          Icons.edit_note_rounded,
          _t('ఈ వార్తను మళ్లీ పంపలేరు. కొత్త వార్త పంపండి.',
              'This story can’t be resubmitted. Send a new one.'),
          FilledButton(
            key: const Key('status_create_new'),
            onPressed: _createNew,
            child: Text(_t('కొత్త వార్త', 'New story')),
          ),
        ),
      SubmissionStatus.retryMedia => (
          Icons.cloud_off_rounded,
          _t('మీడియా అప్‌లోడ్ విఫలమైంది. మళ్లీ అప్‌లోడ్ చేయండి.',
              'Media upload failed. Upload it again.'),
          s.canUploadMedia
              ? FilledButton.icon(
                  key: const Key('status_retry_media'),
                  onPressed: _uploading ? null : _retryMedia,
                  icon: const Icon(Icons.upload_rounded),
                  label: Text(_uploading
                      ? '${(_progress * 100).toInt()}%'
                      : _t('మళ్లీ అప్‌లోడ్', 'Retry upload')),
                )
              : null,
        ),
      SubmissionStatus.waitMedia => (
          Icons.hourglass_top_rounded,
          _pollCount >= _maxPolls
              ? _t('ఇంకా ప్రాసెస్ అవుతోంది. రిఫ్రెష్ చేయడానికి క్రిందికి లాగండి.',
                  'Still processing. Pull down to refresh.')
              : _t('మీడియా ప్రాసెస్ అవుతోంది…', 'Processing your media…'),
          null,
        ),
      SubmissionStatus.waitReview => (
          Icons.fact_check_outlined,
          _t('ఎడిటర్ సమీక్ష కోసం వేచి ఉంది.', 'Waiting for editor review.'),
          null,
        ),
      _ => (Icons.info_outline_rounded, _t('చర్య అవసరం లేదు.', 'Nothing to do right now.'), null),
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
                child: Text(text,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600))),
            if (s.isProcessing && _pollCount < _maxPolls)
              const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2)),
          ]),
          if (action != null) ...[
            const SizedBox(height: 12),
            Align(alignment: Alignment.centerRight, child: action),
          ],
        ],
      ),
    );
  }

  Widget _noteCard(String note) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_t('ఎడిటర్ గమనిక', 'Editor note'),
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(note, style: const TextStyle(fontSize: 13.5, height: 1.4)),
          ],
        ),
      );

  Widget _timelineRow(TimelineEntry e) {
    final when = e.at == null
        ? ''
        : DateFormat('d MMM, h:mm a').format(e.at!.toLocal());
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Icon(Icons.circle, size: 8, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.status.replaceAll('_', ' '),
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700)),
                if (e.note.isNotEmpty)
                  Text(e.note,
                      style: const TextStyle(
                          fontSize: 12.5, color: AppColors.textMuted)),
              ],
            ),
          ),
          Text(when,
              style:
                  const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}
