import 'dart:ui';

import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../theme/studio_colors.dart';
import '../theme/studio_metrics.dart';
import '../theme/studio_type.dart';
import 'studio/studio_toast.dart';

/// Blocking prompt for a signed-in account that hasn't agreed to the current
/// Terms of Use (EULA) — accounts created before the terms existed, or any
/// account after the terms are revised. The only ways out are agreeing or
/// logging out, so nobody keeps posting without having accepted them.
Future<void> showTermsAcceptanceDialog(BuildContext context) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Terms of Use',
    barrierColor: const Color(0x00000000),
    useRootNavigator: true,
    pageBuilder: (context, animation, secondaryAnimation) {
      return const PopScope(
        canPop: false,
        child: _TermsAcceptanceDialog(),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: ColoredBox(
          color: const Color(0x47000000),
          child: FadeTransition(opacity: animation, child: child),
        ),
      );
    },
  );
}

class _TermsAcceptanceDialog extends StatefulWidget {
  const _TermsAcceptanceDialog();

  @override
  State<_TermsAcceptanceDialog> createState() => _TermsAcceptanceDialogState();
}

class _TermsAcceptanceDialogState extends State<_TermsAcceptanceDialog> {
  bool _saving = false;

  Future<void> _agree() async {
    setState(() => _saving = true);
    try {
      await UserService.instance.acceptTerms();
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      showStudioToast(context, "Couldn't save that — please try again.", icon: null);
    }
  }

  Future<void> _logOut() async {
    final navigator = Navigator.of(context);
    navigator.pop();
    // AuthGate reacts to the signed-out session and returns to /login.
    await AuthService.instance.logout();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final label = StudioType.body14(weight: StudioType.medium, color: c.textPrimary);
    return AlertDialog(
      backgroundColor: c.background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(StudioRadius.button)),
      title: Text('Terms of Use', style: StudioType.header17(color: c.textPrimary)),
      content: Text(
        'To keep using your Studio3 account, please review and agree to our '
        'Terms of Use (EULA). Studio3 has zero tolerance for objectionable '
        'content or abusive users — violating content is removed and the '
        'accounts behind it are ejected.',
        style: StudioType.body14(height: 1.45, color: c.textBody),
      ),
      actionsOverflowButtonSpacing: 4,
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pushNamed('/terms'),
          child: Text('Read terms', style: label),
        ),
        TextButton(
          onPressed: _saving ? null : _logOut,
          child: Text('Log out', style: label),
        ),
        FilledButton(
          onPressed: _saving ? null : _agree,
          style: FilledButton.styleFrom(
            backgroundColor: c.buttonFill,
            foregroundColor: c.buttonText,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(StudioRadius.button)),
          ),
          child: Text(
            _saving ? 'Saving…' : 'I agree',
            style: StudioType.body14(weight: StudioType.medium, color: c.buttonText),
          ),
        ),
      ],
    );
  }
}
