import 'package:flutter/material.dart';
import '../../../data/models/admin_ugc_options.dart';
import '../../controllers/admin_ugc_detail_controller.dart';
import '../../theme/admin_colors.dart';

void showAdminEditMetadataSheet(BuildContext context, {required AdminUgcDetailController controller}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _AdminEditMetadataSheetBody(controller: controller),
  );
}

class _AdminEditMetadataSheetBody extends StatefulWidget {
  final AdminUgcDetailController controller;
  const _AdminEditMetadataSheetBody({required this.controller});

  @override
  State<_AdminEditMetadataSheetBody> createState() => _AdminEditMetadataSheetBodyState();
}

class _AdminEditMetadataSheetBodyState extends State<_AdminEditMetadataSheetBody> {
  late final s = widget.controller.submission;
  late final _titleController = TextEditingController(text: s.title);
  late final _descriptionController = TextEditingController(text: s.description);
  late final _categoryController = TextEditingController(text: s.category);
  late final _stateController = TextEditingController(text: s.stateName);
  late final _districtController = TextEditingController(text: s.district);
  late final _subdistrictController = TextEditingController(text: s.mandal);
  late final _villageController = TextEditingController(text: s.village);
  late final _latController = TextEditingController(text: s.latitude?.toString() ?? '');
  late final _lonController = TextEditingController(text: s.longitude?.toString() ?? '');
  late final _notesController = TextEditingController();
  late String _publicationLevel = s.publicationLevel.isNotEmpty ? s.publicationLevel : AdminUgcOptions.publicationLevels.first.value;

  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _stateController.dispose();
    _districtController.dispose();
    _subdistrictController.dispose();
    _villageController.dispose();
    _latController.dispose();
    _lonController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_titleController.text.trim().isEmpty) {
      setState(() => _error = 'Title is required.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final body = s.toPatchJson(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _categoryController.text.trim(),
        publicationLevel: _publicationLevel,
        stateName: _stateController.text.trim(),
        district: _districtController.text.trim(),
        subdistrict: _subdistrictController.text.trim(),
        village: _villageController.text.trim(),
        latitude: double.tryParse(_latController.text.trim()),
        longitude: double.tryParse(_lonController.text.trim()),
        adminNotes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );
      await widget.controller.patchMetadata(body);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to save changes.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
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
                    const Icon(Icons.edit_outlined, color: AdminColors.primary, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('Edit Submission Metadata', style: TextStyle(color: AdminColors.textPrimary(isDark), fontWeight: FontWeight.w800, fontSize: 16)),
                    ),
                    IconButton(onPressed: () => Navigator.of(context).pop(false), icon: const Icon(Icons.close)),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(controller: _titleController, decoration: const InputDecoration(labelText: 'Title *', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: _descriptionController, maxLines: 3, decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: TextField(controller: _categoryController, decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()))),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _publicationLevel,
                        decoration: const InputDecoration(labelText: 'Publication Level', border: OutlineInputBorder()),
                        items: AdminUgcOptions.publicationLevels.map((o) => DropdownMenuItem(value: o.value, child: Text(o.label))).toList(),
                        onChanged: (v) => setState(() => _publicationLevel = v ?? _publicationLevel),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: TextField(controller: _stateController, decoration: const InputDecoration(labelText: 'State', border: OutlineInputBorder()))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: _districtController, decoration: const InputDecoration(labelText: 'District', border: OutlineInputBorder()))),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: TextField(controller: _subdistrictController, decoration: const InputDecoration(labelText: 'Subdistrict', border: OutlineInputBorder()))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: _villageController, decoration: const InputDecoration(labelText: 'Village', border: OutlineInputBorder()))),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _latController,
                        keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                        decoration: const InputDecoration(labelText: 'Latitude', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _lonController,
                        keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                        decoration: const InputDecoration(labelText: 'Longitude', border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Admin Notes / Revision Reason', border: OutlineInputBorder()),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!, style: const TextStyle(color: AdminColors.error, fontSize: 12.5)),
                ],
                const SizedBox(height: 18),
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
                          : const Text('Save Changes'),
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
}
