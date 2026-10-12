import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/saved_content_store.dart';
import '../theme/home_feed_tokens.dart';
import 'collection_name_sheet.dart';

/// Where a save action resolved to: the default "Saved" bucket (no
/// collection) or a specific collection.
class SaveToCollectionChoice {
  const SaveToCollectionChoice({this.collectionId});

  final String? collectionId;
}

/// Outcome of [resolveSaveCollection]: either the save was cancelled (sheet
/// dismissed without picking a row), or it should proceed into the given
/// collection (`null` collectionId means the default "Saved" bucket).
class SaveResolution {
  const SaveResolution._(this.cancelled, this.collectionId);

  factory SaveResolution.proceed(String? collectionId) =>
      SaveResolution._(false, collectionId);

  static const proceedDefault = SaveResolution._(false, null);
  static const cancelledResult = SaveResolution._(true, null);

  final bool cancelled;
  final String? collectionId;
}

/// Resolves which collection (if any) a save action should land in.
///
/// If the user has never created a collection, this returns immediately
/// without showing anything — saving stays exactly as direct as it is
/// today. Once at least one collection exists, this shows the "Save in"
/// picker; dismissing it without a choice cancels the save entirely.
Future<SaveResolution> resolveSaveCollection(BuildContext context) async {
  if (!SavedContentStore.instance.hasCollections) {
    return SaveResolution.proceedDefault;
  }
  final choice = await SaveToCollectionSheet.show(context);
  if (choice == null) return SaveResolution.cancelledResult;
  return SaveResolution.proceed(choice.collectionId);
}

/// Instagram-style "Save in" picker shown when saving into a device that
/// already has one or more collection folders.
class SaveToCollectionSheet extends StatelessWidget {
  const SaveToCollectionSheet({super.key});

  static Future<SaveToCollectionChoice?> show(BuildContext context) {
    return showModalBottomSheet<SaveToCollectionChoice>(
      context: context,
      backgroundColor: HomeFeedTokens.detailBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => const SaveToCollectionSheet(),
    );
  }

  Future<void> _createNewCollection(BuildContext context) async {
    final name = await CollectionNameSheet.show(context);
    if (name == null || name.isEmpty || !context.mounted) return;
    final collection = await SavedContentStore.instance.createCollection(name);
    if (!context.mounted) return;
    Navigator.pop(
      context,
      SaveToCollectionChoice(collectionId: collection.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final collections = SavedContentStore.instance.collections;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Save in',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: HomeFeedTokens.textPrimary,
                  ),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.bookmark_outline),
              title: Text(
                'Saved',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: HomeFeedTokens.textPrimary,
                ),
              ),
              onTap: () => Navigator.pop(context, const SaveToCollectionChoice()),
            ),
            for (final collection in collections)
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(
                  collection.name,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: HomeFeedTokens.textPrimary,
                  ),
                ),
                trailing: Text(
                  '${collection.entryIds.length}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: HomeFeedTokens.textSecondary,
                  ),
                ),
                onTap: () => Navigator.pop(
                  context,
                  SaveToCollectionChoice(collectionId: collection.id),
                ),
              ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.add),
              title: Text(
                'Create new collection',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: HomeFeedTokens.textPrimary,
                ),
              ),
              onTap: () => _createNewCollection(context),
            ),
          ],
        ),
      ),
    );
  }
}
