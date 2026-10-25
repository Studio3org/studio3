import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../services/chat_service.dart';
import '../theme/studio_colors.dart';
import '../theme/studio_type.dart';
import '../widgets/accept_decline_buttons.dart';
import '../widgets/inbox/chats_body.dart' show ConversationRow;
import '../widgets/studio/studio_top_bar.dart';
import '../widgets/studio/studio_toast.dart';
import 'conversation_thread_page.dart';

/// Message requests (no board): people who messaged you without a conversation yet. The
/// Messages tab's rows with Accept / Decline; tapping opens the chat. Was a sub-tab of
/// Messages; it sits behind the "Message requests" row now.
class MessageRequestsPage extends StatefulWidget {
  const MessageRequestsPage({super.key, this.initial = const []});

  final List<ConversationSummary> initial;

  @override
  State<MessageRequestsPage> createState() => _MessageRequestsPageState();
}

class _MessageRequestsPageState extends State<MessageRequestsPage> {
  late final List<ConversationSummary> _requests = List.of(widget.initial);
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final page = await ChatService.instance.listRequests();
      if (!mounted) return;
      setState(() {
        _requests
          ..clear()
          ..addAll(page.items);
      });
    } catch (_) {}
  }

  Future<void> _accept(ConversationSummary r) async {
    setState(() => _busy.add(r.id));
    try {
      await ChatService.instance.acceptRequest(r.id);
      if (mounted) setState(() => _requests.removeWhere((x) => x.id == r.id));
    } catch (_) {
      if (mounted) showStudioToast(context, "Couldn't accept the request", icon: null);
    } finally {
      if (mounted) setState(() => _busy.remove(r.id));
    }
  }

  Future<void> _decline(ConversationSummary r) async {
    setState(() => _busy.add(r.id));
    try {
      await ChatService.instance.declineRequest(r.id);
    } catch (_) {
      // Treated as handled either way.
    } finally {
      if (mounted) {
        setState(() {
          _requests.removeWhere((x) => x.id == r.id);
          _busy.remove(r.id);
        });
      }
    }
  }

  Future<void> _open(ConversationSummary r) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ConversationThreadPage(
          conversationId: r.id,
          otherPartyId: r.otherPartyId,
          otherPartyUsername: r.otherPartyUsername,
          otherPartyName: r.otherPartyDisplayName,
          otherPartyAvatarUrl: r.otherPartyAvatarUrl,
          initialStatus: r.status,
        ),
      ),
    );
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return Scaffold(
      backgroundColor: c.background,
      appBar: StudioTopBar(context: context, title: 'Message requests'),
      body: _requests.isEmpty
          ? Center(
              child: Text('No message requests', style: StudioType.body14(color: c.textSecondary)),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                for (final r in _requests)
                  ConversationRow(
                    conversation: r,
                    onTap: () => _open(r),
                    trailing: AcceptDeclineButtons(
                      busy: _busy.contains(r.id),
                      onAccept: () => _accept(r),
                      onDecline: () => _decline(r),
                    ),
                  ),
              ],
            ),
    );
  }
}
