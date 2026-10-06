import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Bottom-center pill shown when previewing your own profile as a viewer.
class ProfileViewerModeCapsule extends StatelessWidget {
  const ProfileViewerModeCapsule({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        child: Text(
          'Viewing your profile as others see it',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.92),
            height: 1.2,
          ),
        ),
      ),
    );
  }
}
