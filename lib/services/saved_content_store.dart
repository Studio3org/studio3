import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/feed_item.dart';
import '../models/feed_preview_item.dart';
import '../models/piece_summary.dart';
import '../models/post_summary.dart';
import 'cache_service.dart';
import 'engagement_store.dart';
import 'social_service.dart';

enum SavedContentKind { piece, scene }

enum SavedContentFilter { all, piece, scene }

class SavedEntry {
  const SavedEntry({
    required this.id,
    required this.kind,
    this.preview,
    this.feedItem,
    this.savedAt = 0,
  });

  final String id;
  final SavedContentKind kind;
  final FeedPreviewItem? preview;
  final FeedItem? feedItem;

  /// Epoch ms when this item was saved — used to pick a "most recent" cover
  /// for the "Saved" folder tile. Defaults to 0 for cache entries written
  /// before this field existed, so they simply sort to the back.
  final int savedAt;

  String get title =>
      preview?.title ?? feedItem?.title ?? feedItem?.post?.caption ?? 'Saved';

  String get authorName =>
      preview?.displayName ?? feedItem?.authorName ?? 'Artist';

  bool get isVideoScene =>
      feedItem?.isVideo == true || preview?.medium == 'Video';

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'savedAt': savedAt,
    if (preview != null) 'preview': preview!.toJson(),
    if (feedItem != null) 'feedItem': feedItem!.toJson(),
  };

  factory SavedEntry.fromJson(Map<String, dynamic> json) {
    final feedItemJson = json['feedItem'] as Map<String, dynamic>?;
    return SavedEntry(
      id: json['id'] as String? ?? '',
      kind: json['kind'] == 'piece'
          ? SavedContentKind.piece
          : SavedContentKind.scene,
      savedAt: json['savedAt'] as int? ?? 0,
      preview: json['preview'] != null
          ? FeedPreviewItem.fromCacheJson(
              json['preview'] as Map<String, dynamic>,
            )
          : null,
      feedItem: feedItemJson != null ? FeedItem.fromJson(feedItemJson) : null,
    );
  }
}

/// A user-created folder grouping saved pieces/scenes, Instagram-style.
class SavedCollection {
  const SavedCollection({
    required this.id,
    required this.name,
    required this.createdAt,
    this.entryIds = const [],
  });

  final String id;
  final String name;
  final DateTime createdAt;

  /// Ids of saved entries in this collection, most-recently-added first.
  final List<String> entryIds;

  SavedCollection copyWith({String? name, List<String>? entryIds}) =>
      SavedCollection(
        id: id,
        name: name ?? this.name,
        createdAt: createdAt,
        entryIds: entryIds ?? this.entryIds,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'entryIds': entryIds,
  };

  factory SavedCollection.fromJson(Map<String, dynamic> json) {
    return SavedCollection(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        json['createdAt'] as int? ?? 0,
      ),
      entryIds: (json['entryIds'] as List?)?.cast<String>() ?? const [],
    );
  }
}

/// Resolves the thumbnail to show for a saved entry, shared by the flat
/// saved grid and the folder tiles so both fall back the same way.
String? savedEntryThumbnailUrl(SavedEntry entry) {
  final preview = entry.preview;
  if (preview != null) {
    return preview.heroImageUrl ?? feedPreviewImageUrl(preview);
  }
  return entry.feedItem?.mediaUrl;
}

/// Local store for pieces and scenes saved from For You and scene videos.
/// Persisted to disk (via [CacheService]) so saved items survive app
/// restarts instead of living only in memory.
class SavedContentStore extends ChangeNotifier {
  SavedContentStore._();
  static final SavedContentStore instance = SavedContentStore._();

  static const _storageKey = 'saved_content.entries';
  static const _collectionsStorageKey = 'saved_content.collections';

  final Map<String, SavedEntry> _entries = {};
  final List<SavedCollection> _collections = [];

  /// Restores previously saved entries and collections from disk. Call once
  /// at startup, before any screen that reads from this store builds.
  Future<void> load() async {
    final raw = CacheService.instance.readRaw(_storageKey);
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List;
        for (final e in list) {
          final entry = SavedEntry.fromJson(e as Map<String, dynamic>);
          if (entry.id.isNotEmpty) _entries[entry.id] = entry;
        }
      } catch (_) {
        // Corrupt/old-format cache entry — ignore and start empty rather
        // than crash the app on startup.
      }
    }

    final rawCollections = CacheService.instance.readRaw(
      _collectionsStorageKey,
    );
    if (rawCollections != null) {
      try {
        final list = jsonDecode(rawCollections) as List;
        _collections
          ..clear()
          ..addAll(
            list.map(
              (e) => SavedCollection.fromJson(e as Map<String, dynamic>),
            ),
          );
      } catch (_) {
        // Corrupt collections cache — keep saved entries intact regardless.
      }
    }

    notifyListeners();
  }

  Future<void> _persistEntries() => CacheService.instance.writeRaw(
    _storageKey,
    jsonEncode(_entries.values.map((e) => e.toJson()).toList()),
  );

  Future<void> _persistCollections() => CacheService.instance.writeRaw(
    _collectionsStorageKey,
    jsonEncode(_collections.map((c) => c.toJson()).toList()),
  );

  /// Clears saved items and collections on logout so a second account on
  /// the same device never sees the previous account's saved list.
  Future<void> clearLocal() async {
    _entries.clear();
    _collections.clear();
    await CacheService.instance.invalidate(_storageKey);
    await CacheService.instance.invalidate(_collectionsStorageKey);
    notifyListeners();
  }

  bool isSaved(String id) => _entries.containsKey(id);

  List<SavedCollection> get collections => List.unmodifiable(_collections);

  bool get hasCollections => _collections.isNotEmpty;

  /// Creates a collection on the backend (so it's visible from other
  /// devices) and mirrors it locally under the server-assigned id. Falls
  /// back to a locally-generated id when offline/API-unavailable — the
  /// collection still works on this device, it just won't sync elsewhere
  /// until it's recreated there.
  Future<SavedCollection> createCollection(String name) async {
    final trimmed = name.trim();
    var id = 'col_${DateTime.now().microsecondsSinceEpoch}';
    var createdAt = DateTime.now();
    try {
      final data = await SocialService.instance.createCollection(trimmed);
      final remoteId = data['id'] as String?;
      if (remoteId != null && remoteId.isNotEmpty) id = remoteId;
      final createdAtRaw = data['createdAt'] as String?;
      if (createdAtRaw != null) {
        createdAt = DateTime.tryParse(createdAtRaw) ?? createdAt;
      }
    } catch (_) {
      // Offline or API error — keep the locally-generated id.
    }
    final collection = SavedCollection(
      id: id,
      name: trimmed,
      createdAt: createdAt,
    );
    _collections.add(collection);
    notifyListeners();
    unawaited(_persistCollections());
    return collection;
  }

  Future<void> renameCollection(String collectionId, String name) async {
    final trimmed = name.trim();
    final index = _collections.indexWhere((c) => c.id == collectionId);
    if (index == -1) return;
    _collections[index] = _collections[index].copyWith(name: trimmed);
    notifyListeners();
    unawaited(_persistCollections());
    unawaited(
      SocialService.instance
          .renameCollection(collectionId, trimmed)
          .catchError((_) {}),
    );
  }

  /// Removes the folder only — saved items inside stay saved (still show
  /// up under the flat "Saved" bucket), matching Instagram.
  Future<void> deleteCollection(String collectionId) async {
    final removed = _collections.any((c) => c.id == collectionId);
    _collections.removeWhere((c) => c.id == collectionId);
    if (removed) {
      notifyListeners();
      unawaited(_persistCollections());
    }
    unawaited(
      SocialService.instance.deleteCollection(collectionId).catchError((_) {}),
    );
  }

  /// Merges collection summaries from the backend into the local list, so
  /// collections created on another device show up here too. Never
  /// touches an already-known collection's `entryIds` — local membership
  /// already reflects this device's saves; full membership only refreshes
  /// on-demand via [loadCollectionDetailFromApi] when a folder is opened.
  Future<void> loadCollectionsFromApi() async {
    try {
      final remote = await SocialService.instance.listCollections();
      var changed = false;
      for (final json in remote) {
        final id = json['id'] as String? ?? '';
        if (id.isEmpty || _collections.any((c) => c.id == id)) continue;
        final createdAtRaw = json['createdAt'] as String?;
        _collections.add(
          SavedCollection(
            id: id,
            name: json['name'] as String? ?? '',
            createdAt: createdAtRaw != null
                ? DateTime.tryParse(createdAtRaw) ?? DateTime.now()
                : DateTime.now(),
          ),
        );
        changed = true;
      }
      if (changed) {
        notifyListeners();
        unawaited(_persistCollections());
      }
    } catch (_) {
      // Offline — keep whatever's cached locally.
    }
  }

  /// Fetches a single collection's full item list from the backend and
  /// hydrates both the shared entries map and this collection's
  /// `entryIds` — used when a folder is opened, so items saved from
  /// another device appear too.
  Future<void> loadCollectionDetailFromApi(String collectionId) async {
    try {
      final detail = await SocialService.instance.getCollectionDetail(
        collectionId,
      );
      final items = (detail['items'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);

      final ids = items
          .map(
            (json) => switch (json['targetType']) {
              'piece' => PieceSummary.fromJson(json).id,
              'post' => PostSummary.fromJson(json).id,
              _ => null,
            },
          )
          .whereType<String>()
          .toList(growable: false);

      // Populate oldest-first so each sequential `DateTime.now()` stamp in
      // savePreview/saveFeedItem keeps the newest item's savedAt largest —
      // `items` itself arrives newest-first from the API.
      for (final json in items.reversed) {
        switch (json['targetType']) {
          case 'piece':
            savePreview(
              FeedPreviewItem.fromPieceSummary(PieceSummary.fromJson(json)),
            );
          case 'post':
            saveFeedItem(FeedItem.post(PostSummary.fromJson(json)));
        }
      }

      final index = _collections.indexWhere((c) => c.id == collectionId);
      if (index != -1) {
        _collections[index] = _collections[index].copyWith(entryIds: ids);
        notifyListeners();
        unawaited(_persistCollections());
      }
    } catch (_) {
      // Offline — keep whatever's cached locally for this collection.
    }
  }

  void addEntryToCollection(
    String collectionId,
    String entryId, {
    required String targetType,
  }) {
    final index = _collections.indexWhere((c) => c.id == collectionId);
    if (index == -1) return;
    final current = _collections[index];
    final entryIds = current.entryIds.where((id) => id != entryId).toList()
      ..insert(0, entryId);
    _collections[index] = current.copyWith(entryIds: entryIds);
    notifyListeners();
    unawaited(_persistCollections());
    unawaited(
      SocialService.instance
          .addToCollection(
            collectionId: collectionId,
            targetType: targetType,
            targetId: entryId,
          )
          .catchError((_) {}),
    );
  }

  void removeEntryFromAllCollections(String entryId, {String? targetType}) {
    var changed = false;
    final affectedCollectionIds = <String>[];
    for (var i = 0; i < _collections.length; i++) {
      final current = _collections[i];
      if (!current.entryIds.contains(entryId)) continue;
      _collections[i] = current.copyWith(
        entryIds: current.entryIds.where((id) => id != entryId).toList(),
      );
      changed = true;
      affectedCollectionIds.add(current.id);
    }
    if (changed) {
      notifyListeners();
      unawaited(_persistCollections());
    }
    if (targetType != null) {
      for (final collectionId in affectedCollectionIds) {
        unawaited(
          SocialService.instance
              .removeFromCollection(
                collectionId: collectionId,
                targetType: targetType,
                targetId: entryId,
              )
              .catchError((_) {}),
        );
      }
    }
  }

  List<SavedEntry> entriesForCollection(
    String collectionId, {
    SavedContentFilter filter = SavedContentFilter.all,
  }) {
    final collection = _collections.firstWhere(
      (c) => c.id == collectionId,
      orElse: () => SavedCollection(
        id: collectionId,
        name: '',
        createdAt: DateTime.now(),
      ),
    );
    final items = collection.entryIds
        .map((id) => _entries[id])
        .whereType<SavedEntry>()
        .toList(growable: false);
    switch (filter) {
      case SavedContentFilter.all:
        return items;
      case SavedContentFilter.piece:
        return items
            .where((entry) => entry.kind == SavedContentKind.piece)
            .toList(growable: false);
      case SavedContentFilter.scene:
        return items
            .where((entry) => entry.kind == SavedContentKind.scene)
            .toList(growable: false);
    }
  }

  /// Most recently saved entry with a usable thumbnail, for the "Saved"
  /// folder tile's cover image.
  SavedEntry? mostRecentEntryOverall() {
    final sorted = _entries.values.toList()
      ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
    for (final entry in sorted) {
      final url = savedEntryThumbnailUrl(entry);
      if (url != null && url.isNotEmpty) return entry;
    }
    return sorted.isEmpty ? null : sorted.first;
  }

  List<SavedEntry> entries({
    SavedContentFilter filter = SavedContentFilter.all,
  }) {
    final all = _entries.values.toList(growable: false);
    switch (filter) {
      case SavedContentFilter.all:
        return all;
      case SavedContentFilter.piece:
        return all
            .where((entry) => entry.kind == SavedContentKind.piece)
            .toList(growable: false);
      case SavedContentFilter.scene:
        return all
            .where((entry) => entry.kind == SavedContentKind.scene)
            .toList(growable: false);
    }
  }

  List<FeedItem> get videoSceneFeedItems => _entries.values
      .where(
        (entry) =>
            entry.kind == SavedContentKind.scene &&
            entry.feedItem != null &&
            entry.feedItem!.isVideo,
      )
      .map((entry) => entry.feedItem!)
      .toList(growable: false);

  void savePreview(FeedPreviewItem item) {
    final kind = item.isScene ? SavedContentKind.scene : SavedContentKind.piece;
    FeedItem? feedItem;
    if (item.isScene && item.medium == 'Video') {
      feedItem = FeedItem.post(
        PostSummary(
          id: item.id,
          caption: item.title,
          mediaUrl: item.heroImageUrl,
          mediaType: 'video',
          authorName: item.displayName,
          authorAvatarUrl: item.authorAvatarUrl,
          authorUsername: item.handle.replaceFirst('@', ''),
        ),
      );
    }
    _entries[item.id] = SavedEntry(
      id: item.id,
      kind: kind,
      preview: item,
      feedItem: feedItem,
      savedAt: DateTime.now().millisecondsSinceEpoch,
    );
    EngagementStore.instance.setSaved(item.id, true);
    notifyListeners();
    unawaited(_persistEntries());
  }

  void saveFeedItem(FeedItem item) {
    FeedPreviewItem? preview;
    if (item.type == FeedItemType.post) {
      preview = FeedPreviewItem.fromFeedItem(item);
    }
    _entries[item.id] = SavedEntry(
      id: item.id,
      kind: SavedContentKind.scene,
      preview: preview,
      feedItem: item,
      savedAt: DateTime.now().millisecondsSinceEpoch,
    );
    EngagementStore.instance.setSaved(item.id, true);
    notifyListeners();
    unawaited(_persistEntries());
  }

  void unsave(String id) {
    final removedEntry = _entries.remove(id);
    if (removedEntry != null) {
      EngagementStore.instance.setSaved(id, false);
      notifyListeners();
      unawaited(_persistEntries());
    }
    removeEntryFromAllCollections(
      id,
      targetType: removedEntry == null
          ? null
          : (removedEntry.kind == SavedContentKind.scene ? 'post' : 'piece'),
    );
  }
}
