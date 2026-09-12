import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../controllers/ugc_controller.dart';
import '../models/reporter_post.dart';
import '../models/ugc_draft.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../state/app_state.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  late final UgcController _controller;
  final _titleController = TextEditingController();
  final _captionController = TextEditingController();
  final _otpController = TextEditingController();

  static const _categories = [
    'Local', 'Sports', 'Politics', 'Weather', 'Accident', 'Community'
  ];

  @override
  void initState() {
    super.initState();
    _controller = UgcController();
    _controller.addListener(_onControllerStateChanged);

    _titleController.addListener(() {
      _controller.setTitle(_titleController.text);
    });
    _captionController.addListener(() {
      _controller.setDescription(_captionController.text);
    });

    // Check for any recoverable pending draft
    _controller.checkForPendingDraft();
  }

  void _onControllerStateChanged() {
    if (!mounted) return;
    setState(() {});

    if (_controller.status == UgcUploadStatus.completed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('News submitted to Admin Queue (Pending)'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _titleController.clear();
      _captionController.clear();
      if (!(ModalRoute.of(context)?.isFirst ?? true)) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<bool> _confirmDiscard() async {
    if (!_controller.hasUnsavedChanges && !_controller.isSubmittingOrUploading) {
      return true;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard post?'),
        content: const Text('Your drafted news will be kept locally so you can resume later. Do you want to leave now?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Leave', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    return discard == true;
  }

  void _onSubmitPressed() {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title for your news.')),
      );
      return;
    }
    if (_captionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a short description of the news.')),
      );
      return;
    }
    if (_controller.type == PostType.image && _controller.selectedImagePaths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please attach at least one photo.')),
      );
      return;
    }
    if (_controller.type == PostType.video && _controller.selectedVideoPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please attach a video.')),
      );
      return;
    }

    if (!AppState.instance.uploadVerified) {
      _showOtpSheet();
      return;
    }

    _controller.submitNews();
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
                  isImage ? 'Attach News Photos' : 'Attach News Video',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
                  ),
                  title: Text(isImage ? 'Take Photo with Camera' : 'Record Video with Camera'),
                  subtitle: Text(
                    isImage ? 'Capture high quality photo' : 'Max 3 minutes duration',
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
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
                    child: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
                  ),
                  title: Text(isImage ? 'Choose from Gallery' : 'Choose Video from Gallery'),
                  subtitle: Text(
                    isImage ? 'Up to 10 photos supported' : 'Max 50MB file size',
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
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

  void _showOtpSheet() async {
    _otpController.clear();
    Timer? sheetTimer;
    
    final phone = AppState.instance.userPhone.isNotEmpty ? AppState.instance.userPhone : '9876543210';
    try {
      await ApiService.instance.sendOtp(phone);
    } catch (_) {
      // Ignored
    }

    if (!mounted) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        int resendSeconds = 24;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            bool sheetSubmitting = false;
            String? sheetError;

            void startTimer() {
              sheetTimer = Timer.periodic(const Duration(seconds: 1), (t) {
                if (resendSeconds > 0) {
                  setSheetState(() => resendSeconds--);
                } else {
                  t.cancel();
                }
              });
            }

            if (sheetTimer == null) {
              startTimer();
            }

            void verifyOtp() async {
              final otpCode = _otpController.text.trim();
              if (otpCode.length < 4 || otpCode.length > 6) {
                setSheetState(() => sheetError = 'Please enter a valid OTP code.');
                return;
              }
              setSheetState(() => sheetSubmitting = true);
              
              try {
                final success = await ApiService.instance.verifyOtp(phone, otpCode);
                setSheetState(() => sheetSubmitting = false);
                
                if (!success) {
                  setSheetState(() => sheetError = 'Incorrect OTP.');
                  return;
                }
                
                AppState.instance.markUploadVerified();
                if (context.mounted) Navigator.pop(context);
                _controller.submitNews();
              } catch (e) {
                setSheetState(() {
                  sheetSubmitting = false;
                  sheetError = 'Verification failed. Try again.';
                });
              }
            }

            final isDark = Theme.of(context).brightness == Brightness.dark;
            final sheetColor = Theme.of(context).cardColor;
            final safeBottom = MediaQuery.of(context).padding.bottom;
            final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
            
            return Padding(
              padding: EdgeInsets.only(bottom: keyboardHeight > 0 ? keyboardHeight : safeBottom),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 26),
                decoration: BoxDecoration(
                  color: sheetColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : const Color(0xFFE1E3E9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      margin: const EdgeInsets.only(bottom: 20),
                    ),
                    const Text(
                      'Verify your mobile to publish',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'One-time check for your first post. After this, you can post news anytime without OTP.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.5),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: isDark ? Colors.white24 : const Color(0xFFE7E9EE), width: 1.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Text('IN +91', style: TextStyle(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w500)),
                          const SizedBox(width: 12),
                          Text(AppState.instance.userPhone.isNotEmpty ? AppState.instance.userPhone : '98xxxxxx21', 
                              style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontSize: 13, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 22, letterSpacing: 12, fontWeight: FontWeight.w700),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: '••••••',
                        filled: true,
                        fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.02),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: isDark ? Colors.white24 : const Color(0xFFE7E9EE), width: 1.5),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: isDark ? Colors.white24 : const Color(0xFFE7E9EE), width: 1.5),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                        ),
                      ),
                    ),
                    if (sheetError != null) ...[
                      const SizedBox(height: 8),
                      Text(sheetError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                    ],
                    const SizedBox(height: 16),
                    Text.rich(
                      TextSpan(
                        text: resendSeconds > 0 ? 'Resend code in ' : 'Didn\'t receive code? ',
                        children: [
                          if (resendSeconds > 0)
                            TextSpan(text: '0:${resendSeconds.toString().padLeft(2, '0')}', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold))
                          else
                            const TextSpan(text: 'Resend', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        onPressed: sheetSubmitting ? null : verifyOtp,
                        child: sheetSubmitting
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Verify & Submit Post', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      sheetTimer?.cancel();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!AppState.instance.isReporter) {
      return _buildReporterOnboarding();
    }
    return _buildUploadForm();
  }

  Widget _buildReporterOnboarding() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.campaign_rounded, size: 64, color: AppColors.primary),
              ),
              const SizedBox(height: 32),
              const Text(
                'Join as a Reporter',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              const Text(
                'Help your community stay informed. Report local news, accidents, and events happening around you.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: AppColors.textMuted, height: 1.5),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.cardDarkSlate : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? Colors.white24 : Colors.black12),
                ),
                child: Column(
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.monetization_on_rounded, color: Colors.amber, size: 24),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Earn points for every approved news report. Redeem them for real cash rewards!',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Divider(color: isDark ? Colors.white12 : Colors.black12),
                    const SizedBox(height: 16),
                    const Row(
                      children: [
                        Icon(Icons.dashboard_customize_rounded, color: AppColors.primary, size: 24),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Track your submissions in the Reporter Dashboard.',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    AppState.instance.registerAsReporter();
                    setState(() {});
                  },
                  child: const Text('Start Reporting', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUploadForm() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasMedia = (_controller.type == PostType.image && _controller.selectedImagePaths.isNotEmpty) || 
                     (_controller.type == PostType.video && _controller.selectedVideoPath != null);
    
    final isSecondaryRoute = !(ModalRoute.of(context)?.isFirst ?? true);
    
    final formScaffold = Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: isSecondaryRoute ? IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isDark ? Colors.white10 : const Color(0xFFF1F2F5),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.chevron_left, size: 20, color: Theme.of(context).iconTheme.color),
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
        ) : null,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Post News', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
            Text('Share what\'s happening around you', style: TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.normal)),
          ],
        ),
        titleSpacing: 0,
        centerTitle: false,
        elevation: 0,
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
                    border: Border.all(color: Colors.amber.shade700.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.restore_page_rounded, color: Colors.amber, size: 24),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'You have an unsaved draft. Restore it?',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          _controller.restorePendingDraft().then((_) {
                            _titleController.text = _controller.title;
                            _captionController.text = _controller.description;
                          });
                        },
                        child: const Text('Restore', style: TextStyle(fontWeight: FontWeight.bold)),
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
                      Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Some attached media files are no longer available on your device. Please re-attach them.',
                          style: TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const Text('POST TYPE',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.5)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _typeCard(
                      icon: '🖼️',
                      label: 'Image News',
                      selected: _controller.type == PostType.image,
                      onTap: () => _controller.setType(PostType.image),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _typeCard(
                      icon: '🎥',
                      label: 'Video News',
                      selected: _controller.type == PostType.video,
                      onTap: () => _controller.setType(PostType.video),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Upload Box
              GestureDetector(
                onTap: _controller.isSubmittingOrUploading ? null : _showMediaPickerSheet,
                child: Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: hasMedia ? Colors.black : (isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFFBFBFC)),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.white24 : const Color(0xFFD6D9E0), 
                      style: hasMedia ? BorderStyle.solid : BorderStyle.none,
                      width: 1.5
                    ),
                    image: hasMedia && _controller.type == PostType.image
                        ? DecorationImage(
                            image: FileImage(File(_controller.selectedImagePaths.first)),
                            fit: BoxFit.cover,
                            colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.3), BlendMode.darken),
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
                                onTap: _controller.isSubmittingOrUploading ? null : _controller.clearMedia,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close, color: Colors.white, size: 14),
                                ),
                              ),
                            ),
                            if (_controller.type == PostType.image)
                              Positioned(
                                bottom: 8,
                                left: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text('${_controller.selectedImagePaths.length} photo(s)', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                                ),
                              ),
                            if (_controller.type == PostType.video)
                               const Center(child: Icon(Icons.play_circle_fill, color: Colors.white, size: 48)),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(_controller.type == PostType.image ? '🖼️' : '🎥', style: const TextStyle(fontSize: 24)),
                            const SizedBox(height: 8),
                            Text(
                              _controller.type == PostType.image ? 'Tap to attach photo (Camera or Gallery)' : 'Tap to attach video (Camera or Gallery)',
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                            ),
                          ],
                        ),
                ),
              ),
              
              // Individual Photo Removal Strip
              if (_controller.type == PostType.image && _controller.selectedImagePaths.length > 1) ...[
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
                              onTap: _controller.isSubmittingOrUploading ? null : () => _controller.removeImageAt(index),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Colors.black87,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, color: Colors.white, size: 12),
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: isDark ? Colors.white24 : const Color(0xFFE7E9EE)),
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
                          : 'Location required (Tap to detect)',
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
                        onTap: () => _controller.ensureLocationAvailable(),
                        child: const Icon(Icons.refresh, size: 14, color: AppColors.primary),
                      ),
                    ],
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              const Text('TITLE',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.5)),
              const SizedBox(height: 10),
              TextField(
                controller: _titleController,
                maxLength: 60,
                enabled: !_controller.isSubmittingOrUploading,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'E.g., Suryapet road repair update',
                  hintStyle: const TextStyle(fontSize: 14, color: AppColors.textMuted, fontWeight: FontWeight.normal),
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: isDark ? Colors.white24 : const Color(0xFFE7E9EE), width: 1.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: isDark ? Colors.white24 : const Color(0xFFE7E9EE), width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              const Text('CATEGORY',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.5)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 10,
                children: _categories.map((cat) {
                  final selected = cat == _controller.category;
                  return GestureDetector(
                    onTap: _controller.isSubmittingOrUploading ? null : () => _controller.setCategory(cat),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.primary : Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: selected ? AppColors.primary : (isDark ? Colors.white24 : const Color(0xFFE7E9EE))),
                      ),
                      child: Text(
                        cat,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: selected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF5C6273)),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              
              const SizedBox(height: 20),
              const Text('DESCRIPTION',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.5)),
              const SizedBox(height: 10),
              TextField(
                controller: _captionController,
                maxLines: 4,
                maxLength: 500,
                enabled: !_controller.isSubmittingOrUploading,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Add full details about the news...',
                  hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: isDark ? Colors.white24 : const Color(0xFFE7E9EE), width: 1.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: isDark ? Colors.white24 : const Color(0xFFE7E9EE), width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
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
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _controller.status == UgcUploadStatus.preparing
                                ? 'Preparing media...'
                                : (_controller.status == UgcUploadStatus.submitting
                                    ? 'Submitting post details...'
                                    : 'Uploading media (${(_controller.uploadProgress * 100).toInt()}%)...'),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary),
                          ),
                          if (_controller.status == UgcUploadStatus.uploading)
                            GestureDetector(
                              onTap: _controller.cancelUpload,
                              child: const Text('Cancel', style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: _controller.status == UgcUploadStatus.uploading ? _controller.uploadProgress : null,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
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
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _controller.errorMessage!,
                          style: const TextStyle(color: Colors.red, fontSize: 12.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 8,
                    shadowColor: AppColors.primary.withValues(alpha: 0.4),
                  ),
                  onPressed: _controller.isSubmittingOrUploading ? null : _onSubmitPressed,
                  child: _controller.isSubmittingOrUploading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(
                          _controller.submissionId != null && _controller.status == UgcUploadStatus.failed
                              ? 'Retry Media Upload'
                              : 'Submit for Review',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
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
        canPop: !_controller.hasUnsavedChanges && !_controller.isSubmittingOrUploading,
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
          color: selected ? AppColors.primary.withValues(alpha: 0.1) : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : (isDark ? Colors.white24 : const Color(0xFFE7E9EE)),
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
                color: selected ? AppColors.primary : (isDark ? Colors.white70 : const Color(0xFF5C6273)),
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
    _controller.dispose();
    _titleController.dispose();
    _captionController.dispose();
    _otpController.dispose();
    super.dispose();
  }
}
