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

  bool _showOtpStep = false;
  bool _submitting = false;
  String? _error;

  static const _categories = [
    'Local',
    'Sports',
    'Politics',
    'Weather',
    'Accident',
    'Community'
  ];

  // Mock media placeholders since real file/camera pickers need
  // platform-specific setup outside this preview environment.
  static const _mockImageThumbnail =
      'https://images.unsplash.com/photo-1495020689067-958852a7765e?w=600';
  static const _mockVideoThumbnail =
      'https://images.unsplash.com/photo-1495020689067-958852a7765e?w=600';

  void _onSubmitPressed() {
    if (_captionController.text.trim().isEmpty) {
      setState(() => _error = 'Add a short caption describing the news.');
      return;
    }
    setState(() => _error = null);

    if (!AppState.instance.uploadVerified) {
      // First-ever submission for this account — show the one-time OTP step.
      setState(() => _showOtpStep = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('OTP sent once to your registered number (demo code: 1234)'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    _finalizeSubmission();
  }

  void _onVerifyOtpPressed() {
    setState(() => _submitting = true);
    final success = AppState.instance.verifyUploadOtp(_otpController.text);
    setState(() => _submitting = false);
    if (!success) {
      setState(() => _error = 'Incorrect OTP. Demo code is 1234.');
      return;
    }
    _finalizeSubmission();
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Post News')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: _showOtpStep ? _buildOtpStep() : _buildFormStep(),
        ),
      ),
    );
  }

  Widget _buildFormStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Post type',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _typeChip(
                icon: Icons.image_outlined,
                label: 'Image News',
                selected: _type == PostType.image,
                onTap: () => setState(() => _type = PostType.image),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _typeChip(
                icon: Icons.videocam_outlined,
                label: 'Video News',
                selected: _type == PostType.video,
                onTap: () => setState(() => _type = PostType.video),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        // Mock media picker — a real build would use image_picker/file_picker.
        Container(
          height: 160,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.chipBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE0E0E3), style: BorderStyle.solid),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _type == PostType.image ? Icons.add_photo_alternate_outlined : Icons.video_call_outlined,
                size: 36,
                color: AppColors.textMuted,
              ),
              const SizedBox(height: 8),
              Text(
                _type == PostType.image ? 'Tap to attach a photo (mock)' : 'Tap to attach a video (mock)',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Text('Category',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _categories.map((cat) {
            final selected = cat == _category;
            return GestureDetector(
              onTap: () => setState(() => _category = cat),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : AppColors.chipBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  cat,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: selected ? Colors.white : AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 18),
        const Text('Caption',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
        const SizedBox(height: 8),
        TextField(
          controller: _captionController,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Describe what\'s happening in a sentence or two...',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE0E0E3)),
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12.5)),
        ],
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
            onPressed: _onSubmitPressed,
            child: const Text('Submit for Review',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  Widget _buildOtpStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.verified_user_outlined, color: AppColors.primary, size: 28),
        ),
        const SizedBox(height: 16),
        const Text(
          'One-time verification',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textDark),
        ),
        const SizedBox(height: 6),
        Text(
          'This is a one-time check for your first post. We\'ve sent a code '
          'to +91 ${AppState.instance.userPhone.isEmpty ? "XXXXXXXXXX" : AppState.instance.userPhone}. '
          'You won\'t need to do this again for future posts.',
          style: const TextStyle(color: AppColors.textMuted, fontSize: 13.5, height: 1.4),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          maxLength: 4,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, letterSpacing: 8, fontWeight: FontWeight.w700),
          decoration: InputDecoration(
            counterText: '',
            hintText: '••••',
            filled: true,
            fillColor: AppColors.chipBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12.5)),
        ],
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
            onPressed: _submitting ? null : _onVerifyOtpPressed,
            child: _submitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
                  )
                : const Text('Verify & Submit',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  Widget _typeChip({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? AppColors.primary : const Color(0xFFE0E0E3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? AppColors.primary : AppColors.textMuted),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.primary : AppColors.textMuted,
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
