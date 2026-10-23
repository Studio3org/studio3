import 'package:flutter/material.dart';

import '../models/piece_summary.dart';
import '../models/post_summary.dart';
import '../services/api_exception.dart';
import '../services/auth_session.dart';
import '../services/piece_service.dart';
import '../services/post_service.dart';
import '../theme/studio_colors.dart';
import '../theme/studio_type.dart';
import '../widgets/create_flow/link_piece_sheet.dart';
import '../widgets/create_flow/post_flow_widgets.dart';
import '../widgets/studio/studio_field.dart';
import '../widgets/studio/studio_switch.dart';
import '../widgets/studio/studio_toast.dart';
import '../widgets/studio/studio_top_bar.dart';
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
  /// The pieces it shows on, in order, with their titles.
  late List<String> _linkedIds;
  final Map<String, String> _titles = {};
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _caption = TextEditingController(text: widget.post.caption);
    _isProcess = widget.post.isProcess;
    _linkedIds = widget.post.linkedPieceIds.isNotEmpty
        ? List.of(widget.post.linkedPieceIds)
        : [?widget.post.pieceId];
    final first = widget.post.linkedPiece;
    if (first != null) _titles[first.id] = first.title;
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
      if (mounted) showStudioToast(context, 'Could not load your pieces', icon: null);
      return;
    }
    if (!mounted) return;
    for (final p in pieces) {
      _titles[p.id] = p.title;
    }
    final picked = await LinkPieceSheet.show(context, pieces: pieces, selectedIds: _linkedIds);
    if (picked == null || !mounted) return;
    setState(() => _linkedIds = picked.map((p) => p.id).toList());
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final body = <String, dynamic>{
      if (_caption.text.trim().isNotEmpty) 'caption': _caption.text.trim(),
      'isProcess': _isProcess,
      'linkedPieceIds': _linkedIds,
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

  /// No board: the light Studio form — underline caption, a Studio switch, linked pieces as
  /// a chevron row, errors in Ink.
  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final linked = _linkedIds.map((id) => _titles[id] ?? 'A piece').join(', ');
    return StudioLoadingGate(
      loading: _saving,
      child: Scaffold(
        backgroundColor: c.background,
        appBar: StudioTopBar(
          context: context,
          title: 'Edit Scene',
          actions: [StudioSaveAction(onPressed: _saving ? null : _save)],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          children: [
            StudioUnderlineField(
              label: 'Caption',
              controller: _caption,
              hint: 'Every piece has a behind-the-scenes. This is yours…',
              maxLines: 5,
              minLines: 1,
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Work in progress',
                      style: StudioType.sans(16, color: c.textPrimary),
                    ),
                  ),
                  StudioSwitch(
                    value: _isProcess,
                    semanticLabel: 'Work in progress',
                    onChanged: (v) => setState(() => _isProcess = v),
                  ),
                ],
              ),
            ),
            PostChevronRow(
              label: 'Linked pieces',
              value: _linkedIds.isEmpty ? null : linked,
              placeholder: 'Optional',
              onTap: _pickLinkedPiece,
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: StudioType.body14(color: c.textPrimary)),
            ],
          ],
        ),
      ),
    );
  }
}
