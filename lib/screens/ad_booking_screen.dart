// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
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
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _messageController = TextEditingController();

  String _adType = 'main'; // 'main' or 'local'
  String _adSize = 'Full Ad'; // 'Full Ad' or 'Small Ad'
  int _durationDays = 7;
  String? _selectedAreaId;

  List<dynamic> _areas = [];
  bool _isLoadingAreas = false;

  bool _isFetchingPrice = false;
  int? _quotedPrice;
  String? _priceError;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = AppState.instance.userName;
    _phoneController.text = AppState.instance.userPhone;
    _fetchAreas();
    _fetchPrice();
  }

  Future<void> _fetchAreas() async {
    setState(() => _isLoadingAreas = true);
    try {
      final areas = await ApiService.instance.getAdAreas();
      if (mounted) {
        setState(() {
          _areas = areas;
          _isLoadingAreas = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingAreas = false);
      }
    }
  }

  Future<void> _fetchPrice() async {
    if (_adType == 'local' && _selectedAreaId == null) {
      setState(() {
        _quotedPrice = null;
        _priceError = 'Select an area to see pricing';
      });
      return;
    }

    setState(() {
      _isFetchingPrice = true;
      _priceError = null;
    });

    try {
      final data = await ApiService.instance.getAdPricing(
        adType: _adType,
        areaId: _selectedAreaId,
        durationDays: _durationDays,
      );
      if (mounted) {
        setState(() {
          _quotedPrice = data['price'] ?? data['amount'] ?? 0;
          _isFetchingPrice = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isFetchingPrice = false;
          _priceError = 'Failed to load price';
        });
      }
    }
  }

  void _onTypeChanged(String? type) {
    if (type != null) {
      setState(() {
        _adType = type;
        if (type == 'main') _selectedAreaId = null;
      });
      _fetchPrice();
    }
  }

  void _onAreaChanged(String? areaId) {
    if (areaId != null) {
      setState(() => _selectedAreaId = areaId);
      _fetchPrice();
    }
  }

  void _onDurationChanged(int? duration) {
    if (duration != null) {
      setState(() => _durationDays = duration);
      _fetchPrice();
    }
  }

  Future<void> _submit() async {
    if (_nameController.text.isEmpty ||
        _phoneController.text.isEmpty ||
        _businessNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields.')),
      );
      return;
    }

    if (_adType == 'local' && _selectedAreaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a local area.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final combinedMessage = 'Ad size preference: $_adSize. ${_messageController.text}';
      
      final data = await ApiService.instance.submitAdBooking({
        'advertiser_name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'business_name': _businessNameController.text.trim(),
        'ad_type': _adType,
        if (_adType == 'local') 'area_id': _selectedAreaId,
        'duration_days': _durationDays,
        'message': combinedMessage,
      });

      setState(() => _isSubmitting = false);

      if (!mounted) return;
      _showSuccessDialog(data['whatsapp_url'] ?? data['whatsappUrl'], data['quoted_price'] ?? _quotedPrice);
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to submit inquiry. Please try again.')),
        );
      }
    }
  }

  void _showSuccessDialog(String? whatsappUrl, dynamic finalPrice) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Inquiry Submitted!'),
          content: Text('Your inquiry has been sent. The estimated price is ₹$finalPrice. Our team will review and contact you.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // close dialog
                Navigator.of(context).pop(); // close screen
              },
              child: const Text('Close'),
            ),
            if (whatsappUrl != null)
              ElevatedButton.icon(
                onPressed: () async {
                  final uri = Uri.parse(whatsappUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.chat),
                label: const Text('Continue on WhatsApp'),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('DailyBuzz', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
            Text('Advertise with Us', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Your Details'),
              _buildTextField('Your Name', _nameController),
              const SizedBox(height: 12),
              _buildTextField('Phone Number', _phoneController, keyboardType: TextInputType.phone),
              const SizedBox(height: 12),
              _buildTextField('Business Name', _businessNameController),

              const SizedBox(height: 24),
              _buildSectionTitle('Ad Targeting'),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('State-wide'),
                      value: 'main',
                      groupValue: _adType,
                      activeColor: AppColors.primary,
                      onChanged: _onTypeChanged,
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Local Area'),
                      value: 'local',
                      groupValue: _adType,
                      activeColor: AppColors.primary,
                      onChanged: _onTypeChanged,
                    ),
                  ),
                ],
              ),
              if (_adType == 'local') ...[
                const SizedBox(height: 8),
                _isLoadingAreas
                    ? const CircularProgressIndicator()
                    : DropdownButtonFormField<String>(
                        decoration: _inputDecoration('Select Area'),
                        initialValue: _selectedAreaId,
                        items: _areas.map<DropdownMenuItem<String>>((area) {
                          return DropdownMenuItem<String>(
                            value: area['id'].toString(),
                            child: Text(area['name'] ?? 'Unknown Area'),
                          );
                        }).toList(),
                        onChanged: _onAreaChanged,
                      ),
              ],

              const SizedBox(height: 24),
              _buildSectionTitle('Ad Size Preference'),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Full Ad'),
                      value: 'Full Ad',
                      groupValue: _adSize,
                      activeColor: AppColors.primary,
                      onChanged: (v) => setState(() => _adSize = v!),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Small Ad'),
                      value: 'Small Ad',
                      groupValue: _adSize,
                      activeColor: AppColors.primary,
                      onChanged: (v) => setState(() => _adSize = v!),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              _buildSectionTitle('Duration'),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 7, label: Text('7 days')),
                  ButtonSegment(value: 14, label: Text('14 days')),
                  ButtonSegment(value: 30, label: Text('30 days')),
                ],
                selected: {_durationDays},
                onSelectionChanged: (set) => _onDurationChanged(set.first),
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    return states.contains(WidgetState.selected) ? AppColors.primary : Colors.white;
                  }),
                  foregroundColor: WidgetStateProperty.resolveWith((states) {
                    return states.contains(WidgetState.selected) ? Colors.white : AppColors.textDark;
                  }),
                ),
              ),

              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.chipBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    const Text('Estimated price', style: TextStyle(color: AppColors.textMuted)),
                    const SizedBox(height: 4),
                    if (_isFetchingPrice)
                      const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2))
                    else if (_priceError != null)
                      Text(_priceError!, style: const TextStyle(color: Colors.red, fontSize: 13))
                    else
                      Text(
                        '₹${_quotedPrice ?? 0}',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    if (_quotedPrice != null && !_isFetchingPrice)
                      Text('for $_durationDays days (${_adType == 'main' ? 'State-wide' : 'Local'})',
                          style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              _buildTextField('Additional message (optional)', _messageController, maxLines: 3),

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Submit Inquiry', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {int maxLines = 1, TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: _inputDecoration(label),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _businessNameController.dispose();
    _messageController.dispose();
    super.dispose();
  }
}
