import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/ad_package.dart';
import '../services/api_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

/// Ad booking. Everything offered comes from the backend: the areas
/// (GET /ads/areas/) and every bookable package with its price
/// (GET /ads/pricing/options/). The app has no durations of its own — an
/// area or ad type without a priced package is simply not offered.
class AdBookingScreen extends StatefulWidget {
  /// For tests; the screen loads from [ApiService] otherwise.
  final Future<List<dynamic>> Function()? areasLoader;
  final Future<dynamic> Function()? optionsLoader;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>)? submitter;

  const AdBookingScreen({
    super.key,
    this.areasLoader,
    this.optionsLoader,
    this.submitter,
  });

  @override
  State<AdBookingScreen> createState() => _AdBookingScreenState();
}

class _AdBookingScreenState extends State<AdBookingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _businessController = TextEditingController();
  final _messageController = TextEditingController();
  late final _nameController = TextEditingController(
    text: AppState.instance.userName == 'Guest User'
        ? ''
        : AppState.instance.userName,
  );
  late final _phoneController =
      TextEditingController(text: AppState.instance.userPhone);

  String _adType = 'local'; // 'local' or 'main'

  bool _loading = true;
  bool _loadFailed = false;
  bool _isSubmitting = false;
  String? _error;

  AdPricingCatalog? _catalog;

  /// The package the advertiser picked — area, duration and price, all as
  /// the backend sent them.
  AdPackage? _selected;

  // Populated after successful booking submission
  Map<String, dynamic>? _bookingSuccessData;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  @override
  void dispose() {
    _businessController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
      _error = null;
    });
    try {
      final results = await Future.wait<dynamic>([
        (widget.areasLoader ?? ApiService.instance.getAdAreas)()
            .catchError((_) => <dynamic>[]),
        (widget.optionsLoader ?? ApiService.instance.getAdPricingOptions)(),
      ]);
      final catalog = AdPricingCatalog.parse(results[1],
          areas: results[0] as List<dynamic>);
      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        _loading = false;
        // Open on a type that actually has packages.
        if (catalog.localByArea.isEmpty && catalog.main.isNotEmpty) {
          _adType = 'main';
        }
        _selected = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  void _selectType(String type) {
    if (_adType == type) return;
    setState(() {
      _adType = type;
      _selected = null;
      _error = null;
    });
  }

  void _selectPackage(AdPackage p) {
    HapticFeedback.selectionClick();
    setState(() {
      _adType = p.adType;
      _selected = p;
      _error = null;
    });
  }

  Future<void> _submitBooking() async {
    if (_isSubmitting) return;
    final pkg = _selected;
    if (pkg == null) {
      setState(() => _error = 'దయచేసి ఒక ప్యాకేజీని ఎంచుకోండి.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final payload = {
        'advertiser_name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'business_name': _businessController.text.trim(),
        'ad_type': pkg.adType,
        'duration_days': pkg.durationDays,
        // Backend contract: the package's area for local, null for main.
        'area_id': pkg.adType == 'local' ? pkg.areaId : null,
        if (_messageController.text.trim().isNotEmpty)
          'message': _messageController.text.trim(),
      };

      final responseData = await (widget.submitter ??
          ApiService.instance.submitAdBooking)(payload);

      if (mounted) {
        HapticFeedback.heavyImpact();
        setState(() {
          _bookingSuccessData = responseData;
          _isSubmitting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error =
              'బుకింగ్ అభ్యర్థన సమర్పించడంలో విఫలమైంది. దయచేసి నెట్‌వర్క్ తనిఖీ చేసి మళ్లీ ప్రయత్నించండి.';
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _launchWhatsApp(String? rawUrl) async {
    HapticFeedback.lightImpact();
    if (rawUrl != null && rawUrl.isNotEmpty) {
      final uri = Uri.tryParse(rawUrl);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }

    // Production-safe fallback
    const String phone = "916281732036";
    final pkg = _selected;
    final String text = Uri.encodeComponent(
      "Hello, I want to advertise on Vaaradhi"
      "${_businessController.text.trim().isNotEmpty ? " for '${_businessController.text.trim()}'" : ''}. "
      "${_bookingSuccessData?['id'] != null ? 'Ref: ${_bookingSuccessData!['id']}. ' : ''}"
      "${pkg != null ? 'Ad Type: ${pkg.adType}${pkg.areaName != null ? ' (${pkg.areaName})' : ''}, Duration: ${pkg.durationDays} days, Price: ${pkg.priceLabel}.' : ''}",
    );
    final Uri waUri = Uri.parse("https://wa.me/$phone?text=$text");
    if (await canLaunchUrl(waUri)) {
      await launchUrl(waUri, mode: LaunchMode.externalApplication);
    } else {
      final Uri fallbackUri =
          Uri.parse("https://api.whatsapp.com/send?phone=$phone&text=$text");
      if (await canLaunchUrl(fallbackUri)) {
        await launchUrl(fallbackUri, mode: LaunchMode.inAppBrowserView);
      }
    }
  }

  // --- Step 1: Main vs Local ------------------------------------------------

  Widget _buildAdTypeSelector(bool isDark) {
    final catalog = _catalog;
    final mainCount = catalog?.main.length ?? 0;
    final localCount = catalog?.localByArea.length ?? 0;
    return Row(
      children: [
        Expanded(
          child: _typeCard(
            key: const Key('ad_type_main'),
            isDark: isDark,
            selected: _adType == 'main',
            enabled: mainCount > 0,
            icon: Icons.public_rounded,
            title: 'రాష్ట్రవ్యాప్తంగా',
            subtitle: mainCount > 0
                ? '$mainCount ప్యాకేజీలు'
                : 'ప్రస్తుతం అందుబాటులో లేదు',
            onTap: () => _selectType('main'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _typeCard(
            key: const Key('ad_type_local'),
            isDark: isDark,
            selected: _adType == 'local',
            enabled: localCount > 0,
            icon: Icons.location_city_rounded,
            title: 'స్థానిక ప్రాంతం',
            subtitle: localCount > 0
                ? '$localCount ప్రాంతాలు'
                : 'ప్రస్తుతం అందుబాటులో లేదు',
            onTap: () => _selectType('local'),
          ),
        ),
      ],
    );
  }

  Widget _typeCard({
    required Key key,
    required bool isDark,
    required bool selected,
    required bool enabled,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final active = selected && enabled;
    return Opacity(
      key: key,
      opacity: enabled ? 1 : 0.5,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          decoration: BoxDecoration(
            color: active
                ? AppColors.primary.withValues(alpha: 0.12)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.grey.shade100),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: active ? AppColors.primary : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon,
                      color: active ? AppColors.primary : Colors.grey,
                      size: 22),
                  if (active)
                    const Icon(Icons.check_circle_rounded,
                        color: AppColors.primary, size: 18),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: active ? AppColors.primary : null,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Step 2: packages, exactly as the backend prices them --------------

  Widget _packageChip(AdPackage p, bool isDark) {
    final selected = p.sameAs(_selected);
    final hint = p.durationHint;
    return InkWell(
      key: Key('ad_pkg_${p.adType}_${p.areaId ?? 'main'}_${p.durationDays}'),
      onTap: () => _selectPackage(p),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : (isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.white),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : (isDark ? Colors.white24 : Colors.grey.shade300),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              p.durationLabel,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: selected
                    ? Colors.white
                    : (isDark ? Colors.white : Colors.black87),
              ),
            ),
            if (hint != null)
              Text(
                hint,
                style: TextStyle(
                    fontSize: 11,
                    color: selected ? Colors.white70 : Colors.grey),
              ),
            const SizedBox(height: 4),
            Text(
              p.priceLabel,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 15,
                color: selected ? Colors.white : AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPackages(bool isDark) {
    final catalog = _catalog!;
    if (_adType == 'main') {
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [for (final p in catalog.main) _packageChip(p, isDark)],
      );
    }
    return Column(
      children: [
        for (final entry in catalog.localByArea.entries)
          Container(
            key: Key('ad_area_${entry.key}'),
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _selected?.areaId == entry.key
                    ? AppColors.primary
                    : (isDark ? Colors.white12 : Colors.grey.shade200),
                width: _selected?.areaId == entry.key ? 1.6 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 18, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        catalog.areaNames[entry.key]?.isNotEmpty == true
                            ? catalog.areaNames[entry.key]!
                            : (entry.value.first.areaName ?? 'ప్రాంతం'),
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final p in entry.value) _packageChip(p, isDark)
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// No packages to offer (endpoint not live, nothing priced, or offline).
  Widget _buildUnavailable(bool isDark) {
    return Container(
      key: const Key('ad_packages_unavailable'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _loadFailed
                ? 'ప్రకటన ప్యాకేజీలను లోడ్ చేయడంలో విఫలమైంది. మళ్లీ ప్రయత్నించండి.'
                : 'ప్రస్తుతం ప్రకటన ప్యాకేజీలు అందుబాటులో లేవు. వివరాల కోసం WhatsApp ద్వారా సంప్రదించండి.',
            style: const TextStyle(fontSize: 13.5, height: 1.4),
          ),
          const SizedBox(height: 12),
          Wrap(
            children: [
              if (_loadFailed)
                TextButton.icon(
                  onPressed: _loadCatalog,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('మళ్లీ ప్రయత్నించండి'),
                ),
              TextButton.icon(
                onPressed: () => _launchWhatsApp(null),
                icon: const Icon(Icons.chat_bubble_rounded,
                    size: 18, color: Color(0xFF25D366)),
                label: const Text('WhatsApp'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Success ---------------------------------------------------------------

  Widget _buildSuccessScreen(bool isDark) {
    final data = _bookingSuccessData ?? {};
    final pkg = _selected;
    final bookingId = data['id']?.toString() ?? 'Pending';
    final price = data['quoted_price']?.toString();
    final currency = data['currency']?.toString();
    final priceText = price != null && currency != null
        ? AdPackage(
                adType: pkg?.adType ?? _adType,
                durationDays: pkg?.durationDays ?? 0,
                price: price,
                currency: currency)
            .priceLabel
        : pkg?.priceLabel;
    final whatsappUrl = data['whatsapp_url']?.toString();

    final areaName = pkg?.adType == 'local'
        ? (pkg?.areaName ??
            _catalog?.areaNames[pkg?.areaId] ??
            'స్థానిక ప్రాంతం')
        : 'రాష్ట్రవ్యాప్తంగా (అన్ని ఫీడ్‌లు)';

    return Scaffold(
      appBar: AppBar(
        title: const Text('బుకింగ్ స్వీకరించబడింది'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 16),
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  border: Border.all(color: const Color(0xFF10B981), width: 3),
                ),
                child: const Center(
                  child: Icon(Icons.check_rounded,
                      color: Color(0xFF10B981), size: 48),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'ప్రకటన బుకింగ్ సమర్పించబడింది!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                'మీ అభ్యర్థన నమోదు చేయబడింది. మీ బ్యానర్లు సమర్పించడానికి మరియు షెడ్యూల్‌ను ఖరారు చేయడానికి నేరుగా WhatsApp లో సంప్రదించండి.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white70 : Colors.black54,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? Colors.white12 : Colors.grey.shade200,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Flexible(
                          child: Text(
                            'అంచనా వేసిన ధర',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.grey),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'పరిశీలనలో ఉంది',
                            style: TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      priceText ?? 'ధర నిర్ధారణ కోసం వేచి ఉంది',
                      style: TextStyle(
                        fontSize: priceText != null ? 28 : 16,
                        fontWeight: FontWeight.w900,
                        color: priceText != null
                            ? AppColors.primary
                            : Colors.orange,
                      ),
                    ),
                    const Divider(height: 28),
                    _buildDetailRow('రిఫరెన్స్ ఐడీ',
                        '#${bookingId.length > 8 ? bookingId.substring(0, 8) : bookingId}'),
                    const SizedBox(height: 10),
                    _buildDetailRow(
                        'వ్యాపారం', _businessController.text.trim()),
                    const SizedBox(height: 10),
                    _buildDetailRow('ప్రకటన పరిధి', areaName),
                    const SizedBox(height: 10),
                    _buildDetailRow('కాలపరిమితి', pkg?.durationLabel ?? '-'),
                    const SizedBox(height: 10),
                    _buildDetailRow(
                        'సంప్రదింపు నంబర్', _phoneController.text.trim()),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.chat_bubble_rounded, size: 22),
                  label: const Text(
                    'WhatsApp లో చాట్ చేయండి',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 2,
                  ),
                  onPressed: () => _launchWhatsApp(whatsappUrl),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'పూర్తయింది',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String title, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  InputDecoration _fieldDecoration(bool isDark,
          {required String label, required String hint, required IconData icon}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor:
            isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none),
      );

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_bookingSuccessData != null) {
      return _buildSuccessScreen(isDark);
    }

    final catalog = _catalog;
    final hasPackages = catalog != null && !catalog.isEmpty;
    final selected = _selected;

    return Scaffold(
      appBar: AppBar(
        title: const Text('మాతో ప్రకటనలు ఇవ్వండి'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'మీ వ్యాపారాన్ని విస్తరించండి',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                'మీ బ్రాండ్‌ను నేరుగా స్థానిక మరియు రాష్ట్రవ్యాప్త పాఠకులకు చేరవేయడానికి వారధిలో ప్రకటనలు ఇవ్వండి.',
                style: TextStyle(
                    color: isDark ? Colors.white60 : Colors.black54,
                    fontSize: 14),
              ),
              const SizedBox(height: 24),

              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Row(
                    children: [
                      SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text('ప్రకటన ప్యాకేజీలను లోడ్ చేస్తోంది...',
                          style: TextStyle(color: Colors.grey)),
                      ),
                    ],
                  ),
                )
              else if (!hasPackages)
                _buildUnavailable(isDark)
              else ...[
                // 1. Main vs Local
                const Text(
                  '1. ప్రకటన స్థానాన్ని ఎంచుకోండి',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                const SizedBox(height: 10),
                _buildAdTypeSelector(isDark),
                const SizedBox(height: 20),

                // 2. Package (area + duration + price)
                Text(
                  _adType == 'local'
                      ? '2. ప్రాంతం & ప్యాకేజీని ఎంచుకోండి'
                      : '2. ప్యాకేజీని ఎంచుకోండి',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 15),
                ),
                const SizedBox(height: 10),
                _buildPackages(isDark),
                const SizedBox(height: 12),

                // Selected package summary
                Container(
                  key: const Key('ad_selected_summary'),
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('ఎంచుకున్న ప్యాకేజీ',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14)),
                            const SizedBox(height: 2),
                            Text(
                              selected == null
                                  ? 'పైన ఒక ప్యాకేజీని ఎంచుకోండి'
                                  : '${selected.adType == 'local' ? (selected.areaName ?? catalog.areaNames[selected.areaId] ?? '') : 'రాష్ట్రవ్యాప్తంగా'} · ${selected.durationLabel}',
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        selected?.priceLabel ?? '—',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                          fontSize: 20,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 3. Advertiser details
                const Text(
                  '3. ప్రకటనదారు వివరాలు',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _businessController,
                  decoration: _fieldDecoration(isDark,
                      label: 'వ్యాపారం / బ్రాండ్ పేరు',
                      hint: 'ఉదా. రవి మొబైల్స్',
                      icon: Icons.storefront_rounded),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'మీ వ్యాపారం పేరు నమోదు చేయండి';
                    }
                    if (v.trim().length < 2) {
                      return 'సరైన వ్యాపారం పేరు నమోదు చేయండి';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _nameController,
                  decoration: _fieldDecoration(isDark,
                      label: 'సంప్రదించవలసిన వ్యక్తి పేరు',
                      hint: 'ఉదా. రమేష్',
                      icon: Icons.person_outline_rounded),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'సంప్రదించవలసిన వ్యక్తి పేరు నమోదు చేయండి';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: _fieldDecoration(isDark,
                      label: 'ఫోన్ / WhatsApp నంబర్',
                      hint: 'ఉదా. 9876543210',
                      icon: Icons.phone_outlined),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'ఫోన్ నంబర్ నమోదు చేయండి';
                    }
                    if (v.trim().length < 10) {
                      return 'సరైన 10 అంకెల ఫోన్ నంబర్ నమోదు చేయండి';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _messageController,
                  maxLines: 2,
                  decoration: _fieldDecoration(isDark,
                      label: 'ప్రత్యేక వివరాలు / సూచనలు (ఐచ్ఛికం)',
                      hint: 'ఉదా. పండుగ ప్రత్యేక బ్యానర్',
                      icon: Icons.notes_rounded),
                ),
                const SizedBox(height: 16),

                if (_error != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: Colors.red.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            color: Colors.redAccent, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_error!,
                              style: const TextStyle(
                                  color: Colors.redAccent, fontSize: 13)),
                        ),
                      ],
                    ),
                  ),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    key: const Key('ad_book_submit'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    onPressed: (_isSubmitting || selected == null)
                        ? null
                        : _submitBooking,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Text(
                            'బుకింగ్ అభ్యర్థనను సమర్పించండి',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}
