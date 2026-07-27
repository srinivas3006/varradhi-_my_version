import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class AdBookingScreen extends StatefulWidget {
  const AdBookingScreen({super.key});

  @override
  State<AdBookingScreen> createState() => _AdBookingScreenState();
}

class _AdBookingScreenState extends State<AdBookingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _businessController = TextEditingController();

  String _adType = 'local';
  int _durationDays = 7;

  bool _isFetchingPrice = false;
  bool _isSubmitting = false;

  String? _quotedPrice;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchPricing();
  }

  Future<void> _fetchPricing() async {
    setState(() {
      _isFetchingPrice = true;
      _error = null;
    });

    try {
      final data = await ApiService.instance.getAdPricing(
        adType: _adType,
        durationDays: _durationDays,
      );
      if (mounted) {
        setState(() {
          _quotedPrice = '${data['currency'] ?? '₹'} ${data['price']}';
          _isFetchingPrice = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _quotedPrice = null;
          _isFetchingPrice = false;
        });
      }
    }
  }

  Future<void> _submitBooking() async {
    if (!_formKey.currentState!.validate()) return;
    if (_quotedPrice == null) {
      setState(() => _error = 'Please wait for price calculation.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final payload = {
        'business_name': _businessController.text.trim(),
        'ad_type': _adType,
        'duration_days': _durationDays,
      };

      final data = await ApiService.instance.submitAdBooking(payload);
      final url = data['whatsapp_url'] as String?;
      
      if (url != null && url.isNotEmpty) {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          if (mounted) Navigator.pop(context); // Close on success
        } else {
          throw Exception('Could not launch WhatsApp');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Failed to submit booking. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _onSelectionChanged() {
    _fetchPricing();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Advertise With Us')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Grow Your Business',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'Advertise on Varadhi to reach thousands of users instantly.',
                style: TextStyle(color: AppColors.textMuted),
              ),
              const SizedBox(height: 32),
              
              // Business Name
              const Text('Business Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _businessController,
                decoration: InputDecoration(
                  hintText: 'Enter your business name',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Please enter your business name' : null,
              ),
              const SizedBox(height: 24),
              
              // Scope Selection
              const Text('Ad Visibility', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _adType,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: const [
                  DropdownMenuItem(value: 'local', child: Text('Local News Only')),
                  DropdownMenuItem(value: 'main', child: Text('State-wide (Main News)')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _adType = val);
                    _onSelectionChanged();
                  }
                },
              ),
              const SizedBox(height: 24),

              // Duration Selection
              const Text('Duration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                value: _durationDays,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: const [
                  DropdownMenuItem(value: 7, child: Text('1 Week')),
                  DropdownMenuItem(value: 14, child: Text('2 Weeks')),
                  DropdownMenuItem(value: 30, child: Text('1 Month')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _durationDays = val);
                    _onSelectionChanged();
                  }
                },
              ),
              const SizedBox(height: 32),

              // Pricing Banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Estimated Price:', style: TextStyle(fontWeight: FontWeight.bold)),
                    if (_isFetchingPrice)
                      const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    else if (_quotedPrice != null)
                      Text(_quotedPrice!, style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.primary, fontSize: 18))
                    else
                      const Text('Unavailable', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(_error!, style: const TextStyle(color: Colors.red)),
                ),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366), // WhatsApp Green
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Contact Admin on WhatsApp', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  onPressed: _isSubmitting ? null : _submitBooking,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _businessController.dispose();
    super.dispose();
  }
}
