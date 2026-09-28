import 'package:flutter/material.dart';
import '../../../data/models/admin_push_notification_payload.dart';
import '../../../data/models/admin_ugc_options.dart';
import '../../../data/models/admin_ugc_submission_model.dart';
import '../../theme/admin_colors.dart';
import '../../../../../services/api_service.dart';

typedef AdminApproveCallback = Future<void> Function(
  String notes,
  String publicationLevel,
  AdminPushNotificationPayload? push,
);

/// `POST /admin/api/notifications/target-preview/` → target_count,
/// target_scope, target_type, target_data, warnings.
typedef AdminPreviewCallback = Future<Map<String, dynamic>> Function(
    Map<String, dynamic> request);

/// Shows the approval dialog. Returns true if the approve call succeeded.
Future<bool?> showAdminApprovalDialog(
  BuildContext context, {
  required AdminUgcSubmissionModel submission,
  required AdminApproveCallback onApprove,
  AdminPreviewCallback? onPreview,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => _AdminApprovalDialog(
        submission: submission, onApprove: onApprove, onPreview: onPreview),
  );
}

class _AdminApprovalDialog extends StatefulWidget {
  final AdminUgcSubmissionModel submission;
  final AdminApproveCallback onApprove;
  final AdminPreviewCallback? onPreview;

  const _AdminApprovalDialog(
      {required this.submission, required this.onApprove, this.onPreview});

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

  // Audience preview (handover §15): shown before any push goes out.
  Map<String, dynamic>? _preview;
  bool _previewLoading = false;
  String? _previewError;
  bool _confirmedAudience = false;
  int _previewSeq = 0;

  List<String> get _previewWarnings {
    final w = _preview?['warnings'];
    if (w is List) return w.map((e) => e.toString()).toList();
    if (w is String && w.isNotEmpty) return [w];
    return const [];
  }

  /// Explicit confirmation is required when the backend warns, when the
  /// target is everyone, or when the preview could not be checked.
  bool get _needsConfirmation =>
      _previewWarnings.isNotEmpty ||
      _pushTarget == 'all' ||
      _previewError != null;

  bool get _canApprove =>
      !_submitting &&
      (!_sendPush ||
          (!_previewLoading && (!_needsConfirmation || _confirmedAudience)));

  Future<void> _loadPreview() async {
    if (!_sendPush) return;
    final seq = ++_previewSeq;
    setState(() {
      _previewLoading = true;
      _previewError = null;
      _confirmedAudience = false;
    });
    try {
      final s = widget.submission;
      final preview = widget.onPreview ??
          ApiService.instance.previewAdminNotificationTarget;
      final data = await preview({
        'target_type': _pushTarget,
        'target': _pushTarget,
        'notification_type': _pushType,
        if (s.stateName.isNotEmpty) 'state': s.stateName,
        if (s.district.isNotEmpty) 'district': s.district,
        if (s.district.isNotEmpty) 'city': s.district,
        if (s.mandal.isNotEmpty) 'subdistrict': s.mandal,
        if (s.village.isNotEmpty) 'village': s.village,
      });
      if (!mounted || seq != _previewSeq) return;
      setState(() {
        _preview = data;
        _previewLoading = false;
      });
    } catch (e) {
      if (!mounted || seq != _previewSeq) return;
      setState(() {
        _preview = null;
        _previewError = 'ప్రేక్షకుల సంఖ్యను తనిఖీ చేయలేకపోయాం.';
        _previewLoading = false;
      });
    }
  }

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

  /// Who will receive the push, straight from the target-preview API, with
  /// a confirmation checkbox when the audience is broad or flagged.
  Widget _buildAudiencePreview(bool isDark) {
    final secondary = AdminColors.textSecondaryColor(isDark);
    if (_previewLoading) {
      return Row(children: [
        const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2)),
        const SizedBox(width: 8),
        Text('ప్రేక్షకులను లెక్కిస్తోంది…',
            style: TextStyle(fontSize: 12.5, color: secondary)),
      ]);
    }
    final count = _preview?['target_count'];
    final scope = _preview?['target_scope']?.toString() ?? '';
    return Column(
      key: const Key('admin_push_preview'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_previewError != null)
          Row(children: [
            Expanded(
              child: Text(_previewError!,
                  style: const TextStyle(
                      fontSize: 12.5, color: AdminColors.error)),
            ),
            TextButton(
                onPressed: _loadPreview, child: const Text('మళ్లీ తనిఖీ')),
          ])
        else if (count != null)
          Text(
            'సుమారు $count మందికి చేరుతుంది${scope.isNotEmpty ? ' · $scope' : ''}',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AdminColors.textPrimary(isDark)),
          ),
        for (final w in _previewWarnings)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 16, color: Colors.amber),
                const SizedBox(width: 6),
                Expanded(
                    child: Text(w,
                        style: TextStyle(fontSize: 12.5, color: secondary))),
              ],
            ),
          ),
        if (_needsConfirmation)
          CheckboxListTile(
            key: const Key('admin_push_confirm'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
            value: _confirmedAudience,
            onChanged: (v) => setState(() => _confirmedAudience = v ?? false),
            title: Text(
              _pushTarget == 'all'
                  ? 'అందరికీ పంపుతున్నానని నిర్ధారిస్తున్నాను'
                  : 'ఈ ప్రేక్షకులకు పంపుతున్నానని నిర్ధారిస్తున్నాను',
              style: const TextStyle(fontSize: 12.5),
            ),
          ),
      ],
    );
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
                        isExpanded: true,
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
                      // Material, not a coloured Container: the switch tile
                      // paints its ink on the nearest Material.
                      Material(
                        color: AdminColors.surface(isDark),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('పుష్ నోటిఫికేషన్ పంపండి', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                              value: _sendPush,
                              activeThumbColor: AdminColors.primary,
                              onChanged: (v) {
                                setState(() => _sendPush = v);
                                if (v) _loadPreview();
                              },
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
                                      isExpanded: true,
                                      initialValue: _pushType,
                                      decoration: const InputDecoration(labelText: 'రకం', border: OutlineInputBorder()),
                                      items: AdminUgcOptions.pushNotificationTypes
                                          .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                                          .toList(),
                                      onChanged: (v) {
                                        setState(() => _pushType = v ?? _pushType);
                                        _loadPreview();
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      isExpanded: true,
                                      initialValue: _pushTarget,
                                      decoration: const InputDecoration(labelText: 'లక్ష్యం', border: OutlineInputBorder()),
                                      items: AdminUgcOptions.pushNotificationTargets
                                          .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                                          .toList(),
                                      onChanged: (v) {
                                        setState(() => _pushTarget = v ?? _pushTarget);
                                        _loadPreview();
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              _buildAudiencePreview(isDark),
                            ],
                          ],
                        ),
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
                    key: const Key('admin_approve_submit'),
                    onPressed: _canApprove ? _submit : null,
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
