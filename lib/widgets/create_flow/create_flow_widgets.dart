import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/post_media_assets.dart';
import '../../theme/app_theme.dart';
import '../../theme/home_feed_tokens.dart';

/// Shared horizontal inset for create / listing flow dividers.
const double createFlowHorizontalInset = 15.0;

class CreateFlowBanner extends StatelessWidget {
  const CreateFlowBanner({
    super.key,
    required this.topInset,
    required this.title,
    required this.onClose,
  });

  final double topInset;
  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Padding(
        padding: EdgeInsets.only(top: topInset),
        child: SizedBox(
          height: 64,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: onClose,
                    behavior: HitTestBehavior.opaque,
                    child: SvgPicture.asset(
                      PostMediaAssets.createCloseIcon,
                      width: 14,
                      height: 14,
                    ),
                  ),
                ),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: HomeFeedTokens.textInverse,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CreateFlowPreviewCard extends StatelessWidget {
  const CreateFlowPreviewCard({super.key, required this.imagePath});

  static const cardWidth = 200.0;
  static const cardHeight = 266.0;
  static const cardRadius = 8.0;

  final String imagePath;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: cardWidth,
      height: cardHeight,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(cardRadius),
        child: _buildImage(),
      ),
    );
  }

  Widget _buildImage() {
    if (imagePath.startsWith('assets/')) {
      return Image.asset(
        imagePath,
        width: cardWidth,
        height: cardHeight,
        fit: BoxFit.cover,
      );
    }
    return Image.file(
      File(imagePath),
      width: cardWidth,
      height: cardHeight,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Image.asset(
          imagePath,
          width: cardWidth,
          height: cardHeight,
          fit: BoxFit.cover,
        );
      },
    );
  }
}

class CreateFlowDivider extends StatelessWidget {
  const CreateFlowDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 0.5,
      color: const Color(0xFF2E2C28),
    );
  }
}

/// Pill text field matching login page [AuthIconInput] styling.
class CreateFlowTextField extends StatelessWidget {
  const CreateFlowTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.style = CreateFlowTextFieldStyle.title,
    this.maxLines = 1,
    this.minLines,
    this.keyboardType,
    this.prefixText,
  });

  static const _textDim = Color(0x80FFFFFF);
  static const _border = Color(0x26FFFFFF);
  static const _borderFocus = Color(0x55FFFFFF);

  final TextEditingController controller;
  final String hint;
  final CreateFlowTextFieldStyle style;
  final int maxLines;
  final int? minLines;
  final TextInputType? keyboardType;
  final String? prefixText;

  InputDecoration _decoration({required bool multiline}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: _textDim,
        height: multiline ? 1.35 : null,
      ),
      prefixText: prefixText,
      prefixStyle: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: HomeFeedTokens.textInverse,
      ),
      filled: true,
      fillColor: Colors.black.withValues(alpha: 0.35),
      contentPadding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: multiline ? 14 : 0,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _border, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _border, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _borderFocus, width: 1.2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final multiline = maxLines > 1;
    final field = TextField(
      controller: controller,
      maxLines: maxLines,
      minLines: minLines,
      keyboardType: keyboardType,
      style: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: style == CreateFlowTextFieldStyle.title
            ? FontWeight.w500
            : FontWeight.w400,
        color: HomeFeedTokens.textInverse,
        height: multiline ? 1.35 : null,
      ),
      cursorColor: HomeFeedTokens.textInverse,
      decoration: _decoration(multiline: multiline),
    );

    if (multiline) {
      return field;
    }

    return SizedBox(
      height: AppDims.pillInputHeight,
      child: field,
    );
  }
}

enum CreateFlowTextFieldStyle { title, body }

class CreateFlowMetadataRow extends StatelessWidget {
  const CreateFlowMetadataRow({
    super.key,
    required this.iconAsset,
    required this.iconWidth,
    required this.iconHeight,
    required this.label,
    required this.onTap,
    this.trailing,
    this.countBadge,
  });

  final String iconAsset;
  final double iconWidth;
  final double iconHeight;
  final String label;
  final VoidCallback onTap;
  final String? trailing;
  final int? countBadge;

  static const _textSecondary = Color(0xFF8C8880);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            SvgPicture.asset(
              iconAsset,
              width: iconWidth,
              height: iconHeight,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: HomeFeedTokens.textInverse,
                ),
              ),
            ),
            if (trailing != null) ...[
              Text(
                trailing!,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: _textSecondary,
                ),
              ),
              const SizedBox(width: 10),
            ],
            if (countBadge != null && countBadge! > 0) ...[
              Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$countBadge',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: HomeFeedTokens.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
            SvgPicture.asset(
              PostMediaAssets.createChevronRight,
              width: 8,
              height: 13,
            ),
          ],
        ),
      ),
    );
  }
}

class CreateFlowLocationChip extends StatelessWidget {
  const CreateFlowLocationChip({
    super.key,
    required this.label,
    this.onRemove,
  });

  static const _neutral700 = Color(0xFF4A4843);
  static const _textSecondary = Color(0xFF8C8880);

  final String label;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onRemove,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 18,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _neutral700,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: FontWeight.w400,
            color: _textSecondary,
          ),
        ),
      ),
    );
  }
}

class CreateFlowToggleRow extends StatelessWidget {
  const CreateFlowToggleRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.iconAsset,
    this.iconWidth = 12,
    this.iconHeight = 12,
  });

  static const _neutral700 = Color(0xFF4A4843);
  static const _neutral300 = Color(0xFFC8C5BC);
  static const _toggleBlue = Color(0xFF3B82F6);
  static const _trackWidth = 52.0;
  static const _trackHeight = 28.0;
  static const _knobSize = 22.0;
  static const _trackPadding = 3.0;

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? iconAsset;
  final double iconWidth;
  final double iconHeight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          if (iconAsset != null) ...[
            SvgPicture.asset(
              iconAsset!,
              width: iconWidth,
              height: iconHeight,
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: HomeFeedTokens.textInverse,
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              FocusScope.of(context).unfocus();
              onChanged(!value);
            },
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: _trackWidth,
              height: _trackHeight,
              padding: const EdgeInsets.all(_trackPadding),
              decoration: BoxDecoration(
                color: value ? _toggleBlue : _neutral700,
                borderRadius: BorderRadius.circular(100),
              ),
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: _knobSize,
                height: _knobSize,
                decoration: BoxDecoration(
                  color: value ? HomeFeedTokens.textInverse : _neutral300,
                  shape: BoxShape.circle,
                  boxShadow: value
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CreateFlowBottomButton extends StatelessWidget {
  const CreateFlowBottomButton({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    required this.onTap,
    this.width,
    this.child,
  });

  final String label;
  final Color backgroundColor;
  final Color textColor;
  final VoidCallback? onTap;
  final double? width;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          width: width,
          height: 32,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: child ??
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                ),
          ),
        ),
      ),
    );
  }
}
