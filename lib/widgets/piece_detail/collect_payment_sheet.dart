import 'package:flutter/material.dart';

import '../../models/collect_checkout.dart';
import '../../theme/studio_colors.dart';
import '../../theme/studio_metrics.dart';
import '../../theme/studio_type.dart';
import '../studio/studio_button.dart';
import '../studio/studio_icon.dart';
import '../studio/studio_select_row.dart';
import '../studio/studio_sheet.dart';

/// Payment method picker (GPay / Apple Pay / Credit-Debit). No board of its own: a board
/// sheet with Back + "Payment", the methods as select rows (left line, no radios, no
/// icons, as the checkout options), and the 54 button.
class CollectPaymentSheet extends StatefulWidget {
  const CollectPaymentSheet({super.key, this.initial});

  final CollectPaymentMethod? initial;

  static Future<CollectPaymentMethod?> show(BuildContext context, {CollectPaymentMethod? initial}) {
    return showStudioSheet<CollectPaymentMethod>(
      context: context,
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
    final c = context.studio;
    const methods = CollectPaymentMethod.values;
    return StudioSheet(
      horizontalPadding: 24,
      gap: 12,
      children: [
        SizedBox(
          height: 44,
          child: Row(
            children: [
              Semantics(
                button: true,
                label: 'Back',
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox.square(
                    dimension: 44,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: StudioIcon(StudioIcons.back, size: 22, color: c.textPrimary),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  'Payment',
                  textAlign: TextAlign.center,
                  style: StudioType.sans(16, weight: StudioType.medium, color: c.textPrimary),
                ),
              ),
              const SizedBox(width: 44),
            ],
          ),
        ),
        Column(
          children: [
            for (var i = 0; i < methods.length; i++)
              StudioSelectRow(
                title: methods[i].label,
                selected: _selected == methods[i],
                titleSize: 17,
                titleLetterSpacing: 0,
                verticalPadding: 16,
                ruleInset: 16,
                divider: i < methods.length - 1,
                onTap: () => setState(() => _selected = methods[i]),
              ),
          ],
        ),
        const SizedBox(height: 8),
        StudioButton(
          label: 'Save and next',
          height: StudioSize.buttonPrimaryTall,
          onPressed: _save,
        ),
      ],
    );
  }
}
