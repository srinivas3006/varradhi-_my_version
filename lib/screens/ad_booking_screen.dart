import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

class AdBookingScreen extends StatefulWidget {
  const AdBookingScreen({super.key});

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
  int _durationDays = 7;

  bool _isFetchingPrice = false;
  bool _isSubmitting = false;
  bool _isLoadingAreas = false;

  String? _quotedPrice;
  String? _currency;
  String? _error;

  List<dynamic> _areas = [];
  String? _selectedAreaId;

  // Populated after successful booking submission
  Map<String, dynamic>? _bookingSuccessData;

  @override
  void initState() {
    super.initState();
    _loadAreas();
  }

  @override
  void dispose() {
    _businessController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadAreas() async {
    setState(() => _isLoadingAreas = true);
    try {
      final areas = await ApiService.instance.getAdAreas();
      if (mounted) {
        setState(() {
          _areas = areas;
          _isLoadingAreas = false;
          if (_adType == 'local' &&
              _selectedAreaId == null &&
              areas.isNotEmpty) {
            _selectedAreaId = areas.first['id']?.toString();
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingAreas = false);
    }
    _fetchPricing();
  }

  Future<void> _fetchPricing() async {
    if (_adType == 'local' &&
        (_selectedAreaId == null || _selectedAreaId!.isEmpty)) {
      setState(() {
        _quotedPrice = null;
        _error = _areas.isEmpty && !_isLoadingAreas
            ? 'ప్రస్తుతం ప్రకటన ప్రాంతాలు అందుబాటులో లేవు.'
            : 'దయచేసి స్థానిక ప్రకటనల కోసం ఒక ప్రాంతాన్ని ఎంచుకోండి.';
      });
      return;
    }

    setState(() {
      _isFetchingPrice = true;
      _error = null;
    });

    try {
      final data = await ApiService.instance.getAdPricing(
        adType: _adType,
        areaId: _adType == 'local' ? _selectedAreaId : null,
        durationDays: _durationDays,
      );
      final backendPrice = data['price'];
      final backendCurrency = data['currency'];
      if (backendPrice == null || backendCurrency == null) {
        throw StateError(
          'Backend pricing response is missing price or currency.',
        );
      }
      if (mounted) {
        setState(() {
          _currency = backendCurrency.toString();
          _quotedPrice = backendPrice.toString();
          _isFetchingPrice = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _quotedPrice = null;
          _isFetchingPrice = false;
          _error =
              'ధర వివరాలను పొందడంలో విఫలమైంది. దయచేసి మళ్లీ ప్రయత్నించండి.';
        });
      }
    }
  }

  Future<void> _submitBooking() async {
    if (!_formKey.currentState!.validate()) return;

    if (_adType == 'local' &&
        (_selectedAreaId == null || _selectedAreaId!.isEmpty)) {
      setState(() => _error = 'దయచేసి ప్రకటన కోసం మీ ప్రాంతాన్ని ఎంచుకోండి');
      return;
    }

    if (_quotedPrice == null || _currency == null) {
      setState(() => _error =
          'à°§à°° à°µà°¿à°µà°°à°¾à°²à± à°¸à°°à±à°µà°°à± à°¨à±à°‚à°¡à°¿ à°²à±‹à°¡à± à°•à°¾à°²à±‡à°¦à±. à°¦à°¯à°šà±‡à°¸à°¿ à°®à°³à±à°²à±€ à°ªà±à°°à°¯à°¤à±à°¨à°¿à°‚à°šà°‚à°¡à°¿.');
      _fetchPricing();
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final payload = {
        'advertiser_name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'business_name': _businessController.text.trim(),
        'ad_type': _adType,
        'duration_days': _durationDays,
        if (_adType == 'local') 'area_id': _selectedAreaId,
        if (_messageController.text.trim().isNotEmpty)
          'message': _messageController.text.trim(),
      };

      final responseData = await ApiService.instance.submitAdBooking(payload);

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
    final String text = Uri.encodeComponent(
      "Hello, I booked an ad for '${_businessController.text.trim()}'. "
      "Ref: ${_bookingSuccessData?['id'] ?? 'New'}. "
      "Ad Type: $_adType, Duration: $_durationDays days."
      "${_currency != null && _quotedPrice != null ? ' Quoted: $_currency $_quotedPrice.' : ''}",
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

  Widget _buildAdTypeSelector(bool isDark) {
    return Row(
      children: [
        // Main (State-wide)
        Expanded(
          child: GestureDetector(
            onTap: () {
              if (_adType != 'main') {
                setState(() {
                  _adType = 'main';
                  _selectedAreaId = null;
                });
                _fetchPricing();
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              decoration: BoxDecoration(
                color: _adType == 'main'
                    ? AppColors.primary.withValues(alpha: 0.12)
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.grey.shade100),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _adType == 'main'
                      ? AppColors.primary
                      : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(
                        Icons.public_rounded,
                        color:
                            _adType == 'main' ? AppColors.primary : Colors.grey,
                        size: 22,
                      ),
                      if (_adType == 'main')
                        const Icon(Icons.check_circle_rounded,
                            color: AppColors.primary, size: 18),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'రాష్ట్రవ్యాప్తంగా',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: _adType == 'main' ? AppColors.primary : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ప్రధాన వార్తల ఫీడ్',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Local News
        Expanded(
          child: GestureDetector(
            onTap: () {
              if (_adType != 'local') {
                setState(() {
                  _adType = 'local';
                  if (_areas.isNotEmpty) {
                    _selectedAreaId = _areas.first['id']?.toString();
                  }
                });
                _fetchPricing();
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              decoration: BoxDecoration(
                color: _adType == 'local'
                    ? AppColors.primary.withValues(alpha: 0.12)
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.grey.shade100),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _adType == 'local'
                      ? AppColors.primary
                      : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(
                        Icons.location_city_rounded,
                        color: _adType == 'local'
                            ? AppColors.primary
                            : Colors.grey,
                        size: 22,
                      ),
                      if (_adType == 'local')
                        const Icon(Icons.check_circle_rounded,
                            color: AppColors.primary, size: 18),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'స్థానిక ప్రాంతం',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: _adType == 'local' ? AppColors.primary : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ఎంచుకున్న జిల్లా / ప్రాంతం',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDurationPills(bool isDark) {
    final durations = [
      {'days': 7, 'label': '7 రోజులు', 'sub': '1 వారం'},
      {'days': 14, 'label': '14 రోజులు', 'sub': '2 వారాలు'},
      {'days': 30, 'label': '30 రోజులు', 'sub': '1 నెల'},
    ];

    return Row(
      children: durations.map((d) {
        final days = d['days'] as int;
        final isSelected = _durationDays == days;

        return Expanded(
          child: GestureDetector(
            onTap: () {
              if (_durationDays != days) {
                setState(() => _durationDays = days);
                _fetchPricing();
              }
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.grey.shade100),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    d['label'] as String,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.white : Colors.black87),
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    d['sub'] as String,
                    style: TextStyle(
                      color: isSelected ? Colors.white70 : Colors.grey,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSuccessScreen(bool isDark) {
    final data = _bookingSuccessData ?? {};
    final bookingId = data['id']?.toString() ?? 'Pending';
    final price = data['quoted_price']?.toString() ?? _quotedPrice;
    final currency = data['currency']?.toString() ?? _currency;
    final whatsappUrl = data['whatsapp_url']?.toString();

    String areaName = 'రాష్ట్రవ్యాప్తంగా (అన్ని ఫీడ్‌లు)';
    if (_adType == 'local') {
      final areaObj = _areas.firstWhere(
        (a) => a['id']?.toString() == _selectedAreaId,
        orElse: () => null,
      );
      if (areaObj != null) {
        areaName = areaObj['name']?.toString() ?? 'స్థానిక ప్రాంతం';
      }
    }

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
              // Glowing Checkmark
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

              // Quote & Details Card
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
                        const Text(
                          'అంచనా వేసిన ధర',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, color: Colors.grey),
                        ),
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
                    if (price != null && currency != null)
                      Text(
                        '$currency $price',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                        ),
                      )
                    else
                      const Text(
                        'Price pending from backend',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.orange,
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
                    _buildDetailRow('కాలపరిమితి', '$_durationDays రోజులు'),
                    const SizedBox(height: 10),
                    _buildDetailRow(
                        'సంప్రదింపు నంబర్', _phoneController.text.trim()),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // WhatsApp Contact Button using whatsapp_url
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
                    backgroundColor:
                        const Color(0xFF25D366), // WhatsApp Brand Color
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 2,
                  ),
                  onPressed: () => _launchWhatsApp(whatsappUrl),
                ),
              ),
              const SizedBox(height: 14),

              // Done / Back to Home
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Show Success Screen if booking is complete
    if (_bookingSuccessData != null) {
      return _buildSuccessScreen(isDark);
    }

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
              // Header
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

              // 1. Choose Main vs Local
              const Text(
                '1. ప్రకటన స్థానాన్ని ఎంచుకోండి',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
              const SizedBox(height: 10),
              _buildAdTypeSelector(isDark),
              const SizedBox(height: 16),

              // If Local, Area Dropdown
              if (_adType == 'local') ...[
                const Text(
                  'లక్ష్య ప్రాంతం / జిల్లా',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 8),
                _isLoadingAreas
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2)),
                            SizedBox(width: 12),
                            Text('అందుబాటులో ఉన్న ప్రాంతాలను లోడ్ చేస్తోంది...',
                                style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                    : DropdownButtonFormField<String>(
                        initialValue: _selectedAreaId,
                        decoration: InputDecoration(
                          hintText: _areas.isEmpty
                              ? 'ప్రాంతాలు అందుబాటులో లేవు'
                              : 'ప్రాంతాన్ని ఎంచుకోండి',
                          filled: true,
                          fillColor: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          prefixIcon: const Icon(Icons.location_on_outlined),
                        ),
                        items: _areas.map((area) {
                          return DropdownMenuItem<String>(
                            value: area['id']?.toString(),
                            child: Text(area['name']?.toString() ?? 'ప్రాంతం'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() => _selectedAreaId = val);
                          _fetchPricing();
                        },
                        validator: (v) {
                          if (_adType == 'local' && (v == null || v.isEmpty)) {
                            return 'దయచేసి ఒక ప్రాంతాన్ని ఎంచుకోండి';
                          }
                          return null;
                        },
                      ),
                const SizedBox(height: 20),
              ],

              // 2. Choose Duration
              const Text(
                '2. ప్రకటన కాలపరిమితిని ఎంచుకోండి',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
              const SizedBox(height: 10),
              _buildDurationPills(isDark),
              const SizedBox(height: 20),

              // 3. Quoted Pricing Card
              Container(
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
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('అంచనా వేసిన కోట్',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                        SizedBox(height: 2),
                        Text('కాలపరిమితి & ప్రదేశం ఆధారంగా',
                            style: TextStyle(color: Colors.grey, fontSize: 11)),
                      ],
                    ),
                    if (_isFetchingPrice)
                      const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2))
                    else if (_quotedPrice != null && _currency != null)
                      Text(
                        '${_currency!} $_quotedPrice',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                          fontSize: 20,
                        ),
                      )
                    else
                      const Text('అందుబాటులో లేదు',
                          style: TextStyle(color: Colors.redAccent)),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 4. Advertiser Details Form
              const Text(
                '3. ప్రకటనదారు వివరాలు',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
              const SizedBox(height: 12),

              // Business Name
              TextFormField(
                controller: _businessController,
                decoration: InputDecoration(
                  labelText: 'వ్యాపారం / బ్రాండ్ పేరు',
                  hintText: 'ఉదా. రవి మొబైల్స్',
                  prefixIcon: const Icon(Icons.storefront_rounded),
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.grey.shade100,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty)
                    return 'మీ వ్యాపారం పేరు నమోదు చేయండి';
                  if (v.trim().length < 2)
                    return 'సరైన వ్యాపారం పేరు నమోదు చేయండి';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Name
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'సంప్రదించవలసిన వ్యక్తి పేరు',
                  hintText: 'ఉదా. రమేష్',
                  prefixIcon: const Icon(Icons.person_outline_rounded),
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.grey.shade100,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty)
                    return 'సంప్రదించవలసిన వ్యక్తి పేరు నమోదు చేయండి';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Phone Number
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'ఫోన్ / WhatsApp నంబర్',
                  hintText: 'ఉదా. 9876543210',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.grey.shade100,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty)
                    return 'ఫోన్ నంబర్ నమోదు చేయండి';
                  if (v.trim().length < 10)
                    return 'సరైన 10 అంకెల ఫోన్ నంబర్ నమోదు చేయండి';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Message / Notes (Optional)
              TextFormField(
                controller: _messageController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'ప్రత్యేక వివరాలు / సూచనలు (ఐచ్ఛికం)',
                  hintText: 'ఉదా. పండుగ ప్రత్యేక బ్యానర్',
                  prefixIcon: const Icon(Icons.notes_rounded),
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.grey.shade100,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none),
                ),
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

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  onPressed: (_isSubmitting ||
                          _isFetchingPrice ||
                          _quotedPrice == null ||
                          _currency == null)
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
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}
