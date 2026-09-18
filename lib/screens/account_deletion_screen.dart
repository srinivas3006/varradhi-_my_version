import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../localization/app_translations.dart';
import '../models/account_deletion_request.dart';
import '../services/api_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

class AccountDeletionScreen extends StatefulWidget {
  const AccountDeletionScreen({super.key});

  @override
  State<AccountDeletionScreen> createState() => _AccountDeletionScreenState();
}

class _AccountDeletionScreenState extends State<AccountDeletionScreen> {
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  AccountDeletionRequest? _currentRequest;

  // Form state
  String _selectedReason = 'privacy';
  final TextEditingController _notesController = TextEditingController();
  bool _isAcknowledged = false;

  @override
  void initState() {
    super.initState();
    _fetchDeletionStatus();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _fetchDeletionStatus() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final request = await ApiService.instance.getAccountDeletionRequest();
      if (!mounted) return;

      if (request != null && request.isApproved) {
        // Account has already been approved and deleted by admin
        await _handleApprovedAccount();
        return;
      }

      setState(() {
        _currentRequest = request;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        // If error isn't 404, record message
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _handleApprovedAccount() async {
    if (!mounted) return;
    await AppState.instance.logout();
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.green),
            SizedBox(width: 8),
            Text('Account Deleted'),
          ],
        ),
        content: const Text(
          'Your account deletion request has been approved and processed. Your personal data has been permanently purged.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).popUntil((route) => route.isFirst);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitDeletionRequest() async {
    if (!_isAcknowledged) return;

    final isTelugu = AppState.instance.language == 'Telugu';

    // Double confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isTelugu ? 'ఖాతా తొలగింపు అభ్యర్థన సమర్పించాలా?' : 'Submit Account Deletion Request?',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          isTelugu
            ? 'ఈ అభ్యర్థన అడ్మిన్ సమీక్షకు వెళుతుంది. అడ్మిన్ ఆమోదించిన తర్వాత మీ వ్యక్తిగత సమాచారం శాశ్వతంగా తొలగించబడుతుంది. మీరు కొనసాగించాలనుకుంటున్నారా?'
            : 'Your request will be placed in the admin review queue. Upon approval, your account and personal data will be permanently purged. Do you wish to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isTelugu ? 'అవును, సమర్పించు' : 'Yes, Submit'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isSubmitting = true);

    try {
      final req = await ApiService.instance.requestAccountDeletion(
        reason: _selectedReason,
        notes: _notesController.text.trim(),
        confirm: true,
      );

      if (!mounted) return;

      setState(() {
        _currentRequest = req;
        _isSubmitting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green[800],
          content: Text(
            isTelugu
                ? 'ఖాతా తొలగింపు అభ్యర్థన విజయవంతంగా సమర్పించబడింది.'
                : 'Deletion request submitted successfully. Awaiting review.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red[800],
          content: Text(e.toString().replaceAll('Exception: ', '')),
        ),
      );
    }
  }

  Future<void> _cancelDeletionRequest() async {
    final isTelugu = AppState.instance.language == 'Telugu';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isTelugu ? 'అభ్యర్థన రద్దు చేయాలా?' : 'Cancel Deletion Request?',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          isTelugu
              ? 'మీరు మీ ఖాతా తొలగింపు అభ్యర్థనను రద్దు చేయాలనుకుంటున్నారా? మీ ఖాతా సాధారణ స్థితిలోనే కొనసాగుతుంది.'
              : 'Are you sure you want to cancel your deletion request? Your account will remain active and untouched.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isTelugu ? 'అవును, రద్దు చేయి' : 'Yes, Cancel Request'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isSubmitting = true);

    try {
      await ApiService.instance.cancelAccountDeletionRequest();
      if (!mounted) return;

      setState(() {
        _currentRequest = null;
        _isSubmitting = false;
        _isAcknowledged = false;
        _notesController.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green[800],
          content: Text(
            isTelugu
                ? 'తొలగింపు అభ్యర్థన రద్దు చేయబడింది. మీ ఖాతా క్రియాశీలంగా ఉంది.'
                : 'Deletion request cancelled. Your account remains active.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red[800],
          content: Text(e.toString().replaceAll('Exception: ', '')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isTelugu = AppState.instance.language == 'Telugu';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isTelugu ? 'ఖాతా తొలగింపు' : 'Account Deletion',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
        ),
        centerTitle: false,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchDeletionStatus,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: _currentRequest != null && _currentRequest!.isPending
                    ? _buildPendingStateView(isDark, isTelugu)
                    : _buildFormView(isDark, isTelugu),
              ),
            ),
    );
  }

  // --- 1. Pending State View ---
  Widget _buildPendingStateView(bool isDark, bool isTelugu) {
    final req = _currentRequest!;
    final dateStr = req.createdAt != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(req.createdAt!.toLocal())
        : 'Recently';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2C2212) : const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.amber.withValues(alpha: 0.3) : const Color(0xFFF59E0B),
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.hourglass_top_rounded, color: Colors.amber, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isTelugu ? 'సమీక్షలో ఉంది (PENDING)' : 'Awaiting Admin Review',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.amber[200] : const Color(0xFF92400E),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isTelugu ? 'తేదీ: $dateStr' : 'Requested on $dateStr',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Text(
                isTelugu ? 'కారణం:' : 'Reason:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                AccountDeletionRequest.getReasonLabel(req.reason, isTelugu: isTelugu),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              if (req.notes != null && req.notes!.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  isTelugu ? 'మీ వివరణ:' : 'Your Notes:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  req.notes!,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Explanatory info box
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.06),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 20, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    isTelugu ? 'తదుపరి ఏమి జరుగుతుంది?' : 'What happens next?',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                isTelugu
                    ? '• మా అడ్మిన్ బృందం మీ ఖాతాకు సంబంధించిన రివార్డ్ చెల్లింపులు, కాయిన్స్ మరియు ప్రచురించిన కంటెంట్‌ను తనిఖీ చేస్తుంది.\n• అడ్మిన్ ఆమోదించే వరకు మీ ఖాతా అలాగే ఉంటుంది మరియు మీరు యాప్‌ను సాధారణంగా ఉపయోగించవచ్చు.\n• మీరు మనస్సు మార్చుకుంటే, అడ్మిన్ సమీక్షించేలోపు ఎప్పుడైనా ఈ అభ్యర్థనను రద్దు చేసుకోవచ్చు.'
                    : '• An administrator will review your account to settle any pending reward payouts, unredeemed coins, or published submissions.\n• You stay logged in and the app works normally until an admin approves your request.\n• If you change your mind, you can withdraw this deletion request at any time before it is reviewed.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        // Cancel Request Button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.redAccent, width: 1.2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: _isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.redAccent),
                  )
                : const Icon(Icons.close_rounded, color: Colors.redAccent),
            label: Text(
              isTelugu ? 'అభ్యర్థనను రద్దు చేయండి (Cancel Request)' : 'Withdraw Deletion Request',
              style: const TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            onPressed: _isSubmitting ? null : _cancelDeletionRequest,
          ),
        ),
      ],
    );
  }

  // --- 2. Initial Request Form View ---
  Widget _buildFormView(bool isDark, bool isTelugu) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF3B1515) : const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(fontSize: 12, color: Colors.red),
                  ),
                ),
              ],
            ),
          ),
        ],
        // Rejection Notice if applicable
        if (_currentRequest != null && _currentRequest!.isRejected) ...[
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF3B1515) : const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.red, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isTelugu ? 'గత అభ్యర్థన ఆమోదించబడలేదు' : 'Previous Request Not Approved',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isTelugu
                            ? 'మీ గత అభ్యర్థన సమీక్షించబడి ఆమోదించబడలేదు. సందేహాల కోసం support@vaaradhinews.com ని సంప్రదించండి.'
                            : 'Your previous request was reviewed and not approved. For assistance, contact support@vaaradhinews.com.',
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],

        // Warning Disclosure Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.red.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isTelugu ? 'ఖాతా మరియు డేటా తొలగింపు సమాచారం' : 'Data Purge & Retention Policy',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                isTelugu ? 'శాశ్వతంగా తొలగించబడేవి:' : 'Permanently Purged:',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                isTelugu
                    ? '• లాగిన్ సెషన్‌లు & పుష్ టోకెన్‌లు\n• బుక్‌మార్క్‌లు మరియు చదివిన వార్తల చరిత్ర\n• ప్రొఫైల్ ఫోటో, వ్యక్తిగత పేరు మరియు పాస్‌వర్డ్\n• సిటిజన్ జర్నలిస్ట్ ప్రొఫైల్ మరియు ధృవీకరించిన మొబైల్ నంబర్'
                    : '• Device sessions & active push tokens\n• Bookmarks & reading history\n• Profile photo, personal name & credentials\n• UGC reporter profile & verified phone number',
                style: TextStyle(fontSize: 12, height: 1.4, color: isDark ? Colors.white70 : Colors.black87),
              ),
              const SizedBox(height: 10),
              Text(
                isTelugu ? 'గుర్తింపు లేకుండా భద్రపరచబడేవి (Anonymised):' : 'Retained with Identity Detached (Anonymised):',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                isTelugu
                    ? '• ప్రచురితమైన పబ్లిక్ వార్తలు & వ్యాఖ్యలు (వార్తా చరిత్ర భద్రత కొరకు ఉంచబడతాయి, కానీ మీ ఫోన్ నంబర్ మరియు గుర్తింపు పూర్తిగా తొలగించబడతాయి)\n• చట్టపరమైన ఆడిట్ కొరకు రివార్డ్ లావాదేవీల రికార్డులు (వ్యక్తిగత వివరాలు స్క్రబ్ చేయబడతాయి)'
                    : '• Published news items & comments (preserved for public news archive, with all author phone/identity scrubbed)\n• Reward wallet transaction audit logs (retained anonymously for legal financial audit)',
                style: TextStyle(fontSize: 12, height: 1.4, color: isDark ? Colors.white70 : Colors.black87),
              ),
              const SizedBox(height: 10),
              Text(
                isTelugu
                    ? 'గమనిక: అభ్యర్థన తక్షణమే తొలగించబడదు. మానవ అడ్మిన్ పరిశీలన తర్వాత మాత్రమే ఆమోదించబడుతుంది.'
                    : 'Note: Deletion is admin-reviewed to check pending reward payouts and news items before processing.',
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: isDark ? Colors.amber[300] : Colors.orange[900],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Reason Dropdown
        Text(
          isTelugu ? 'తొలగించడానికి కారణం (Reason)' : 'Reason for Deletion',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF242424) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.12),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedReason,
              isExpanded: true,
              dropdownColor: isDark ? const Color(0xFF242424) : Colors.white,
              items: AccountDeletionRequest.reasonOptions.map((opt) {
                return DropdownMenuItem<String>(
                  value: opt.code,
                  child: Text(
                    isTelugu ? opt.titleTe : opt.titleEn,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedReason = val);
              },
            ),
          ),
        ),

        const SizedBox(height: 18),

        // Notes Text Area
        Text(
          isTelugu ? 'అదనపు వివరాలు (ఐచ్ఛికం - Notes)' : 'Additional Feedback or Notes (Optional)',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _notesController,
          maxLines: 3,
          maxLength: 1000,
          decoration: InputDecoration(
            hintText: isTelugu
                ? 'మేము ఎలా మెరుగుపరుచుకోవచ్చో తెలపండి...'
                : 'Help us improve by telling us more...',
            hintStyle: TextStyle(fontSize: 13, color: isDark ? Colors.white38 : Colors.black38),
            filled: true,
            fillColor: isDark ? const Color(0xFF242424) : Colors.white,
            contentPadding: const EdgeInsets.all(14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.12),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.12),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Mandatory Confirmation Checkbox
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _isAcknowledged,
          activeColor: Colors.red,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(
            isTelugu
                ? 'ఈ అభ్యర్థన అడ్మిన్ సమీక్షకు లోబడి ఉంటుందని, ఆమోదం పొందిన తర్వాత నా ఖాతా మరియు వ్యక్తిగత డేటా శాశ్వతంగా తొలగించబడుతుందని నేను అర్థం చేసుకున్నాను.'
                : 'I understand this request is subject to review and upon approval my account and personal data will be permanently anonymised and purged.',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          onChanged: (val) {
            setState(() => _isAcknowledged = val ?? false);
          },
        ),

        const SizedBox(height: 24),

        // Submit Button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _isAcknowledged ? Colors.red : Colors.grey[700],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: _isAcknowledged ? 2 : 0,
            ),
            onPressed: (_isAcknowledged && !_isSubmitting) ? _submitDeletionRequest : null,
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                  )
                : Text(
                    isTelugu ? 'ఖాతా తొలగింపు అభ్యర్థనను సమర్పించండి' : 'Submit Deletion Request',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
          ),
        ),

        const SizedBox(height: 32),
      ],
    );
  }
}
