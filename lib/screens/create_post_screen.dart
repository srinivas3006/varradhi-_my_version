import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/reporter_post.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../state/app_state.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  PostType _type = PostType.image;
  String _category = 'Local';
  final _titleController = TextEditingController();
  final _captionController = TextEditingController();
  final _otpController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  bool _submitting = false;
  bool _isPicking = false;
  String? _error;
  
  List<XFile> _selectedImages = [];
  XFile? _selectedVideo;

  static const _categories = [
    'Local', 'Sports', 'Politics', 'Weather', 'Accident', 'Community'
  ];

  @override
  void initState() {
    super.initState();
    _titleController.addListener(() => setState(() {}));
    _captionController.addListener(() => setState(() {}));
  }

  void _onSubmitPressed() {
    if (_titleController.text.trim().isEmpty) {
      setState(() => _error = 'Please enter a title for your news.');
      return;
    }
    if (_captionController.text.trim().isEmpty) {
      setState(() => _error = 'Add a short description of the news.');
      return;
    }
    if (_type == PostType.image && _selectedImages.isEmpty) {
      setState(() => _error = 'Please attach at least one photo.');
      return;
    }
    if (_type == PostType.video && _selectedVideo == null) {
      setState(() => _error = 'Please attach a video.');
      return;
    }
    
    setState(() => _error = null);

    if (!AppState.instance.uploadVerified) {
      _showOtpSheet();
      return;
    }

    _finalizeSubmission();
  }

  Future<void> _pickMedia() async {
    if (_isPicking) return;
    setState(() => _isPicking = true);
    try {
      if (_type == PostType.image) {
        final List<XFile> picked = await _picker.pickMultiImage();
        if (picked.isNotEmpty) {
          setState(() {
            _selectedImages = picked;
          });
        }
      } else {
        final XFile? picked = await _picker.pickVideo(source: ImageSource.gallery);
        if (picked != null) {
          setState(() {
            _selectedVideo = picked;
          });
        }
      }
    } catch (e) {
      setState(() => _error = 'Failed to pick media: $e');
    } finally {
      setState(() => _isPicking = false);
    }
  }

  void _showOtpSheet() async {
    _otpController.clear();
    Timer? sheetTimer;
    
    // Send OTP immediately upon opening
    final phone = AppState.instance.userPhone.isNotEmpty ? AppState.instance.userPhone : '9876543210';
    try {
      await ApiService.instance.sendOtp(phone);
    } catch (e) {
      // Handle fail
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

            // Start timer on first build
            if (sheetTimer == null) {
              startTimer();
            }

            void verifyOtp() async {
              if (_otpController.text.length != 4) {
                setSheetState(() => sheetError = 'Please enter a 4-digit code.');
                return;
              }
              setSheetState(() => sheetSubmitting = true);
              
              try {
                final success = await ApiService.instance.verifyOtp(phone, _otpController.text);
                setSheetState(() => sheetSubmitting = false);
                
                if (!success) {
                  setSheetState(() => sheetError = 'Incorrect OTP.');
                  return;
                }
                
                AppState.instance.uploadVerified = true;
                if (mounted) Navigator.pop(context);
                _finalizeSubmission();
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
                      maxLength: 4,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 24, letterSpacing: 16, fontWeight: FontWeight.w700),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: '••••',
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
          }
        );
      },
    ).then((_) {
      sheetTimer?.cancel();
    });
  }

  void _finalizeSubmission() async {
    setState(() => _submitting = true);
    
    try {
      final String contentType = _type == PostType.image ? 'image' : 'video';
      final mobile = AppState.instance.userPhone.isNotEmpty ? AppState.instance.userPhone : '9876543210';
      
      // 1. Submit UGC data first
      final ugcResponse = await ApiService.instance.submitUgc({
        'mobile': mobile,
        'title': _titleController.text.trim(),
        'description': _captionController.text.trim(),
        'category': _category.toLowerCase(),
        'content_type': contentType,
        'media_url': '', // Provided after upload if needed
        'thumbnail_url': '',
        'location_lat': '17.141500', // Mocked or get from geolocator later
        'location_lon': '79.623600',
        'village': '',
        'subdistrict': '',
        'district': AppState.instance.district,
        'state': AppState.instance.stateName,
        'country': 'India',
      });
      
      final submissionId = ugcResponse['submission_id'] ?? ugcResponse['id'] ?? 'mock-uuid-123';
      
      // 2. Upload media tied to submission_id
        if (_type == PostType.image && _selectedImages.isNotEmpty) {
          await ApiService.instance.uploadMedia(
            submissionId: submissionId.toString(),
            mobile: mobile,
            mediaType: contentType,
            filePath: _selectedImages.first.path,
          );
        } else if (_type == PostType.video && _selectedVideo != null) {
          await ApiService.instance.uploadMedia(
            submissionId: submissionId.toString(),
            mobile: mobile,
            mediaType: contentType,
            filePath: _selectedVideo!.path,
          );
        }
        
        // Register the post locally to reflect in the Reporter Dashboard
        AppState.instance.submitReporterPost(
          type: _type,
          caption: _titleController.text.trim(),
          category: _category,
          mediaUrl: _type == PostType.image && _selectedImages.isNotEmpty 
              ? _selectedImages.first.path 
              : (_selectedVideo?.path ?? ''),
        );
        
        if (mounted) {
        setState(() {
          _submitting = false;
          _titleController.clear();
          _captionController.clear();
          _selectedImages.clear();
          _selectedVideo = null;
          _type = PostType.image;
          _category = 'Local';
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('News submitted to Admin Queue (Pending)'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
          if (!(ModalRoute.of(context)?.isFirst ?? true)) {
            Navigator.of(context).pop();
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = 'Failed to submit post: $e';
        });
      }
    }
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
              
              // Points info
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
    final hasMedia = (_type == PostType.image && _selectedImages.isNotEmpty) || 
                     (_type == PostType.video && _selectedVideo != null);
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: (ModalRoute.of(context)?.isFirst ?? true) ? null : IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isDark ? Colors.white10 : const Color(0xFFF1F2F5),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.chevron_left, size: 20, color: Theme.of(context).iconTheme.color),
          ),
          onPressed: () => Navigator.pop(context),
        ),
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
              const Text('POST TYPE',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.5)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _typeCard(
                      icon: '🖼️',
                      label: 'Image News',
                      selected: _type == PostType.image,
                      onTap: () => setState(() { _type = PostType.image; _selectedVideo = null; }),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _typeCard(
                      icon: '🎥',
                      label: 'Video News',
                      selected: _type == PostType.video,
                      onTap: () => setState(() { _type = PostType.video; _selectedImages.clear(); }),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Upload Box
              GestureDetector(
                onTap: _pickMedia,
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
                    image: hasMedia && _type == PostType.image
                        ? DecorationImage(
                            image: FileImage(File(_selectedImages.first.path)),
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
                                onTap: () => setState(() {
                                  _selectedImages.clear();
                                  _selectedVideo = null;
                                }),
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
                            if (_type == PostType.image)
                              Positioned(
                                bottom: 8,
                                left: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text('${_selectedImages.length} photo(s)', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                                ),
                              ),
                            if (_type == PostType.video)
                               const Center(child: Icon(Icons.play_circle_fill, color: Colors.white, size: 48)),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(_type == PostType.image ? '🖼️' : '🎥', style: const TextStyle(fontSize: 24)),
                            const SizedBox(height: 8),
                            Text(
                              _type == PostType.image ? 'Tap to attach a photo' : 'Tap to attach a video',
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                            ),
                          ],
                        ),
                ),
              ),
              
              if (_type == PostType.image && _selectedImages.length > 1) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 60,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _selectedImages.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(_selectedImages[index].path),
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
              
              const SizedBox(height: 12),
              // Location Chip
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
                      '${AppState.instance.district}, ${AppState.instance.stateName}',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Theme.of(context).textTheme.bodyLarge?.color),
                    ),
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
                  final selected = cat == _category;
                  return GestureDetector(
                    onTap: () => setState(() => _category = cat),
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
              
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12.5)),
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
                  onPressed: _submitting ? null : _onSubmitPressed,
                  child: _submitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Submit for Review',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
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
    _titleController.dispose();
    _captionController.dispose();
    _otpController.dispose();
    super.dispose();
  }
}
