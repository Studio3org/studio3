import 'package:flutter/material.dart';

import '../../services/api_exception.dart';
import '../../services/piece_service.dart';
import '../studio/studio.dart';

/// Hide from my Collection (`PieceCollectedOwner`, B32): hides a piece the viewer collected
/// from their Collection and toasts the server's message with Undo, which puts it back. The
/// purchase itself is untouched. Errors show the server's message.
Future<void> hideFromMyCollection(BuildContext context, String pieceId) async {
  try {
    final message = await PieceService.instance.hideFromCollection(pieceId);
    if (!context.mounted) return;
    showStudioToast(
      context,
      message,
      duration: const Duration(seconds: 5),
      actionLabel: 'Undo',
      onAction: () => unhideFromMyCollection(context, pieceId),
    );
  } on ApiException catch (e) {
    if (context.mounted) showStudioToast(context, e.message, icon: null);
  } catch (_) {
    if (context.mounted) showStudioToast(context, 'Could not hide this piece. Try again.', icon: null);
  }
}

/// Puts a hidden piece back in the viewer's Collection (Undo, and Unhide on their own
/// Collection tab), toasting the server's message. Returns whether it worked.
Future<bool> unhideFromMyCollection(BuildContext context, String pieceId) async {
  try {
    final message = await PieceService.instance.unhideFromCollection(pieceId);
    if (context.mounted) showStudioToast(context, message);
    return true;
  } on ApiException catch (e) {
    if (context.mounted) showStudioToast(context, e.message, icon: null);
  } catch (_) {
    if (context.mounted) showStudioToast(context, 'Could not bring this piece back. Try again.', icon: null);
  }
  return false;
}
