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
  String? _error;

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
    } catch (e) {
      // Resetting the spinner alone told the moderator nothing: the button
      // simply became clickable again, with no way to tell a failed reject
      // from a slow one.
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('వార్తను తిరస్కరించండి', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _notesController,
            maxLines: 2,
            decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'తిరస్కరణకు కారణం'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: const TextStyle(color: Colors.red, fontSize: 12.5),
            ),
          ],
        ],
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
