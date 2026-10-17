import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/ad_package.dart';
import '../services/api_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

/// Ad booking (POST /api/v1/ads/bookings/). Everything offered comes from
/// GET /api/v1/ads/pricing/options/: the coverage scopes (global / state /
/// local), each scope's areas, every duration with its price, and the ad
/// formats. Nothing is hard-coded — a scope, area or format the backend does
/// not price is simply not offered.
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

  String _scope = AdScope.local;
  String? _format;
  String? _areaId;

  /// The duration/price the advertiser picked, as the backend sent it.
  AdPackage? _selected;

  bool _loading = true;
  bool _loadFailed = false;
  bool _isSubmitting = false;
  AdBookingError? _error;

  AdPricingCatalog? _catalog;

  // Populated after a successful booking.
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

  /// Loads the options. On a reload ([keepChoices]) the picks that still
  /// exist are kept; the form fields are never touched.
  Future<void> _loadCatalog({bool keepChoices = false}) async {
    setState(() {
      _loading = true;
      _loadFailed = false;
      if (!keepChoices) _error = null;
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
        // Open on a scope that actually has packages.
        if (!catalog.offers(_scope)) {
          _scope = AdScope.all
              .firstWhere(catalog.offers, orElse: () => AdScope.local);
        }
        if (_format != null &&
            !catalog.formats.any((f) => f.value == _format)) {
          _format = null;
        }
        _format ??=
            catalog.formats.length == 1 ? catalog.formats.first.value : null;
        final areas = catalog.areasFor(_scope);
        if (_areaId != null && !areas.containsKey(_areaId)) _areaId = null;
        // Nothing to choose between when only one area is priced.
        _areaId ??= areas.length == 1 ? areas.keys.first : null;
        final sel = _selected;
        final still = sel == null
            ? null
            : _packagesFor(catalog).where(sel.sameAs).firstOrNull;
        _selected = keepChoices ? still : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  /// The duration/price options for the current scope and area.
  List<AdPackage> _packagesFor(AdPricingCatalog c) {
    if (_scope == AdScope.global) return c.global;
    final id = _areaId;
    return id == null ? const [] : (c.areasFor(_scope)[id] ?? const []);
  }

  void _selectScope(String scope) {
    if (_scope == scope) return;
    HapticFeedback.selectionClick();
    final areas = _catalog?.areasFor(scope) ?? const {};
    setState(() {
      _scope = scope;
      _areaId = areas.length == 1 ? areas.keys.first : null;
      _selected = null;
      _error = null;
    });
  }

  void _selectPackage(AdPackage p) {
    HapticFeedback.selectionClick();
    setState(() {
      _selected = p;
      _error = null;
    });
  }

  String? _fieldError(String field) => _error?.fields[field];

  Future<void> _submitBooking() async {
    if (_isSubmitting) return;
    final pkg = _selected;
    final catalog = _catalog;
    final needsFormat = catalog != null && catalog.formats.isNotEmpty;
    final missing = <String, String>{
      if (needsFormat && _format == null)
        'ad_format': 'ప్రకటన రకాన్ని ఎంచుకోండి.',
      if (_scope != AdScope.global && _areaId == null)
        'area_id': 'ప్రాంతాన్ని ఎంచుకోండి.',
      if (pkg == null) 'duration_days': 'కాలపరిమితి & ధరను ఎంచుకోండి.',
    };
    final formOk = _formKey.currentState!.validate();
    if (missing.isNotEmpty) {
      setState(() => _error =
          AdBookingError(fields: missing, message: missing.values.join('\n')));
      return;
    }
    if (!formOk) return;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    final payload = <String, dynamic>{
      'advertiser_name': _nameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'business_name': _businessController.text.trim(),
      'scope': _scope,
      if (_format != null) 'ad_format': _format,
      // Never sent for global.
      if (_scope != AdScope.global) 'area_id': pkg!.areaId,
      'duration_days': pkg!.durationDays,
      if (_messageController.text.trim().isNotEmpty)
        'message': _messageController.text.trim(),
    };

    try {
      final responseData = await (widget.submitter ??
          ApiService.instance.submitAdBooking)(payload);
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      setState(() {
        _bookingSuccessData = responseData;
        _isSubmitting = false;
      });
    } catch (e) {
      if (!mounted) return;
      final error = e is DioException
          ? AdBookingError.from(
              e.type == DioExceptionType.badResponse
                  ? e.response?.statusCode
                  : null,
              e.response?.data)
          : const AdBookingError(
              message: 'బుకింగ్ సమర్పించలేకపోయాం. మళ్లీ ప్రయత్నించండి.',
              retryable: true);
      // Everything typed stays in the form.
      setState(() {
        _error = error;
        _isSubmitting = false;
      });
      if (error.refreshOptions) {
        await _loadCatalog(keepChoices: true);
        if (mounted) setState(() => _error = error);
      }
    }
  }

  Future<void> _launchWhatsApp(String rawUrl) async {
    HapticFeedback.lightImpact();
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    }
  }

  // --- Labels ---------------------------------------------------------------

  static String scopeTitle(String scope) => switch (scope) {
        AdScope.global => 'అన్ని ప్రాంతాలు',
        AdScope.state => 'రాష్ట్రం',
        _ => 'స్థానికం',
      };

  static String scopeSubtitle(String scope) => switch (scope) {
        AdScope.global => 'యాప్ అంతటా',
        AdScope.state => 'ఒక రాష్ట్రమంతా',
        _ => 'జిల్లా / మండలం / గ్రామం',
      };

  static IconData scopeIcon(String scope) => switch (scope) {
        AdScope.global => Icons.public_rounded,
        AdScope.state => Icons.map_outlined,
        _ => Icons.location_city_rounded,
      };

  String _formatLabel(String? value) {
    if (value == null) return '-';
    return _catalog?.formats
            .where((f) => f.value == value)
            .map((f) => f.label)
            .firstOrNull ??
        value;
  }

  String _areaName(AdPricingCatalog catalog, String id) {
    final name = catalog.areaNames[id];
    if (name != null && name.isNotEmpty) return name;
    return catalog.areasFor(_scope)[id]?.first.areaName ?? 'ప్రాంతం';
  }

  // --- Step 1: scope ----------------------------------------------------------

  Widget _buildScopeSelector(AdPricingCatalog catalog, bool isDark) {
    return Row(
      children: [
        for (final s in AdScope.all) ...[
          if (s != AdScope.global) const SizedBox(width: 8),
          Expanded(
            child: _scopeCard(
              key: Key('ad_scope_$s'),
              isDark: isDark,
              selected: _scope == s,
              enabled: catalog.offers(s),
              icon: scopeIcon(s),
              title: scopeTitle(s),
              subtitle: catalog.offers(s)
                  ? scopeSubtitle(s)
                  : 'ప్రస్తుతం అందుబాటులో లేదు',
              onTap: () => _selectScope(s),
            ),
          ),
        ],
      ],
    );
  }

  Widget _scopeCard({
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
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
              const SizedBox(height: 8),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: active ? AppColors.primary : null,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 2,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.3,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Dropdowns --------------------------------------------------------------

  InputDecoration _dropdownDecoration(bool isDark,
          {required String label, required IconData icon, String? errorText}) =>
      InputDecoration(
        labelText: label,
        errorText: errorText,
        errorMaxLines: 3,
        prefixIcon: Icon(icon, color: AppColors.primary),
        filled: true,
        fillColor:
            isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
        ),
      );

  Widget _buildFormatDropdown(AdPricingCatalog catalog, bool isDark) {
    return DropdownButtonFormField<String>(
      key: const Key('ad_format_dropdown'),
      initialValue: _format,
      isExpanded: true,
      menuMaxHeight: 420,
      borderRadius: BorderRadius.circular(14),
      icon: const Icon(Icons.keyboard_arrow_down_rounded),
      decoration: _dropdownDecoration(isDark,
          label: 'ప్రకటన రకం',
          icon: Icons.view_quilt_outlined,
          errorText: _fieldError('ad_format')),
      items: [
        for (final f in catalog.formats)
          DropdownMenuItem<String>(
            key: Key('ad_format_option_${f.value}'),
            value: f.value,
            child: Text(f.label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
      ],
      onChanged: (v) {
        if (v == null) return;
        HapticFeedback.selectionClick();
        setState(() {
          _format = v;
          _error = null;
        });
      },
    );
  }

  /// One dropdown of the scope's priced areas; each shows its lowest price.
  Widget _buildAreaDropdown(AdPricingCatalog catalog, bool isDark) {
    final areas = catalog.areasFor(_scope);
    return DropdownButtonFormField<String>(
      // A new key per scope, so switching scope resets the field.
      key: Key('ad_area_dropdown_$_scope'),
      initialValue: _areaId,
      isExpanded: true,
      menuMaxHeight: 420,
      borderRadius: BorderRadius.circular(14),
      icon: const Icon(Icons.keyboard_arrow_down_rounded),
      decoration: _dropdownDecoration(isDark,
          label: _scope == AdScope.state
              ? 'రాష్ట్రాన్ని ఎంచుకోండి'
              : 'ప్రాంతాన్ని ఎంచుకోండి',
          icon: Icons.location_on_outlined,
          errorText: _fieldError('area_id')),
      items: [
        for (final id in areas.keys)
          DropdownMenuItem<String>(
            key: Key('ad_area_option_$id'),
            value: id,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _areaName(catalog, id),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _fromPrice(areas[id]!),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
      ],
      onChanged: (id) {
        if (id == null || id == _areaId) return;
        HapticFeedback.selectionClick();
        setState(() {
          _areaId = id;
          // A package from another area no longer applies.
          if (_selected?.areaId != id) _selected = null;
          _error = null;
        });
      },
    );
  }

  /// "₹1500" for a single package, "₹1500 నుండి" when there are several.
  String _fromPrice(List<AdPackage> packages) {
    double amount(AdPackage p) => double.tryParse(p.price.trim()) ?? 0;
    final cheapest = packages.reduce((a, b) => amount(a) <= amount(b) ? a : b);
    return packages.length == 1
        ? cheapest.priceLabel
        : '${cheapest.priceLabel} నుండి';
  }

  // --- Duration & price -----------------------------------------------------

  Widget _packageChip(AdPackage p, bool isDark) {
    final selected = p.sameAs(_selected);
    final hint = p.durationHint;
    return InkWell(
      key: Key('ad_pkg_${p.scope}_${p.areaId ?? 'all'}_${p.durationDays}'),
      onTap: () => _selectPackage(p),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white),
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

  Widget _buildPackages(AdPricingCatalog catalog, bool isDark) {
    final packages = _packagesFor(catalog);
    if (packages.isEmpty) {
      return Text(
        'ముందు ${_scope == AdScope.state ? 'రాష్ట్రాన్ని' : 'ప్రాంతాన్ని'} ఎంచుకోండి — దాని ధరలు ఇక్కడ కనిపిస్తాయి.',
        style: const TextStyle(color: Colors.grey, fontSize: 13),
      );
    }
    final err = _fieldError('duration_days');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          key: Key('ad_packages_${_scope}_${_areaId ?? 'all'}'),
          spacing: 10,
          runSpacing: 10,
          children: [for (final p in packages) _packageChip(p, isDark)],
        ),
        if (err != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(err,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
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
                : 'ప్రస్తుతం ప్రకటన ప్యాకేజీలు అందుబాటులో లేవు. దయచేసి కొద్దిసేపటి తర్వాత మళ్లీ చూడండి.',
            style: const TextStyle(fontSize: 13.5, height: 1.4),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _loadCatalog,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('మళ్లీ ప్రయత్నించండి'),
          ),
        ],
      ),
    );
  }

  // --- Success ---------------------------------------------------------------

  Widget _buildSuccessScreen(bool isDark) {
    final data = _bookingSuccessData ?? {};
    final pkg = _selected;
    final bookingId = data['id']?.toString() ?? '-';
    final price = data['quoted_price']?.toString();
    final currency = data['currency']?.toString() ?? pkg?.currency ?? 'INR';
    final priceText = price != null && price.isNotEmpty
        ? AdPackage.formatPrice(price, currency)
        : pkg?.priceLabel;
    final whatsappUrl = data['whatsapp_url']?.toString() ?? '';
    final scope = AdScope.normalize((data['scope'] ?? _scope).toString());
    final area = data['area'];
    final areaName = scope == AdScope.global
        ? scopeTitle(AdScope.global)
        : ((area is Map ? area['name']?.toString() : null) ??
            pkg?.areaName ??
            _catalog?.areaNames[pkg?.areaId] ??
            scopeTitle(scope));
    final days = data['duration_days'] ?? pkg?.durationDays;
    final format = _formatLabel((data['ad_format'] ?? _format)?.toString());

    return Scaffold(
      appBar: AppBar(
        title: const Text('బుకింగ్ స్వీకరించబడింది'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
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
                'మీ అభ్యర్థన నమోదైంది. అడ్మిన్ ఆమోదించిన తర్వాతే మీ ప్రకటన ప్రచురించబడుతుంది.',
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
                            'కోట్ చేసిన ధర',
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
                            'ఆమోదం కోసం వేచి ఉంది',
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
                      key: const Key('ad_booking_quoted_price'),
                      style: TextStyle(
                        fontSize: priceText != null ? 28 : 16,
                        fontWeight: FontWeight.w900,
                        color: priceText != null
                            ? AppColors.primary
                            : Colors.orange,
                      ),
                    ),
                    const Divider(height: 28),
                    _buildDetailRow('బుకింగ్ ఐడీ', bookingId,
                        key: const Key('ad_booking_id'), copyable: true),
                    const SizedBox(height: 10),
                    _buildDetailRow(
                        'వ్యాపారం', _businessController.text.trim()),
                    const SizedBox(height: 10),
                    _buildDetailRow('ప్రకటన పరిధి', areaName),
                    const SizedBox(height: 10),
                    _buildDetailRow('ప్రకటన రకం', format),
                    const SizedBox(height: 10),
                    _buildDetailRow(
                        'కాలపరిమితి', days != null ? '$days రోజులు' : '-'),
                    const SizedBox(height: 10),
                    _buildDetailRow(
                        'సంప్రదింపు నంబర్', _phoneController.text.trim()),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              if (whatsappUrl.isNotEmpty) ...[
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    key: const Key('ad_booking_whatsapp'),
                    icon: const Icon(Icons.chat_bubble_rounded, size: 22),
                    label: const Text(
                      'WhatsApp లో కొనసాగించండి',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
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
              ],
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

  Widget _buildDetailRow(String title, String value,
      {Key? key, bool copyable = false}) {
    return Row(
      key: key,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        const SizedBox(width: 12),
        Flexible(
          child: GestureDetector(
            onLongPress: copyable
                ? () {
                    Clipboard.setData(ClipboardData(text: value));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      behavior: SnackBarBehavior.floating,
                      content: Text('బుకింగ్ ఐడీ కాపీ చేయబడింది'),
                    ));
                  }
                : null,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              overflow: TextOverflow.ellipsis,
              maxLines: copyable ? 2 : 1,
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _fieldDecoration(bool isDark,
          {required String label,
          required String hint,
          required IconData icon,
          String? errorText}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: errorText,
        errorMaxLines: 3,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.grey.shade100,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none),
      );

  Widget _stepTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
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
    final error = _error;
    var step = 0;
    String next(String title) => '${++step}. $title';

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
                'మీ బ్రాండ్‌ను నేరుగా స్థానిక, రాష్ట్ర మరియు అన్ని ప్రాంతాల పాఠకులకు చేరవేయడానికి వారధిలో ప్రకటనలు ఇవ్వండి.',
                style: TextStyle(
                    color: isDark ? Colors.white60 : Colors.black54,
                    fontSize: 14),
              ),
              const SizedBox(height: 24),
              if (_loading && catalog == null)
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
                // Coverage: global / state / local
                _stepTitle(next('ప్రకటన పరిధిని ఎంచుకోండి')),
                _buildScopeSelector(catalog, isDark),
                if (_fieldError('scope') != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, left: 4),
                    child: Text(_fieldError('scope')!,
                        style: const TextStyle(
                            color: Colors.redAccent, fontSize: 12)),
                  ),
                const SizedBox(height: 20),

                // Ad format
                if (catalog.formats.isNotEmpty) ...[
                  _stepTitle(next('ప్రకటన రకాన్ని ఎంచుకోండి')),
                  _buildFormatDropdown(catalog, isDark),
                  const SizedBox(height: 20),
                ],

                // Area — state or local only
                if (_scope != AdScope.global) ...[
                  _stepTitle(next(_scope == AdScope.state
                      ? 'రాష్ట్రాన్ని ఎంచుకోండి'
                      : 'ప్రాంతాన్ని ఎంచుకోండి')),
                  _buildAreaDropdown(catalog, isDark),
                  const SizedBox(height: 20),
                ],

                // Duration & price of the chosen area
                _stepTitle(next('కాలపరిమితి & ధర')),
                _buildPackages(catalog, isDark),
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
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('ఎంచుకున్న ప్యాకేజీ',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 2),
                            Text(
                              selected == null
                                  ? 'పైన కాలపరిమితిని ఎంచుకోండి'
                                  : [
                                      selected.needsArea
                                          ? _areaName(
                                              catalog, selected.areaId ?? '')
                                          : scopeTitle(AdScope.global),
                                      if (_format != null)
                                        _formatLabel(_format),
                                      selected.durationLabel,
                                    ].join(' · '),
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

                // Advertiser details
                _stepTitle(next('ప్రకటనదారు వివరాలు')),
                TextFormField(
                  controller: _businessController,
                  decoration: _fieldDecoration(isDark,
                      label: 'వ్యాపారం / బ్రాండ్ పేరు (ఐచ్ఛికం)',
                      hint: 'ఉదా. రవి మొబైల్స్',
                      icon: Icons.storefront_rounded,
                      errorText: _fieldError('business_name')),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _nameController,
                  decoration: _fieldDecoration(isDark,
                      label: 'మీ పేరు *',
                      hint: 'ఉదా. రమేష్',
                      icon: Icons.person_outline_rounded,
                      errorText: _fieldError('advertiser_name')),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'మీ పేరు నమోదు చేయండి'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: _fieldDecoration(isDark,
                      label: 'ఫోన్ / WhatsApp నంబర్ *',
                      hint: 'ఉదా. 9876543210',
                      icon: Icons.phone_outlined,
                      errorText: _fieldError('phone')),
                  validator: (v) {
                    final t = v?.trim() ?? '';
                    if (t.isEmpty) return 'ఫోన్ నంబర్ నమోదు చేయండి';
                    if (t.replaceAll(RegExp(r'\D'), '').length < 10) {
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
                      icon: Icons.notes_rounded,
                      errorText: _fieldError('message')),
                ),
                const SizedBox(height: 16),

                if (error != null)
                  Container(
                    key: const Key('ad_booking_error'),
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
                          child: Text(error.message,
                              style: const TextStyle(
                                  color: Colors.redAccent, fontSize: 13)),
                        ),
                        if (error.retryable)
                          TextButton(
                            key: const Key('ad_booking_retry'),
                            onPressed: _isSubmitting ? null : _submitBooking,
                            child: const Text('మళ్లీ'),
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
