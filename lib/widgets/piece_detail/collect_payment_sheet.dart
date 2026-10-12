import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/collect_checkout.dart';
import '../../theme/collect_detail_tokens.dart';

/// Payment method picker — GPay / Apple Pay / Credit-Debit.
class CollectPaymentSheet extends StatefulWidget {
  const CollectPaymentSheet({
    super.key,
    this.initial,
  });

  final CollectPaymentMethod? initial;

  static Future<CollectPaymentMethod?> show(
    BuildContext context, {
    CollectPaymentMethod? initial,
  }) {
    return showModalBottomSheet<CollectPaymentMethod>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.2),
      builder: (context) => CollectPaymentSheet(initial: initial),
    );
  }

  @override
  State<CollectPaymentSheet> createState() => _CollectPaymentSheetState();
}

class _CollectPaymentSheetState extends State<CollectPaymentSheet> {
  late CollectPaymentMethod _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initial ?? CollectPaymentMethod.card;
  }

  void _save() => Navigator.pop(context, _selected);

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.96;

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Material(
          color: CollectDetailTokens.sheetBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
                child: SizedBox(
                  height: 24,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          behavior: HitTestBehavior.opaque,
                          child: const Padding(
                            padding: EdgeInsets.all(2),
                            child: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 16,
                              color: CollectDetailTokens.textPrimary,
                            ),
                          ),
                        ),
                      ),
                      Text(
                        'Payment',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: CollectDetailTokens.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 24 + bottomInset),
                child: Column(
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: CollectDetailTokens.sheetCardFill,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          for (var i = 0;
                              i < CollectPaymentMethod.values.length;
                              i++) ...[
                            if (i > 0)
                              const Divider(
                                height: 1,
                                indent: 16,
                                endIndent: 16,
                                color: CollectDetailTokens.divider,
                              ),
                            _PaymentOption(
                              method: CollectPaymentMethod.values[i],
                              selected:
                                  _selected == CollectPaymentMethod.values[i],
                              onTap: () => setState(
                                () =>
                                    _selected = CollectPaymentMethod.values[i],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: CollectDetailTokens.collectButtonHeight,
                      width: double.infinity,
                      child: Material(
                        color: CollectDetailTokens.ctaFill,
                        borderRadius: BorderRadius.circular(
                          CollectDetailTokens.collectButtonRadius,
                        ),
                        child: InkWell(
                          onTap: _save,
                          borderRadius: BorderRadius.circular(
                            CollectDetailTokens.collectButtonRadius,
                          ),
                          child: Center(
                            child: Text(
                              'Save and next',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                                color: CollectDetailTokens.textInverse,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentOption extends StatelessWidget {
  const _PaymentOption({
    required this.method,
    required this.selected,
    required this.onTap,
  });

  final CollectPaymentMethod method;
  final bool selected;
  final VoidCallback onTap;

  IconData get _icon {
    switch (method) {
      case CollectPaymentMethod.gpay:
        return Icons.account_balance_wallet_outlined;
      case CollectPaymentMethod.applePay:
        return Icons.apple;
      case CollectPaymentMethod.card:
        return Icons.credit_card;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(
                _icon,
                size: 22,
                color: CollectDetailTokens.textPrimary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  method.label,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: CollectDetailTokens.textPrimary,
                  ),
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                size: 18,
                color: selected
                    ? CollectDetailTokens.textPrimary
                    : CollectDetailTokens.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
