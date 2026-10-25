import 'package:flutter/material.dart';

import '../theme/studio_colors.dart';
import '../theme/studio_metrics.dart';
import '../theme/studio_type.dart';
import 'studio/studio_icon.dart';

/// Search field in picker sheets (`PostMedium`, `PostLocation`, `PostMaterialsSearch`): 46
/// tall, Surface fill, radius 12, 14 sides, a 20 search icon 10 before 15 text.
class PostPickerSearchField extends StatelessWidget {
  const PostPickerSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
    this.autofocus = false,
    this.focusNode,
    this.height = 46,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final bool autofocus;
  final FocusNode? focusNode;

  /// 46 in picker sheets, 44 on the Messages tab (`NotifMessages`).
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final style = StudioType.sans(15, color: c.textPrimary);
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(StudioRadius.button),
      ),
      child: Row(
        children: [
          // Tertiary like the placeholder until something is typed, then Ink.
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) => StudioIcon(
              StudioIcons.search,
              size: 20,
              color: value.text.isEmpty ? c.textTertiary : c.textPrimary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              autofocus: autofocus,
              onChanged: onChanged,
              style: style,
              cursorColor: c.textPrimary,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                isCollapsed: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintText: hintText,
                hintStyle: style.copyWith(color: c.textTertiary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
