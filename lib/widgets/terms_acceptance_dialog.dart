import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../theme/home_feed_tokens.dart';

/// Blocking prompt for a signed-in account that hasn't agreed to the current
/// Terms of Use (EULA) — accounts created before the terms existed, or any
/// account after the terms are revised. The only ways out are agreeing or
/// logging out, so nobody keeps posting without having accepted them.
Future<void> showTermsAcceptanceDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (_) => const PopScope(
      canPop: false,
      child: _TermsAcceptanceDialog(),
    ),
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
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Couldn't save that — please try again. ($e)")),
      );
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
    return AlertDialog(
      backgroundColor: HomeFeedTokens.background,
      title: Text(
        'Terms of Use',
        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 18),
      ),
      content: Text(
        'To keep using your Studio3 account, please review and agree to our '
        'Terms of Use (EULA). Studio3 has zero tolerance for objectionable '
        'content or abusive users — violating content is removed and the '
        'accounts behind it are ejected.',
        style: GoogleFonts.inter(fontSize: 14, height: 1.45),
      ),
      actionsOverflowButtonSpacing: 4,
      actions: [
        TextButton(
          onPressed: _saving
              ? null
              : () => Navigator.of(context).pushNamed('/terms'),
          child: const Text('Read terms'),
        ),
        TextButton(
          onPressed: _saving ? null : _logOut,
          child: const Text('Log out'),
        ),
        FilledButton(
          onPressed: _saving ? null : _agree,
          style: FilledButton.styleFrom(
            backgroundColor: HomeFeedTokens.textPrimary,
            foregroundColor: HomeFeedTokens.textInverse,
          ),
          child: Text(_saving ? 'Saving…' : 'I agree'),
        ),
      ],
    );
  }
}
