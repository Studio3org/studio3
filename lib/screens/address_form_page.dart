import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/address.dart';
import '../models/collect_shipping_address.dart' show kUsStates;
import '../services/address_service.dart';
import '../services/api_exception.dart';
import '../theme/app_theme.dart';
import '../theme/home_feed_tokens.dart';

class AddressFormPage extends StatefulWidget {
  const AddressFormPage({super.key, this.existing});

  final Address? existing;

  @override
  State<AddressFormPage> createState() => _AddressFormPageState();
}

class _AddressFormPageState extends State<AddressFormPage> {
  late final TextEditingController _label;
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _phone;
  late final TextEditingController _line1;
  late final TextEditingController _line2;
  late final TextEditingController _city;
  late final TextEditingController _zip;
  String? _state;
  double? _latitude;
  double? _longitude;
  bool _isDefault = false;
  bool _saving = false;
  bool _locating = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _label = TextEditingController(text: e?.label);
    _firstName = TextEditingController(text: e?.firstName);
    _lastName = TextEditingController(text: e?.lastName);
    _phone = TextEditingController(text: e?.phone);
    _line1 = TextEditingController(text: e?.line1);
    _line2 = TextEditingController(text: e?.line2);
    _city = TextEditingController(text: e?.city);
    _zip = TextEditingController(text: e?.zip);
    _state = e?.state;
    _latitude = e?.latitude;
    _longitude = e?.longitude;
    _isDefault = e?.isDefault ?? false;
  }

  @override
  void dispose() {
    _label.dispose();
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    _line1.dispose();
    _line2.dispose();
    _city.dispose();
    _zip.dispose();
    super.dispose();
  }

  bool get _canSave =>
      _firstName.text.trim().isNotEmpty &&
      _lastName.text.trim().isNotEmpty &&
      _phone.text.trim().isNotEmpty &&
      _line1.text.trim().isNotEmpty &&
      _city.text.trim().isNotEmpty &&
      _state != null &&
      _state!.isNotEmpty &&
      _zip.text.trim().isNotEmpty;

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission denied')),
        );
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location captured')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not get current location')),
      );
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _save() async {
    if (!_canSave) {
      setState(() => _error = 'Please fill in all required fields');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final address = Address(
      id: widget.existing?.id ?? '',
      label: _label.text.trim().isEmpty ? null : _label.text.trim(),
      firstName: _firstName.text.trim(),
      lastName: _lastName.text.trim(),
      phone: _phone.text.trim(),
      line1: _line1.text.trim(),
      line2: _line2.text.trim().isEmpty ? null : _line2.text.trim(),
      city: _city.text.trim(),
      state: _state!,
      zip: _zip.text.trim(),
      latitude: _latitude,
      longitude: _longitude,
      isDefault: _isDefault,
    );
    try {
      if (_isEdit) {
        await AddressService.instance.updateAddress(widget.existing!.id, address);
      } else {
        await AddressService.instance.createAddress(address);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'Could not save address';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HomeFeedTokens.background,
      appBar: AppBar(
        backgroundColor: HomeFeedTokens.background,
        elevation: 0,
        centerTitle: true,
        title: Text(
          _isEdit ? 'Edit address' : 'Add address',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: HomeFeedTokens.textPrimary,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: HomeFeedTokens.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _label,
            decoration: const InputDecoration(labelText: 'Label (e.g. Home)'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _firstName,
                  decoration: const InputDecoration(labelText: 'First name *'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _lastName,
                  decoration: const InputDecoration(labelText: 'Last name *'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone *'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _line1,
            decoration: const InputDecoration(labelText: 'Street address *'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _line2,
            decoration: const InputDecoration(labelText: 'Apt, suite, etc (optional)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _city,
            decoration: const InputDecoration(labelText: 'City *'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _state,
                  decoration: const InputDecoration(labelText: 'State *'),
                  items: [
                    for (final s in kUsStates)
                      DropdownMenuItem(value: s, child: Text(s)),
                  ],
                  onChanged: (v) => setState(() => _state = v),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _zip,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  decoration: const InputDecoration(labelText: 'Zip *'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _locating ? null : _useCurrentLocation,
            icon: _locating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location, size: 18),
            label: Text(
              _latitude != null ? 'Location captured' : 'Use my current location',
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Set as default address'),
            value: _isDefault,
            onChanged: (v) => setState(() => _isDefault = v),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: GoogleFonts.inter(fontSize: 12, color: Colors.red.shade700),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: (_canSave && !_saving) ? _save : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.slate900,
                foregroundColor: AppColors.white,
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save address'),
            ),
          ),
        ],
      ),
    );
  }
}
