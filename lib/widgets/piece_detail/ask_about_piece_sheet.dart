import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/api_exception.dart';
import '../../services/chat_service.dart';
import '../../theme/collect_detail_tokens.dart';

/// Compose sheet for messaging an artist about one of their pieces.
///
/// Goes through Conversations, not the inquiries API: that blueprint is deliberately
/// unregistered on the server, so every send from here used to 404. Inquiries were a
/// piece-scoped DM; general conversations replaced them, which is why this takes the
/// artist's username and mentions the piece in the opening message instead.
class AskAboutPieceSheet extends StatefulWidget {
  const AskAboutPieceSheet({
    super.key,
    required this.artistUsername,
    required this.pieceTitle,
  });

  /// Who the message goes to. Conversations are between people, not about objects.
  final String artistUsername;

  /// Named in the opening message so the artist knows which work is meant.
  final String pieceTitle;

  static Future<bool?> show(
    BuildContext context, {
    required String artistUsername,
    required String pieceTitle,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.2),
      builder: (context) => AskAboutPieceSheet(
        artistUsername: artistUsername,
        pieceTitle: pieceTitle,
      ),
    );
  }

  @override
  State<AskAboutPieceSheet> createState() => _AskAboutPieceSheetState();
}

class _AskAboutPieceSheetState extends State<AskAboutPieceSheet> {
  final _controller = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final message = _controller.text.trim();
    if (message.isEmpty) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      // The piece is named in the body because a conversation has no piece field — the
      // artist would otherwise get a bare message with no idea which work it refers to.
      final title = widget.pieceTitle.trim();
      final body = title.isEmpty ? message : 'Re: $title\n\n$message';
      await ChatService.instance.startConversation(widget.artistUsername, body);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'Could not send message';
        _sending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Material(
          color: CollectDetailTokens.sheetBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ask about this piece',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: CollectDetailTokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _controller,
                  autofocus: true,
                  maxLines: 4,
                  minLines: 3,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: CollectDetailTokens.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Ask the artist a question…',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 14,
                      color: CollectDetailTokens.textSecondary,
                    ),
                    filled: true,
                    fillColor: CollectDetailTokens.sheetCardFill,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.red.shade300),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  height: CollectDetailTokens.collectButtonHeight,
                  width: double.infinity,
                  child: Material(
                    color: _sending
                        ? CollectDetailTokens.ctaFill.withValues(alpha: 0.5)
                        : CollectDetailTokens.ctaFill,
                    borderRadius: BorderRadius.circular(
                      CollectDetailTokens.collectButtonRadius,
                    ),
                    child: InkWell(
                      onTap: _sending ? null : _send,
                      borderRadius: BorderRadius.circular(
                        CollectDetailTokens.collectButtonRadius,
                      ),
                      child: Center(
                        child: _sending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: CollectDetailTokens.textInverse,
                                ),
                              )
                            : Text(
                                'Send',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w400,
                                  color: CollectDetailTokens.textInverse,
                                ),
                              ),
                      ),
                    ),
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
