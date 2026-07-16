import 'package:flutter/material.dart';
import '../models/reporter_post.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  PostType _type = PostType.image;
  String _category = 'Local';
  final _captionController = TextEditingController();
  final _otpController = TextEditingController();

  bool _submitting = false;
  String? _error;
  bool _hasImageAttached = false; // Mock attachment state

  static const _categories = [
    'Local',
    'Sports',
    'Politics',
    'Weather',
    'Accident',
    'Community'
  ];

  static const _mockImageThumbnail =
      'https://images.unsplash.com/photo-1495020689067-958852a7765e?w=600';
  static const _mockVideoThumbnail =
      'https://images.unsplash.com/photo-1495020689067-958852a7765e?w=600';

  @override
  void initState() {
    super.initState();
    _captionController.addListener(() => setState(() {}));
  }

  void _onSubmitPressed() {
    if (_captionController.text.trim().isEmpty) {
      setState(() => _error = 'Add a short caption describing the news.');
      return;
    }
    setState(() => _error = null);

    if (!AppState.instance.uploadVerified) {
      _showOtpSheet();
      return;
    }

    _finalizeSubmission();
  }

  void _showOtpSheet() {
    _otpController.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            bool sheetSubmitting = false;
            String? sheetError;

            void verifyOtp() {
              if (_otpController.text.length != 4) {
                setSheetState(() => sheetError = 'Please enter a 4-digit code.');
                return;
              }
              setSheetState(() => sheetSubmitting = true);
              final success = AppState.instance.verifyUploadOtp(_otpController.text);
              setSheetState(() => sheetSubmitting = false);
              
              if (!success) {
                setSheetState(() => sheetError = 'Incorrect OTP. Demo code is 1234.');
                return;
              }
              
              Navigator.pop(context);
              _finalizeSubmission();
            }

            final isDark = Theme.of(context).brightness == Brightness.dark;
            final sheetColor = Theme.of(context).cardColor;
            
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
                    Text(
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
                        fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.02),
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
                    const Text.rich(
                      TextSpan(
                        text: 'Resend code in ',
                        children: [
                          TextSpan(text: '0:24', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      style: TextStyle(fontSize: 11, color: AppColors.textMuted),
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
    );
  }

  void _finalizeSubmission() {
    AppState.instance.submitReporterPost(
      type: _type,
      caption: _captionController.text.trim(),
      category: _category,
      mediaUrl: _type == PostType.image ? _mockImageThumbnail : _mockVideoThumbnail,
    );
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Post submitted — pending editorial review.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Post News', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
            const Text('Share what\'s happening around you', style: TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.normal)),
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
                      onTap: () => setState(() { _type = PostType.image; _hasImageAttached = false; }),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _typeCard(
                      icon: '🎥',
                      label: 'Video News',
                      selected: _type == PostType.video,
                      onTap: () => setState(() { _type = PostType.video; _hasImageAttached = false; }),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Upload Box
              GestureDetector(
                onTap: () {
                  setState(() { _hasImageAttached = true; }); // Mock attach
                },
                child: Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: _hasImageAttached ? Colors.black : (isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFFBFBFC)),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.white24 : const Color(0xFFD6D9E0), 
                      style: _hasImageAttached ? BorderStyle.solid : BorderStyle.none,
                      width: 1.5
                    ),
                    image: _hasImageAttached
                        ? DecorationImage(
                            image: NetworkImage(_type == PostType.image ? _mockImageThumbnail : _mockVideoThumbnail),
                            fit: BoxFit.cover,
                            colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.3), BlendMode.darken),
                          )
                        : null,
                  ),
                  child: _hasImageAttached
                      ? Stack(
                          children: [
                            Positioned(
                              top: 8,
                              right: 8,
                              child: GestureDetector(
                                onTap: () => setState(() => _hasImageAttached = false),
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
                            Positioned(
                              bottom: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text('1/4 photos', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
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
              const Text('CAPTION',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.5)),
              const SizedBox(height: 10),
              TextField(
                controller: _captionController,
                maxLines: 3,
                maxLength: 220,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Describe what\'s happening in a sentence or two...',
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
              
              if (AppState.instance.uploadVerified) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAFBF3),
                    border: Border.all(color: const Color(0xFFCDF1E1)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check, color: Color(0xFF1FAE7A), size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Verified reporter — posting instantly, no OTP needed',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1FAE7A)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
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
                    shadowColor: AppColors.primary.withOpacity(0.4),
                  ),
                  onPressed: _onSubmitPressed,
                  child: const Text('Submit for Review',
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
          color: selected ? AppColors.primary.withOpacity(0.1) : Theme.of(context).cardColor,
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
    _captionController.dispose();
    _otpController.dispose();
    super.dispose();
  }
}
