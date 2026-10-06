import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/home_feed_tokens.dart';

/// Bottom-sheet prompt for a collection name — shared by "create a new
/// collection" and "rename an existing one". Returns the trimmed name, or
/// null if cancelled.
class CollectionNameSheet extends StatefulWidget {
  const CollectionNameSheet({
    super.key,
    this.initialName = '',
    this.title = 'New collection',
    this.actionLabel = 'Create',
  });

  final String initialName;
  final String title;
  final String actionLabel;

  static Future<String?> show(
    BuildContext context, {
    String initialName = '',
    String title = 'New collection',
    String actionLabel = 'Create',
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: HomeFeedTokens.detailBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => CollectionNameSheet(
        initialName: initialName,
        title: title,
        actionLabel: actionLabel,
      ),
    );
  }

  @override
  State<CollectionNameSheet> createState() => _CollectionNameSheetState();
}

class _CollectionNameSheetState extends State<CollectionNameSheet> {
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
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: HomeFeedTokens.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: 'Collection name',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.inter(color: HomeFeedTokens.textSecondary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _submit,
                    child: Text(
                      widget.actionLabel,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: HomeFeedTokens.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
