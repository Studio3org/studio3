import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/studio_event.dart';
import '../services/saved_content_store.dart';
import '../theme/studio_colors.dart';
import '../theme/studio_metrics.dart';
import '../theme/studio_type.dart';
import 'collection_saved_toast.dart';
import 'save_to_collection_sheet.dart';
import 'studio/studio_toast.dart';

/// Saving, as on Instagram, for anything with a Save (a piece, a Scene, an event): the save
/// happens at once, into All saved, and a bar comes up with the picture, "Added to
/// Collection" and "Save to collection". That opens every folder (with New collection last);
/// the ones it is already in come ticked, and Done puts it in or takes it out of each.
///
/// [targetType] is the server's name for it: `piece`, `post` (a Scene) or `event`.
void showSavedBar(
  BuildContext context, {
  required String entryId,
  required String targetType,
  String? title,
  String? thumbnailUrl,
  bool forSale = false,
  String message = 'Added to Collection',
  double bottomMargin = 16,
}) {
  final c = context.studio;
  final messenger = ScaffoldMessenger.of(context);
  // The sheet opens over whatever is on screen when the button is tapped, even if the page
  // that saved has gone since.
  final navigator = Navigator.of(context, rootNavigator: true);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 4),
      backgroundColor: c.buttonFill,
      margin: EdgeInsets.fromLTRB(16, 0, 16, bottomMargin),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(StudioRadius.button)),
      padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
      content: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 36,
              height: 36,
              child: (thumbnailUrl != null && thumbnailUrl.isNotEmpty)
                  ? CachedNetworkImage(
                      imageUrl: thumbnailUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => ColoredBox(color: c.buttonText.withValues(alpha: 0.15)),
                    )
                  : ColoredBox(color: c.buttonText.withValues(alpha: 0.15)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: StudioType.label13(weight: StudioType.medium, color: c.buttonText),
            ),
          ),
          TextButton(
            onPressed: () {
              messenger.hideCurrentSnackBar();
              if (!navigator.mounted) return;
              chooseCollections(
                navigator.context,
                entryId: entryId,
                targetType: targetType,
                title: title,
                thumbnailUrl: thumbnailUrl,
                forSale: forSale,
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: c.buttonText,
              minimumSize: const Size(44, 44),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            child: Text(
              'Save to collection',
              style: StudioType.label13(weight: StudioType.medium, color: c.buttonText).copyWith(
                decoration: TextDecoration.underline,
                decorationColor: c.buttonText,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// After an event's Save: the bar with "Save to collection", or "Removed from Collection".
void announceEventSave(BuildContext context, StudioEvent event, {required bool saved}) {
  final cover = event.coverMediaUrl;
  if (saved) {
    showSavedBar(context, entryId: event.id, targetType: 'event', title: event.title, thumbnailUrl: cover);
  } else {
    showCollectionSavedToast(context, saved: false, thumbnailUrl: cover);
  }
}

/// Every folder, the ones holding [entryId] ticked; Done adds it to the newly ticked and takes
/// it out of the unticked. New collection makes a folder and ticks it. Returns the folders it
/// is in afterwards, or null when the sheet was closed.
Future<List<String>?> chooseCollections(
  BuildContext context, {
  required String entryId,
  required String targetType,
  String? title,
  String? thumbnailUrl,
  bool forSale = false,
}) async {
  final store = SavedContentStore.instance;
  final before = {
    for (final collection in store.collections)
      if (collection.entryIds.contains(entryId)) collection.id,
  };
  final picked = await SaveToCollectionSheet.pick(
    context,
    pieceTitle: title,
    thumbnailUrl: thumbnailUrl,
    forSale: forSale,
    initiallySelected: before,
  );
  if (picked == null) return null;
  final after = picked.toSet();
  for (final id in after.difference(before)) {
    store.addEntryToCollection(id, entryId, targetType: targetType);
  }
  for (final id in before.difference(after)) {
    store.removeEntryFromCollection(id, entryId, targetType: targetType);
  }
  final added = after.difference(before);
  if (added.isNotEmpty && context.mounted) {
    final names = [
      for (final collection in store.collections)
        if (added.contains(collection.id)) collection.name,
    ];
    showStudioToast(context, names.length == 1 ? 'Saved to ${names.first}' : 'Saved to ${names.length} collections');
  }
  return after.toList();
}
