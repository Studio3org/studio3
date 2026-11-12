import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart' show StripeException;

import '../models/address.dart';
import '../models/saved_card.dart';
import '../services/address_service.dart';
import '../services/api_exception.dart';
import '../services/saved_card_service.dart';
import '../widgets/feed_skeleton.dart';
import '../widgets/settings_tile.dart';
import '../widgets/studio/studio.dart';
import 'address_form_page.dart';

/// Payment and shipping (`SettingsPayment`, Flow 12). Payment: the saved cards ("Visa ending
/// 4242"; tapping one asks to remove it) and Add payment method (Stripe's own form; no Stripe
/// label). Shipping, with an info tooltip "Where your purchases are delivered.": the saved
/// addresses with the default marked, tapping one to edit, make default or delete it, and Add
/// address.
///
/// The board's default card ("Default" on a card, "Your default card is used for auction
/// wins.", and asking for a new default before removing it with active bids) is a payment
/// change on hold (BACKEND_CHANGES B34), so cards have no default here: a bid keeps the card
/// it was placed with.
class PaymentShippingPage extends StatefulWidget {
  const PaymentShippingPage({super.key, this.debugCards, this.debugAddresses});

  /// For tests: the cards instead of loading them.
  @visibleForTesting
  final List<SavedCard>? debugCards;

  /// For tests: the addresses instead of loading them.
  @visibleForTesting
  final List<Address>? debugAddresses;

  @override
  State<PaymentShippingPage> createState() => _PaymentShippingPageState();
}

class _PaymentShippingPageState extends State<PaymentShippingPage> {
  List<SavedCard> _cards = const [];
  List<Address> _addresses = const [];
  bool _loading = true;
  bool _addingCard = false;

  bool get _debug => widget.debugCards != null || widget.debugAddresses != null;

  @override
  void initState() {
    super.initState();
    if (_debug) {
      _cards = widget.debugCards ?? const [];
      _addresses = widget.debugAddresses ?? const [];
      _loading = false;
      return;
    }
    _load();
  }

  Future<void> _load() async {
    if (_debug) return;
    await Future.wait([_loadCards(), _loadAddresses()]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadCards() async {
    try {
      final cards = await SavedCardService.instance.list();
      if (mounted) setState(() => _cards = cards);
    } catch (_) {
      // No cards shown; Add payment method stays.
    }
  }

  Future<void> _loadAddresses({bool refresh = false}) async {
    try {
      final addresses = await AddressService.instance.getAddressesCached(forceRefresh: refresh);
      if (mounted) setState(() => _addresses = addresses);
    } catch (_) {
      // No addresses shown; Add address stays.
    }
  }

  // Payment

  Future<void> _addCard() async {
    if (_addingCard) return;
    setState(() => _addingCard = true);
    try {
      final card = await SavedCardService.instance.addCard();
      if (!mounted) return;
      if (card != null) {
        await _loadCards();
        if (mounted) showStudioToast(context, 'Card added');
      }
    } on CardSaveUnavailable catch (e) {
      if (mounted) showStudioToast(context, e.message, icon: null);
    } on StripeException catch (e) {
      if (mounted) {
        showStudioToast(context, e.error.localizedMessage ?? 'Could not save the card.', icon: null);
      }
    } on ApiException catch (e) {
      if (mounted) showStudioToast(context, e.message, icon: null);
    } catch (_) {
      if (mounted) showStudioToast(context, 'Could not save the card.', icon: null);
    } finally {
      if (mounted) setState(() => _addingCard = false);
    }
  }

  Future<void> _removeCard(SavedCard card) async {
    final confirmed = await showStudioConfirm(
      context,
      title: 'Remove ${savedCardName(card)}?',
      message: 'If you win an auction you bid on with this card, the payment can fail.',
      confirmLabel: 'Remove',
    );
    if (!confirmed || !mounted) return;
    try {
      await SavedCardService.instance.remove(card.id);
      if (!mounted) return;
      setState(() => _cards = [for (final c in _cards) if (c.id != card.id) c]);
      showStudioToast(context, 'Card removed');
    } on ApiException catch (e) {
      if (mounted) showStudioToast(context, e.message, icon: null);
    } catch (_) {
      if (mounted) showStudioToast(context, 'Could not remove the card.', icon: null);
    }
  }

  // Shipping

  Future<void> _openAddressForm([Address? existing]) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(builder: (_) => AddressFormPage(existing: existing)),
    );
    if (saved == true) await _loadAddresses(refresh: true);
  }

  Future<void> _setDefault(Address address) async {
    try {
      await AddressService.instance.setDefault(address.id);
      await _loadAddresses(refresh: true);
    } on ApiException catch (e) {
      if (mounted) showStudioToast(context, e.message, icon: null);
    } catch (_) {
      if (mounted) showStudioToast(context, 'Could not set the default address.', icon: null);
    }
  }

  Future<void> _deleteAddress(Address address) async {
    final confirmed = await showStudioConfirm(
      context,
      title: 'Delete ${addressName(address)}?',
      confirmLabel: 'Delete',
    );
    if (!confirmed || !mounted) return;
    try {
      await AddressService.instance.deleteAddress(address.id);
      await _loadAddresses(refresh: true);
    } on ApiException catch (e) {
      if (mounted) showStudioToast(context, e.message, icon: null);
    } catch (_) {
      if (mounted) showStudioToast(context, 'Could not delete the address.', icon: null);
    }
  }

  void _addressActions(Address address) {
    showStudioSheet<void>(
      context: context,
      builder: (sheetContext) => StudioSheet(
        horizontalPadding: 24,
        gap: 6,
        children: [
          StudioActionRow(
            icon: StudioIcons.renameFolder,
            title: 'Edit',
            onTap: () {
              Navigator.pop(sheetContext);
              _openAddressForm(address);
            },
          ),
          if (!address.isDefault)
            StudioActionRow(
              icon: StudioIcons.check,
              title: 'Set as default',
              onTap: () {
                Navigator.pop(sheetContext);
                _setDefault(address);
              },
            ),
          StudioActionRow(
            icon: StudioIcons.deleteFolder,
            title: 'Delete',
            onTap: () {
              Navigator.pop(sheetContext);
              _deleteAddress(address);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return Scaffold(
      backgroundColor: c.background,
      appBar: StudioTopBar(context: context, title: 'Payment and shipping'),
      body: _loading
          ? const SettingsListSkeleton()
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
              children: [
                const SettingsSectionLabel('Payment', top: 26),
                for (final card in _cards)
                  SettingsRow(
                    label: savedCardName(card),
                    subtitle: card.isExpired ? 'Expired' : null,
                    onTap: () => _removeCard(card),
                  ),
                SettingsRow(label: 'Add payment method', onTap: _addingCard ? null : _addCard),
                StudioTooltip(
                  message: 'Where your purchases are delivered.',
                  builder: (context, toggle) => Padding(
                    padding: const EdgeInsets.only(top: 26, bottom: 2),
                    child: Row(
                      children: [
                        Text(
                          'SHIPPING',
                          style: StudioType.mono(
                            11,
                            weight: StudioType.medium,
                            color: c.textTertiary,
                          ).copyWith(letterSpacing: 0.5),
                        ),
                        StudioInfoButton(
                          onTap: toggle,
                          semanticLabel: 'What is this address for?',
                        ),
                      ],
                    ),
                  ),
                ),
                for (final address in _addresses)
                  SettingsRow(
                    label: addressName(address),
                    subtitle: addressLine(address),
                    value: address.isDefault ? 'Default' : null,
                    onTap: () => _addressActions(address),
                  ),
                SettingsRow(label: 'Add address', onTap: () => _openAddressForm()),
              ],
            ),
    );
  }
}

/// "Visa ending 4242" (the board's card row), "Card ending 4242" with no brand.
String savedCardName(SavedCard card) {
  final brand = (card.brand ?? '').trim();
  final name = brand.isEmpty ? 'Card' : brand[0].toUpperCase() + brand.substring(1);
  final last4 = (card.last4 ?? '').trim();
  return last4.isEmpty ? name : '$name ending $last4';
}

/// The address's label ("Home"), or the name on it.
String addressName(Address address) {
  final label = (address.label ?? '').trim();
  return label.isNotEmpty ? label : address.fullName.trim();
}

/// "4521 Lovers Ln, Dallas, TX 75225".
String addressLine(Address address) {
  final street = [address.line1, address.line2 ?? '']
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .join(', ');
  final region = '${address.state} ${address.zip}'.trim();
  return [street, address.city.trim(), region].where((part) => part.isNotEmpty).join(', ');
}
