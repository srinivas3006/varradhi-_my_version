import 'package:flutter/material.dart';
import '../../theme/admin_colors.dart';

/// Human label for a bulk action wire value, as sent by [AdminBulkActionBar].
String adminBulkActionLabel(String action) {
  switch (action) {
    case 'approve':
      return 'Approve';
    case 'reject':
      return 'Reject';
    case 'flag':
      return 'Flag';
    case 'increase_trust':
      return 'Increase trust';
    case 'block':
      return 'Block uploader';
    default:
      return action;
  }
}

/// Whether an action is destructive enough to warrant a red confirm button.
bool isAdminBulkActionDestructive(String action) =>
    action == 'reject' || action == 'block';

/// Confirms a bulk action and collects the moderation note recorded against
/// every affected submission.
///
/// Returns the note (possibly empty) on confirm, or `null` if the admin
/// cancelled — a bulk approve/reject over a whole page of submissions is not
/// something to fire on a single stray tap.
Future<String?> showAdminBulkNotesDialog(
  BuildContext context, {
  required String action,
  required int count,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _AdminBulkNotesDialog(action: action, count: count),
  );
}

class _AdminBulkNotesDialog extends StatefulWidget {
  final String action;
  final int count;

  const _AdminBulkNotesDialog({required this.action, required this.count});

  @override
  State<_AdminBulkNotesDialog> createState() => _AdminBulkNotesDialogState();
}

class _AdminBulkNotesDialogState extends State<_AdminBulkNotesDialog> {
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = adminBulkActionLabel(widget.action);
    final destructive = isAdminBulkActionDestructive(widget.action);

    return AlertDialog(
      title: Text('$label ${widget.count} ${widget.count == 1 ? 'submission' : 'submissions'}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (destructive)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'This cannot be undone from the queue.',
                style: TextStyle(fontSize: 12.5, color: AdminColors.error, fontWeight: FontWeight.w600),
              ),
            ),
          TextField(
            controller: _notesController,
            maxLines: 2,
            autofocus: true,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Moderation note',
              helperText: 'Recorded on every selected submission.',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_notesController.text.trim()),
          style: ElevatedButton.styleFrom(
            backgroundColor: destructive ? AdminColors.error : AdminColors.primary,
            foregroundColor: Colors.white,
          ),
          child: Text(label),
        ),
      ],
    );
  }
}
