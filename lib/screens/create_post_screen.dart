import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../core/navigation/auth_guard.dart';
import '../controllers/ugc_controller.dart';
import '../models/reporter_post.dart';
import '../models/ugc_draft.dart';
import '../core/utils/indian_mobile.dart';
import '../theme/app_theme.dart';
import '../state/app_state.dart';
import 'ugc_phone_verify_screen.dart';
import 'submission_status_screen.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  late final UgcController _controller;
  final _titleController = TextEditingController();
  final _captionController = TextEditingController();
  bool _verificationOpen = false;
  UgcUploadStatus _lastStatus = UgcUploadStatus.idle;

  static const _categories = [
    'Local',
    'Sports',
    'Politics',
    'Weather',
    'Accident',
    'Community'
  ];

  static const _categoryLabels = {
    'Local': 'స్థానికం',
    'Sports': 'క్రీడలు',
    'Politics': 'రాజకీయాలు',
    'Weather': 'వాతావరణం',
    'Accident': 'ప్రమాదం',
    'Community': 'సామాజికం',
  };

  @override
  void initState() {
    super.initState();
    _controller = UgcController();
    _controller.addListener(_onControllerStateChanged);
    _gate = _currentGate;
    AppState.instance.addListener(_onAppStateChanged);

    _titleController.addListener(() {
      _controller.setTitle(_titleController.text);
    });
    _captionController.addListener(() {
      _controller.setDescription(_captionController.text);
    });

    // Check for any recoverable pending draft
    _controller.checkForPendingDraft();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || AppState.instance.isLoggedIn) return;
      requireAuth(context, () {
        if (mounted) setState(() {});
      });
    });
  }

  /// Which of the three screens [build] shows: login, join, or the form.
  (bool, bool) get _currentGate => (
        AppState.instance.isLoggedIn,
        AppState.instance.hasJoinedAsReporter,
      );
  late (bool, bool) _gate;

  /// Rebuilds only when that choice changes — e.g. the reporter check on
  /// login finishes after this tab is already open — not on every AppState
  /// notification.
  void _onAppStateChanged() {
    final next = _currentGate;
    if (next == _gate || !mounted) return;
    setState(() => _gate = next);
  }

  void _onControllerStateChanged() {
    if (!mounted) return;
    setState(() {});

    // React to transitions only: the listener also fires on every keystroke.
    final previous = _lastStatus;
    _lastStatus = _controller.status;
    if (previous == _controller.status) return;

    if (_controller.status == UgcUploadStatus.verificationRequired &&
        !_verificationOpen) {
      // Backend rejected the cached mobile (or none is cached): verify, then
      // retry the same submission — the draft and submissionId are kept.
      final notice = _controller.errorMessage;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _verifyThenSubmit(notice: notice);
      });
      return;
    }

    if (_controller.status == UgcUploadStatus.completed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('వార్త అడ్మిన్ క్యూకు పంపబడింది (పెండింగ్)'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      final submissionId = _controller.lastCompletedSubmissionId;
      final title = _titleController.text.trim();
      _titleController.clear();
      _captionController.clear();
      // Media processes asynchronously (handover §9): open the status screen,
      // which polls until upload_status is READY or FAILED.
      if (submissionId != null && submissionId.isNotEmpty) {
        final route = MaterialPageRoute(
          builder: (_) => SubmissionStatusScreen(
              submissionId: submissionId, initialTitle: title),
        );
        if (!(ModalRoute.of(context)?.isFirst ?? true)) {
          Navigator.of(context).pushReplacement(route);
        } else {
          Navigator.of(context).push(route);
        }
      } else if (!(ModalRoute.of(context)?.isFirst ?? true)) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<bool> _confirmDiscard() async {
    if (!_controller.hasUnsavedChanges &&
        !_controller.isSubmittingOrUploading) {
      return true;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('వార్తను రద్దు చేయాలా?'),
        content: const Text(
            'మీరు రాసిన డ్రాఫ్ట్ భద్రపరచబడుతుంది, తర్వాత పూర్తి చేయవచ్చు. ఇప్పుడు నిష్క్రమించాలనుకుంటున్నారా?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('సవరణ కొనసాగించు'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child:
                const Text('నిష్క్రమించు', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    return discard == true;
  }

  void _onSubmitPressed() {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('దయచేసి వార్తకు శీర్షికను నమోదు చేయండి.')),
      );
      return;
    }
    if (_captionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('వార్తకు సంబంధించిన సంక్షిప్త వివరణను జోడించండి.')),
      );
      return;
    }
    if (_controller.type == PostType.image &&
        _controller.selectedImagePaths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('దయచేసి కనీసం ఒక ఫోటోను జతచేయండి.')),
      );
      return;
    }
    if (_controller.type == PostType.video &&
        _controller.selectedVideoPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('దయచేసి వీడియోను జతచేయండి.')),
      );
      return;
    }

    _verifyThenSubmit();
  }

  /// Local cache says unverified → verify first. The backend still has the
  /// final word: if submit answers "Mobile number is not verified." the
  /// controller flips to [UgcUploadStatus.verificationRequired] and
  /// [_onControllerStateChanged] reopens verification and retries.
  Future<void> _verifyThenSubmit({String? notice}) async {
    if (!AppState.instance.uploadVerified) {
      final verified = await _openVerification(notice: notice);
      if (verified == null || !mounted) return;
    }
    if (!mounted) return;
    await _controller.submitNews(context);
  }

  Future<String?> _openVerification({String? notice}) async {
    if (_verificationOpen) return null;
    _verificationOpen = true;
    try {
      return await UgcPhoneVerifyScreen.open(context, notice: notice);
    } finally {
      _verificationOpen = false;
    }
  }

  void _showMediaPickerSheet() {
    final isImage = _controller.type == PostType.image;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  margin: const EdgeInsets.only(bottom: 16),
                ),
                Text(
                  isImage
                      ? 'వార్తా ఫోటోలను జతచేయండి'
                      : 'వార్తా వీడియోను జతచేయండి',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt_rounded,
                        color: AppColors.primary),
                  ),
                  title: Text(isImage
                      ? 'కెమెరాతో ఫోటో తీయండి'
                      : 'కెమెరాతో వీడియో రికార్డ్ చేయండి'),
                  subtitle: Text(
                    isImage
                        ? 'స్పష్టమైన ఫోటో తీయండి'
                        : 'గరిష్టంగా 3 నిమిషాల నిడివి',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textMuted),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    if (isImage) {
                      _controller.pickPhotoFromCamera();
                    } else {
                      _controller.recordVideoFromCamera();
                    }
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.photo_library_rounded,
                        color: AppColors.primary),
                  ),
                  title: Text(isImage
                      ? 'గ్యాలరీ నుండి ఫోటో ఎంచుకోండి'
                      : 'గ్యాలరీ నుండి వీడియో ఎంచుకోండి'),
                  subtitle: Text(
                    isImage
                        ? 'గరిష్టంగా 10 ఫోటోలు'
                        : 'గరిష్టంగా 50MB ఫైల్ పరిమాణం',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textMuted),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    if (isImage) {
                      _controller.pickPhotosFromGallery();
                    } else {
                      _controller.pickVideoFromGallery();
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!AppState.instance.isLoggedIn) {
      return _buildLoginRequired();
    }
    if (!AppState.instance.hasJoinedAsReporter) {
      return _buildReporterOnboarding();
    }
    return _buildUploadForm();
  }

  /// True when this screen was pushed as a route. As the Post tab it is
  /// part of Home, and a close button there would pop Home itself.
  bool get _isSecondaryRoute => !(ModalRoute.of(context)?.isFirst ?? true);

  /// Shown only when there is a route to close.
  AppBar _plainAppBar() => AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
        leading: _isSecondaryRoute
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.maybePop(context),
              )
            : null,
      );

  Widget _buildLoginRequired() {
    final telugu = AppState.instance.language == 'Telugu';
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _plainAppBar(),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.edit_note_rounded,
                      size: 52, color: AppColors.primary),
                ),
                const SizedBox(height: 24),
                Text(
                  telugu ? 'వార్త పోస్ట్ చేయడానికి లాగిన్ అవ్వండి' : 'Log in to post news',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800, height: 1.3),
                ),
                const SizedBox(height: 10),
                Text(
                  telugu
                      ? 'మీ గ్రామం, మండలంలో జరుగుతున్న వార్తలను అందరితో పంచుకోండి.'
                      : 'Share what is happening in your village and mandal.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 14.5, color: AppColors.textMuted, height: 1.5),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => requireAuth(context, () {
                      if (mounted) setState(() {});
                    }),
                    icon: const Icon(Icons.login_rounded, size: 20),
                    label: Text(telugu ? 'లాగిన్' : 'Log in',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Which mobile the post will be sent under. Read-only: the UGC mobile is
  /// bound once per account and the backend has no change-mobile flow.
  Widget _buildVerifiedMobileRow() {
    final verified = AppState.instance.uploadVerified;
    final color = verified ? Colors.green.shade700 : AppColors.textMuted;
    return Row(
      children: [
        Icon(verified ? Icons.verified_rounded : Icons.phone_android_rounded,
            size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            verified
                ? 'ధృవీకరించిన మొబైల్: +91 ${IndianMobile.format(AppState.instance.ugcVerifiedMobile)}'
                : 'మొదటి పోస్ట్‌కు ముందు ఒకసారి మొబైల్ ధృవీకరణ అవసరం',
            style: TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w600, color: color),
          ),
        ),
      ],
    );
  }

  Widget _buildReporterOnboarding() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _plainAppBar(),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.campaign_rounded,
                    size: 64, color: AppColors.primary),
              ),
              const SizedBox(height: 32),
              const Text(
                'రిపోర్టర్‌గా చేరండి',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              const Text(
                'మీ చుట్టూ జరుగుతున్న స్థానిక వార్తలు, సంఘటనలు మరియు విశేషాలను అందించి సమాజానికి తోడ్పడండి.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 15, color: AppColors.textMuted, height: 1.5),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color:
                      isDark ? AppColors.cardDarkSlate : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: isDark ? Colors.white24 : Colors.black12),
                ),
                child: Column(
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.monetization_on_rounded,
                            color: Colors.amber, size: 24),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'ఆమోదించబడిన ప్రతి వార్తకు పాయింట్లు సంపాదించండి. వాటిని నగదుగా విత్‌డ్రా చేసుకోండి!',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Divider(color: isDark ? Colors.white12 : Colors.black12),
                    const SizedBox(height: 16),
                    const Row(
                      children: [
                        Icon(Icons.dashboard_customize_rounded,
                            color: AppColors.primary, size: 24),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'మీ వార్తల స్థితిని రిపోర్టర్ డ్యాష్‌బోర్డ్‌లో ట్రాక్ చేయండి.',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    AppState.instance.registerAsReporter();
                    setState(() {});
                  },
                  child: const Text('రిపోర్టింగ్‌ను ప్రారంభించండి',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
          ),
        ),
      ),
    );
  }

  Widget _buildUploadForm() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasMedia = (_controller.type == PostType.image &&
            _controller.selectedImagePaths.isNotEmpty) ||
        (_controller.type == PostType.video &&
            _controller.selectedVideoPath != null);

    final isSecondaryRoute = !(ModalRoute.of(context)?.isFirst ?? true);

    final formScaffold = Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: isSecondaryRoute
            ? IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : const Color(0xFFF1F2F5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.chevron_left,
                      size: 20, color: Theme.of(context).iconTheme.color),
                ),
                onPressed: () async {
                  if (_controller.hasUnsavedChanges) {
                    final shouldDiscard = await _confirmDiscard();
                    if (shouldDiscard && mounted) {
                      Navigator.pop(context);
                    }
                  } else {
                    Navigator.pop(context);
                  }
                },
              )
            : null,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('వార్తను పోస్ట్ చేయండి',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
            Text('మీ ప్రాంతంలో జరుగుతున్న విశేషాలను పంచుకోండి',
                style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.normal)),
          ],
        ),
        // As a tab there is no back button, and 0 left the title touching
        // the screen edge; line it up with the form's 20px gutter instead.
        titleSpacing: isSecondaryRoute ? 0 : 20,
        centerTitle: false,
        elevation: 0,
        // A hairline once the form scrolls under the header, so cards do
        // not look cut off against a same-colour bar.
        scrolledUnderElevation: 0.6,
        shadowColor: isDark ? Colors.black : Colors.black26,
        surfaceTintColor: Colors.transparent,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pending Draft Recovery Banner
              if (_controller.pendingDraft != null) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.amber.shade700.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.restore_page_rounded,
                          color: Colors.amber, size: 24),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'మీ వద్ద సేవ్ చేయని డ్రాఫ్ట్ ఉంది. దాన్ని పునరుద్ధరించాలా?',
                          style: TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          _controller.restorePendingDraft().then((_) {
                            _titleController.text = _controller.title;
                            _captionController.text = _controller.description;
                          });
                        },
                        child: const Text('పునరుద్ధరించు',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: _controller.dismissPendingDraft,
                      ),
                    ],
                  ),
                ),
              ],

              // Missing Local Files Warning
              if (_controller.missingFilesWarning.isNotEmpty) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.shade400),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: Colors.orange, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'జతచేసిన కొన్ని మీడియా ఫైళ్లు మీ పరికరంలో అందుబాటులో లేవు. దయచేసి వాటిని మళ్లీ జతచేయండి.',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const Text('వార్తా రకం',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      letterSpacing: 0.5)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _typeCard(
                      icon: '🖼️',
                      label: 'ఫోటో వార్త',
                      selected: _controller.type == PostType.image,
                      onTap: () => _controller.setType(PostType.image),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _typeCard(
                      icon: '🎥',
                      label: 'వీడియో వార్త',
                      selected: _controller.type == PostType.video,
                      onTap: () => _controller.setType(PostType.video),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Upload Box
              GestureDetector(
                onTap: _controller.isSubmittingOrUploading
                    ? null
                    : _showMediaPickerSheet,
                child: Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: hasMedia
                        ? Colors.black
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : const Color(0xFFFBFBFC)),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color:
                            isDark ? Colors.white24 : const Color(0xFFD6D9E0),
                        style: hasMedia ? BorderStyle.solid : BorderStyle.none,
                        width: 1.5),
                    image: hasMedia && _controller.type == PostType.image
                        ? DecorationImage(
                            image: FileImage(
                                File(_controller.selectedImagePaths.first)),
                            fit: BoxFit.cover,
                            colorFilter: ColorFilter.mode(
                                Colors.black.withValues(alpha: 0.3),
                                BlendMode.darken),
                          )
                        : null,
                  ),
                  child: hasMedia
                      ? Stack(
                          children: [
                            Positioned(
                              top: 8,
                              right: 8,
                              child: GestureDetector(
                                onTap: _controller.isSubmittingOrUploading
                                    ? null
                                    : _controller.clearMedia,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close,
                                      color: Colors.white, size: 14),
                                ),
                              ),
                            ),
                            if (_controller.type == PostType.image)
                              Positioned(
                                bottom: 8,
                                left: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                      '${_controller.selectedImagePaths.length} ఫోటో(లు)',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600)),
                                ),
                              ),
                            if (_controller.type == PostType.video)
                              const Center(
                                  child: Icon(Icons.play_circle_fill,
                                      color: Colors.white, size: 48)),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                                _controller.type == PostType.image
                                    ? '🖼️'
                                    : '🎥',
                                style: const TextStyle(fontSize: 24)),
                            const SizedBox(height: 8),
                            Text(
                              _controller.type == PostType.image
                                  ? 'ఫోటో జతచేయడానికి నొక్కండి (కెమెరా లేదా గ్యాలరీ)'
                                  : 'వీడియో జతచేయడానికి నొక్కండి (కెమెరా లేదా గ్యాలరీ)',
                              style: const TextStyle(
                                  color: AppColors.textMuted, fontSize: 12),
                            ),
                          ],
                        ),
                ),
              ),

              // Individual Photo Removal Strip
              if (_controller.type == PostType.image &&
                  _controller.selectedImagePaths.length > 1) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 64,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _controller.selectedImagePaths.length,
                    itemBuilder: (context, index) {
                      return Stack(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File(_controller.selectedImagePaths[index]),
                                width: 64,
                                height: 64,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 2,
                            right: 12,
                            child: GestureDetector(
                              onTap: _controller.isSubmittingOrUploading
                                  ? null
                                  : () => _controller.removeImageAt(index),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Colors.black87,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close,
                                    color: Colors.white, size: 12),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],

              const SizedBox(height: 14),
              // Location Display / Selection Requirement
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(
                      color: isDark ? Colors.white24 : const Color(0xFFE7E9EE)),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('📍', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 6),
                    Text(
                      AppState.instance.hasValidLocation
                          ? '${AppState.instance.district}, ${AppState.instance.stateName}'
                          : 'లొకేషన్ అవసరం (గుర్తించడానికి నొక్కండి)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppState.instance.hasValidLocation
                            ? Theme.of(context).textTheme.bodyLarge?.color
                            : Colors.orange,
                      ),
                    ),
                    if (!AppState.instance.hasValidLocation) ...[
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () =>
                            _controller.ensureLocationAvailable(context),
                        child: const Icon(Icons.refresh,
                            size: 14, color: AppColors.primary),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 20),
              const Text('శీర్షిక',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      letterSpacing: 0.5)),
              const SizedBox(height: 10),
              TextField(
                controller: _titleController,
                maxLength: 60,
                enabled: !_controller.isSubmittingOrUploading,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'ఉదా: సూర్యాపేట రోడ్డు మరమ్మతుల సమాచారం',
                  hintStyle: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.normal),
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                        color:
                            isDark ? Colors.white24 : const Color(0xFFE7E9EE),
                        width: 1.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                        color:
                            isDark ? Colors.white24 : const Color(0xFFE7E9EE),
                        width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              const Text('వర్గం',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      letterSpacing: 0.5)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 10,
                children: _categories.map((cat) {
                  final selected = cat == _controller.category;
                  return GestureDetector(
                    onTap: _controller.isSubmittingOrUploading
                        ? null
                        : () => _controller.setCategory(cat),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primary
                            : Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: selected
                                ? AppColors.primary
                                : (isDark
                                    ? Colors.white24
                                    : const Color(0xFFE7E9EE))),
                      ),
                      child: Text(
                        _categoryLabels[cat] ?? cat,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: selected
                              ? Colors.white
                              : (isDark
                                  ? Colors.white70
                                  : const Color(0xFF5C6273)),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),
              const Text('వివరణ',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      letterSpacing: 0.5)),
              const SizedBox(height: 10),
              TextField(
                controller: _captionController,
                maxLines: 4,
                maxLength: 500,
                enabled: !_controller.isSubmittingOrUploading,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'వార్తకు సంబంధించిన పూర్తి వివరాలను రాయండి...',
                  hintStyle:
                      const TextStyle(fontSize: 13, color: AppColors.textMuted),
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                        color:
                            isDark ? Colors.white24 : const Color(0xFFE7E9EE),
                        width: 1.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                        color:
                            isDark ? Colors.white24 : const Color(0xFFE7E9EE),
                        width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                ),
              ),

              // Progress Bar & State Display
              if (_controller.isSubmittingOrUploading) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _controller.status == UgcUploadStatus.preparing
                                ? 'మీడియా సిద్ధం చేయబడుతోంది...'
                                : (_controller.status ==
                                        UgcUploadStatus.submitting
                                    ? 'వార్త వివరాలు సమర్పించబడుతున్నాయి...'
                                    : 'మీడియా అప్‌లోడ్ అవుతోంది (${(_controller.uploadProgress * 100).toInt()}%)...'),
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary),
                          ),
                          if (_controller.status == UgcUploadStatus.uploading)
                            GestureDetector(
                              onTap: _controller.cancelUpload,
                              child: const Text('రద్దు చేయి',
                                  style: TextStyle(
                                      color: Colors.red,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: _controller.status == UgcUploadStatus.uploading
                            ? _controller.uploadProgress
                            : null,
                        backgroundColor:
                            AppColors.primary.withValues(alpha: 0.2),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.primary),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
                ),
              ],

              if (_controller.errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _controller.errorMessage!,
                          style: const TextStyle(
                              color: Colors.red, fontSize: 12.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),
              _buildVerifiedMobileRow(),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        AppColors.primary.withValues(alpha: 0.4),
                    disabledForegroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 8,
                    shadowColor: AppColors.primary.withValues(alpha: 0.4),
                  ),
                  onPressed: _controller.isSubmittingOrUploading ||
                          _controller.isUploadRestricted
                      ? null
                      : _onSubmitPressed,
                  child: _controller.isSubmittingOrUploading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Text(
                          AppState.instance.isUgcUploaderBlocked
                              ? 'అప్‌లోడ్ నిలిపివేయబడింది'
                              : AppState.instance.isUgcDailyLimitActive
                                  ? 'రేపు మళ్లీ పోస్ట్ చేయండి'
                                  : _controller.submissionId != null &&
                                          _controller.status ==
                                              UgcUploadStatus.failed
                                      ? 'మీడియా అప్‌లోడ్ మళ్లీ ప్రయత్నించండి'
                                      : AppState.instance.uploadVerified
                                          ? 'సమీక్ష కోసం సమర్పించండి'
                                          : 'మొబైల్ ధృవీకరించి సమర్పించండి',
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );

    if (isSecondaryRoute) {
      return PopScope(
        canPop: !_controller.hasUnsavedChanges &&
            !_controller.isSubmittingOrUploading,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          final shouldDiscard = await _confirmDiscard();
          if (shouldDiscard && mounted) {
            Navigator.of(context).pop();
          }
        },
        child: formScaffold,
      );
    }

    return formScaffold;
  }

  Widget _typeCard({
    required String icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.1)
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : (isDark ? Colors.white24 : const Color(0xFFE7E9EE)),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected
                    ? AppColors.primary
                    : (isDark ? Colors.white70 : const Color(0xFF5C6273)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerStateChanged);
    AppState.instance.removeListener(_onAppStateChanged);
    _controller.dispose();
    _titleController.dispose();
    _captionController.dispose();
    super.dispose();
  }
}
