import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/home_feed_tokens.dart';

/// Prompt for a new series name. Returns trimmed name or null if cancelled.
class CreateSeriesDialog extends StatefulWidget {
  const CreateSeriesDialog({
    super.key,
    this.initialName = '',
    this.title = 'New series',
  });

  final String initialName;
  final String title;

  static Future<String?> show(
    BuildContext context, {
    String initialName = '',
    String title = 'New series',
  }) {
    return showDialog<String>(
      context: context,
      builder: (context) => CreateSeriesDialog(
        initialName: initialName,
        title: title,
      ),
    );
  }

  @override
  State<CreateSeriesDialog> createState() => _CreateSeriesDialogState();
}

class _CreateSeriesDialogState extends State<CreateSeriesDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: HomeFeedTokens.background,
      title: Text(
        widget.title,
        style: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: HomeFeedTokens.textPrimary,
        ),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          hintText: 'Series name',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: GoogleFonts.inter(color: HomeFeedTokens.textSecondary),
          ),
        ),
        TextButton(
          onPressed: _submit,
          child: Text(
            'Create',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: HomeFeedTokens.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
