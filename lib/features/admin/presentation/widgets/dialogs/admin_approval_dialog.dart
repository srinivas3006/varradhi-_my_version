import 'package:flutter/material.dart';
import '../../../data/models/admin_push_notification_payload.dart';
import '../../../data/models/admin_ugc_options.dart';
import '../../../data/models/admin_ugc_submission_model.dart';
import '../../theme/admin_colors.dart';

typedef AdminApproveCallback = Future<void> Function(
  String notes,
  String publicationLevel,
  AdminPushNotificationPayload? push,
);

/// Shows the approval dialog. Returns true if the approve call succeeded.
Future<bool?> showAdminApprovalDialog(
  BuildContext context, {
  required AdminUgcSubmissionModel submission,
  required AdminApproveCallback onApprove,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => _AdminApprovalDialog(submission: submission, onApprove: onApprove),
  );
}

class _AdminApprovalDialog extends StatefulWidget {
  final AdminUgcSubmissionModel submission;
  final AdminApproveCallback onApprove;

  const _AdminApprovalDialog({required this.submission, required this.onApprove});

  @override
  State<_AdminApprovalDialog> createState() => _AdminApprovalDialogState();
}

class _AdminApprovalDialogState extends State<_AdminApprovalDialog> {
  late String _publicationLevel;
  late final TextEditingController _notesController;
  late final TextEditingController _pushTitleController;
  late final TextEditingController _pushBodyController;
  bool _sendPush = false;
  String _pushType = AdminUgcOptions.pushNotificationTypes.first;
  String _pushTarget = AdminUgcOptions.pushNotificationTargets.first;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _publicationLevel = AdminUgcOptions.publicationLevels.first.value;
    _notesController = TextEditingController(text: 'ఎడిటర్ ద్వారా ధృవీకరించబడింది.');
    _pushTitleController = TextEditingController(text: widget.submission.title);
    _pushBodyController = TextEditingController(text: widget.submission.title);
  }

  @override
  void dispose() {
    _notesController.dispose();
    _pushTitleController.dispose();
    _pushBodyController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final push = _sendPush
          ? AdminPushNotificationPayload(
              title: _pushTitleController.text.trim(),
              body: _pushBodyController.text.trim(),
              type: _pushType,
              target: _pushTarget,
              stateName: widget.submission.stateName,
              district: widget.submission.district,
              city: widget.submission.district,
              village: widget.submission.village,
              subdistrict: widget.submission.mandal,
            )
          : null;
      await widget.onApprove(_notesController.text.trim(), _publicationLevel, push);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = 'ఆమోదించడం విఫలమైంది. దయచేసి మళ్ళీ ప్రయత్నించండి.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Dialog(
      backgroundColor: AdminColors.card(isDark),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.check_circle, color: AdminColors.success, size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('వార్తను ఆమోదించండి', style: TextStyle(color: AdminColors.textPrimary(isDark), fontWeight: FontWeight.w800, fontSize: 17)),
                        Text(widget.submission.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: AdminColors.textSecondaryColor(isDark), fontSize: 12.5)),
                      ],
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.of(context).pop(false), icon: const Icon(Icons.close)),
                ],
              ),
              const Divider(height: 24),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ప్రచురణ స్థాయి', style: TextStyle(color: AdminColors.textSecondaryColor(isDark), fontSize: 12, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _publicationLevel,
                        decoration: const InputDecoration(border: OutlineInputBorder()),
                        items: AdminUgcOptions.publicationLevels
                            .map((o) => DropdownMenuItem(
                                  value: o.value,
                                  child: Text('${o.label} — ${o.description}', overflow: TextOverflow.ellipsis),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _publicationLevel = v ?? _publicationLevel),
                      ),
                      const SizedBox(height: 16),
                      Text('అడ్మిన్ గమనికలు', style: TextStyle(color: AdminColors.textSecondaryColor(isDark), fontSize: 12, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _notesController,
                        maxLines: 2,
                        decoration: const InputDecoration(border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AdminColors.surface(isDark),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('పుష్ నోటిఫికేషన్ పంపండి', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                              value: _sendPush,
                              activeThumbColor: AdminColors.primary,
                              onChanged: (v) => setState(() => _sendPush = v),
                            ),
                            if (_sendPush) ...[
                              const SizedBox(height: 4),
                              TextField(
                                controller: _pushTitleController,
                                decoration: const InputDecoration(labelText: 'శీర్షిక', border: OutlineInputBorder()),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _pushBodyController,
                                decoration: const InputDecoration(labelText: 'సందేశం', border: OutlineInputBorder()),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      initialValue: _pushType,
                                      decoration: const InputDecoration(labelText: 'రకం', border: OutlineInputBorder()),
                                      items: AdminUgcOptions.pushNotificationTypes
                                          .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                                          .toList(),
                                      onChanged: (v) => setState(() => _pushType = v ?? _pushType),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      initialValue: _pushTarget,
                                      decoration: const InputDecoration(labelText: 'లక్ష్యం', border: OutlineInputBorder()),
                                      items: AdminUgcOptions.pushNotificationTargets
                                          .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                                          .toList(),
                                      onChanged: (v) => setState(() => _pushTarget = v ?? _pushTarget),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 10),
                        Text(_error!, style: const TextStyle(color: AdminColors.error, fontSize: 12.5)),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: _submitting ? null : () => Navigator.of(context).pop(false), child: const Text('రద్దు చేయి')),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    style: ElevatedButton.styleFrom(backgroundColor: AdminColors.success, foregroundColor: Colors.white),
                    child: _submitting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('ఆమోదించు'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
