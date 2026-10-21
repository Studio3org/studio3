import 'package:flutter/material.dart';

import 'auth_ui.dart';

/// Six underline slots (`SignIn2Code`), shared with the signup code step.
/// Settings flows such as change-email pass their own [controller].
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
    return StudioOtpSlots(
      controller: controller,
      onChanged: onChanged,
      length: length,
    );
  }
}
