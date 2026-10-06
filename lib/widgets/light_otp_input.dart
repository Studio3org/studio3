import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

/// Light-skinned 6-digit OTP field, styled to match [PillInput] (fully
/// rounded, white fill, slate border) for use in Settings-launched flows
/// (e.g. change email) — a separate widget from `AuthOtpInput` since that
/// one is hardcoded to the dark auth-screen palette.
class LightOtpInput extends StatelessWidget {
  const LightOtpInput({
    super.key,
    required this.controller,
    this.onChanged,
    this.length = 6,
  });

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final int length;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppDims.pillInputHeight,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: length,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: 8,
          color: AppColors.slate800,
        ),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: AppColors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9999),
            borderSide: const BorderSide(color: AppColors.slate200, width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9999),
            borderSide: const BorderSide(color: AppColors.slate200, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9999),
            borderSide: const BorderSide(color: AppColors.slate800, width: 1.5),
          ),
        ),
      ),
    );
  }
}
