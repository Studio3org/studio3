import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../models/address.dart';
import '../models/collect_shipping_address.dart' show kUsStates;
import '../services/address_service.dart';
import '../services/api_exception.dart';
import '../theme/studio_colors.dart';
import '../theme/studio_metrics.dart';
import '../theme/studio_type.dart';
import '../widgets/studio/studio_button.dart';
import '../widgets/studio/studio_checkbox.dart';
import '../widgets/studio/studio_field.dart';
import '../widgets/studio/studio_select_row.dart';
import '../widgets/studio/studio_sheet.dart';
import '../widgets/studio/studio_top_bar.dart';

/// Address form (`BuyAddress`): underline fields in the board's order and widths, ZIP and
/// phone in Mono 18 with the phone's helper line, the default-address checkbox, and the
/// pinned 54 button. Same fields and save behaviour as before.
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
  late final TextEditingController _stateText;
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
    _stateText = TextEditingController(text: e?.state);
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
    _stateText.dispose();
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Location permission denied')));
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Location captured')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not get current location')));
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

  void _changed(String _) => setState(() {});

  Future<void> _pickState() async {
    FocusScope.of(context).unfocus();
    final picked = await showStudioSheet<String>(
      context: context,
      builder: (sheetContext) => StudioSheet(
        horizontalPadding: 24,
        gap: 0,
        scrollable: true,
        children: [
          const SizedBox(height: 12),
          Text('State', style: StudioType.title22(color: sheetContext.studio.textPrimary)),
          const SizedBox(height: 8),
          for (final s in kUsStates)
            StudioSelectRow(
              title: s,
              selected: s == _state,
              titleSize: 17,
              titleLetterSpacing: 0,
              verticalPadding: 14,
              ruleInset: 12,
              onTap: () => Navigator.pop(sheetContext, s),
            ),
        ],
      ),
    );
    if (!mounted || picked == null) return;
    setState(() {
      _state = picked;
      _stateText.text = picked;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final safeBottom = MediaQuery.viewPaddingOf(context).bottom;
    const gap = SizedBox(height: 22);

    return Scaffold(
      backgroundColor: c.background,
      appBar: StudioTopBar(context: context, title: _isEdit ? 'Edit address' : 'Delivery address'),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: StudioUnderlineField(
                        label: 'First name',
                        controller: _firstName,
                        required: true,
                        textCapitalization: TextCapitalization.words,
                        autofillHints: const [AutofillHints.givenName],
                        onChanged: _changed,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: StudioUnderlineField(
                        label: 'Last name',
                        controller: _lastName,
                        required: true,
                        textCapitalization: TextCapitalization.words,
                        autofillHints: const [AutofillHints.familyName],
                        onChanged: _changed,
                      ),
                    ),
                  ],
                ),
                gap,
                StudioUnderlineField(
                  label: 'Street address',
                  controller: _line1,
                  required: true,
                  autofillHints: const [AutofillHints.streetAddressLine1],
                  onChanged: _changed,
                ),
                gap,
                StudioUnderlineField(
                  label: 'Apt, suite, etc.',
                  controller: _line2,
                  hint: 'Optional',
                  autofillHints: const [AutofillHints.streetAddressLine2],
                ),
                gap,
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 20,
                      child: StudioUnderlineField(
                        label: 'City',
                        controller: _city,
                        required: true,
                        textCapitalization: TextCapitalization.words,
                        autofillHints: const [AutofillHints.addressCity],
                        onChanged: _changed,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 10,
                      // A read-only underline field (same metrics as the others) that
                      // opens the state list.
                      child: StudioUnderlineField(
                        label: 'State',
                        controller: _stateText,
                        required: true,
                        readOnly: true,
                        onTap: _pickState,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 13,
                      child: StudioUnderlineField(
                        label: 'ZIP',
                        controller: _zip,
                        required: true,
                        mono: true,
                        valueSize: 18,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        autofillHints: const [AutofillHints.postalCode],
                        onChanged: _changed,
                      ),
                    ),
                  ],
                ),
                gap,
                StudioUnderlineField(
                  label: 'Phone',
                  controller: _phone,
                  required: true,
                  mono: true,
                  valueSize: 18,
                  keyboardType: TextInputType.phone,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  helper: 'The shipper uses this to schedule delivery with you.',
                  helperColor: c.textSecondary,
                  onChanged: _changed,
                ),
                gap,
                // Not on the board; kept from the existing form.
                StudioUnderlineField(
                  label: 'Label',
                  controller: _label,
                  hint: 'Optional, e.g. Home',
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: StudioButton(
                    label: _latitude != null ? 'Location captured' : 'Use my current location',
                    variant: StudioButtonVariant.small,
                    loading: _locating,
                    onPressed: _locating ? null : _useCurrentLocation,
                  ),
                ),
                const SizedBox(height: 12),
                StudioCheckbox(
                  value: _isDefault,
                  label: 'Set as default address',
                  onChanged: (v) => setState(() => _isDefault = v),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  // Errors are Ink, never red (`HandoffRules`).
                  Text(_error!, style: StudioType.caption12(height: 1.45, color: c.textPrimary)),
                ],
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              8,
              24,
              safeBottom > 0 ? safeBottom : StudioSize.noInsetBottomPadding,
            ),
            child: StudioButton(
              label: 'Save address',
              height: StudioSize.buttonPrimaryTall,
              loading: _saving,
              onPressed: _canSave && !_saving ? _save : null,
            ),
          ),
        ],
      ),
    );
  }
}
