import 'package:flutter/material.dart';
import '../../theme/admin_colors.dart';

typedef AdminRejectCallback = Future<void> Function(String notes);

Future<bool?> showAdminRejectDialog(BuildContext context, {required AdminRejectCallback onReject}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => _AdminRejectDialog(onReject: onReject),
  );
}

class _AdminRejectDialog extends StatefulWidget {
  final AdminRejectCallback onReject;
  const _AdminRejectDialog({required this.onReject});

  @override
  State<_AdminRejectDialog> createState() => _AdminRejectDialogState();
}

class _AdminRejectDialogState extends State<_AdminRejectDialog> {
  late final TextEditingController _notesController = TextEditingController(text: 'నిర్ధారించబడని లేదా నకిలీ కంటెంట్.');
  bool _submitting = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await widget.onReject(_notesController.text.trim());
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('వార్తను తిరస్కరించండి', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
      content: TextField(
        controller: _notesController,
        maxLines: 2,
        decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'తిరస్కరణకు కారణం'),
      ),
      actions: [
        TextButton(onPressed: _submitting ? null : () => Navigator.of(context).pop(false), child: const Text('రద్దు చేయి')),
        ElevatedButton(
          onPressed: _submitting ? null : _submit,
          style: ElevatedButton.styleFrom(backgroundColor: AdminColors.error, foregroundColor: Colors.white),
          child: _submitting
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('తిరస్కరించు'),
        ),
      ],
    );
  }
}
