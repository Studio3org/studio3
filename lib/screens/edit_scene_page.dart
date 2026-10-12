import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/piece_summary.dart';
import '../models/post_summary.dart';
import '../services/api_exception.dart';
import '../services/auth_session.dart';
import '../services/piece_service.dart';
import '../services/post_service.dart';
import '../theme/home_feed_tokens.dart';
import '../widgets/studio_loading.dart';

class EditScenePage extends StatefulWidget {
  const EditScenePage({super.key, required this.post});

  final PostSummary post;

  @override
  State<EditScenePage> createState() => _EditScenePageState();
}

class _EditScenePageState extends State<EditScenePage> {
  late final TextEditingController _caption;
  bool _isProcess = false;
  String? _linkedPieceId;
  String? _linkedPieceTitle;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _caption = TextEditingController(text: widget.post.caption);
    _isProcess = widget.post.isProcess;
    _linkedPieceId = widget.post.pieceId;
    _linkedPieceTitle = widget.post.linkedPiece?.title;
  }

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _pickLinkedPiece() async {
    final username = AuthSession.instance.user?.username;
    if (username == null || username.isEmpty) return;
    List<PieceSummary> pieces;
    try {
      pieces = await PieceService.instance.getUserPieces(username);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load your pieces')),
      );
      return;
    }
    if (!mounted) return;
    final selected = await showModalBottomSheet<PieceSummary?>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _PiecePicker(pieces: pieces, selectedId: _linkedPieceId),
    );
    if (!mounted) return;
    setState(() {
      _linkedPieceId = selected?.id;
      _linkedPieceTitle = selected?.title;
    });
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final body = <String, dynamic>{
      if (_caption.text.trim().isNotEmpty) 'caption': _caption.text.trim(),
      'isProcess': _isProcess,
      'linkedPieceId': _linkedPieceId,
    };
    try {
      await PostService.instance.update(widget.post.id, body);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'Could not save changes';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StudioLoadingGate(
      loading: _saving,
      child: Scaffold(
        backgroundColor: HomeFeedTokens.background,
        appBar: AppBar(
          backgroundColor: HomeFeedTokens.background,
          elevation: 0,
          title: Text(
            'Edit scene',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: HomeFeedTokens.textPrimary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: _saving ? null : _save,
              child: Text(
                'Save',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: HomeFeedTokens.textPrimary,
                ),
              ),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Caption',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: HomeFeedTokens.textPrimary.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _caption,
              maxLines: 4,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Process / work-in-progress scene'),
              value: _isProcess,
              onChanged: (v) => setState(() => _isProcess = v),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _pickLinkedPiece,
              child: Text(_linkedPieceTitle ?? 'Link to a piece (optional)'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: GoogleFonts.inter(fontSize: 12, color: Colors.red.shade700),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PiecePicker extends StatelessWidget {
  const _PiecePicker({required this.pieces, this.selectedId});

  final List<PieceSummary> pieces;
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Link to piece',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          ListTile(
            leading: Icon(
              selectedId == null ? Icons.radio_button_checked : Icons.radio_button_off,
            ),
            title: const Text('None'),
            onTap: () => Navigator.pop(context),
          ),
          for (final piece in pieces)
            ListTile(
              leading: Icon(
                selectedId == piece.id
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
              ),
              title: Text(piece.title),
              onTap: () => Navigator.pop(context, piece),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
