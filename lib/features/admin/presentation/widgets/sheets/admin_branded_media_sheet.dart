import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../controllers/admin_ugc_detail_controller.dart';
import '../../theme/admin_colors.dart';

void showAdminBrandedMediaSheet(BuildContext context, {required AdminUgcDetailController controller}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _AdminBrandedMediaSheetBody(controller: controller),
  );
}

class _AdminBrandedMediaSheetBody extends StatefulWidget {
  final AdminUgcDetailController controller;
  const _AdminBrandedMediaSheetBody({required this.controller});

  @override
  State<_AdminBrandedMediaSheetBody> createState() => _AdminBrandedMediaSheetBodyState();
}

class _AdminBrandedMediaSheetBodyState extends State<_AdminBrandedMediaSheetBody> {
  final _picker = ImagePicker();
  late final TextEditingController _notesController = TextEditingController(text: 'VARADHI watermark added');

  File? _imageFile;
  File? _videoFile;
  File? _thumbnailFile;
  bool _submitting = false;
  String? _error;

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _imageFile = File(picked.path));
  }

  Future<void> _pickVideo() async {
    final picked = await _picker.pickVideo(source: ImageSource.gallery);
    if (picked != null) setState(() => _videoFile = File(picked.path));
  }

  Future<void> _pickThumbnail() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _thumbnailFile = File(picked.path));
  }

  Future<void> _submit() async {
    if (_imageFile == null && _videoFile == null) {
      setState(() => _error = 'Pick an image or video first.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.controller.uploadBrandedMedia(
        imageFile: _imageFile,
        videoFile: _videoFile,
        thumbnailFile: _thumbnailFile,
        notes: _notesController.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = 'Upload failed. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: BoxDecoration(color: AdminColors.card(isDark), borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 20 + MediaQuery.of(context).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.verified_outlined, color: AdminColors.success, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Upload VARADHI Branded Media', style: TextStyle(color: AdminColors.textPrimary(isDark), fontWeight: FontWeight.w800, fontSize: 16)),
                          Text(widget.controller.submission.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: AdminColors.textSecondaryColor(isDark), fontSize: 12)),
                        ],
                      ),
                    ),
                    IconButton(onPressed: () => Navigator.of(context).pop(false), icon: const Icon(Icons.close)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _submitting ? null : _pickImage,
                        icon: const Icon(Icons.image_outlined),
                        label: const Text('Pick Image'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _submitting ? null : _pickVideo,
                        icon: const Icon(Icons.videocam_outlined),
                        label: const Text('Pick Video'),
                      ),
                    ),
                  ],
                ),
                if (_imageFile != null) _selectedFileChip(_imageFile!.path.split(Platform.pathSeparator).last, () => setState(() => _imageFile = null), isDark),
                if (_videoFile != null) ...[
                  _selectedFileChip(_videoFile!.path.split(Platform.pathSeparator).last, () => setState(() => _videoFile = null), isDark),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _submitting ? null : _pickThumbnail,
                    icon: const Icon(Icons.photo_size_select_actual_outlined),
                    label: Text(_thumbnailFile == null ? 'Pick Thumbnail (optional)' : 'Thumbnail selected'),
                  ),
                ],
                const SizedBox(height: 16),
                Text('Branding Notes', style: TextStyle(color: AdminColors.textSecondaryColor(isDark), fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                TextField(controller: _notesController, decoration: const InputDecoration(border: OutlineInputBorder())),
                if (_submitting) ...[
                  const SizedBox(height: 16),
                  ValueListenableBuilder<double>(
                    valueListenable: widget.controller.uploadProgress,
                    builder: (context, progress, _) => ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(value: progress, minHeight: 6),
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!, style: const TextStyle(color: AdminColors.error, fontSize: 12.5)),
                ],
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: _submitting ? null : () => Navigator.of(context).pop(false), child: const Text('Cancel')),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _submitting ? null : _submit,
                      style: ElevatedButton.styleFrom(backgroundColor: AdminColors.primary, foregroundColor: Colors.white),
                      child: _submitting
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Upload Branded Media'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _selectedFileChip(String name, VoidCallback onDelete, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Chip(
        label: Text(name, overflow: TextOverflow.ellipsis),
        onDeleted: onDelete,
        backgroundColor: AdminColors.surface(isDark),
      ),
    );
  }
}
