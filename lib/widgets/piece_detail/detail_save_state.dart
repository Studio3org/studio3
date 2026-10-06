import 'package:flutter/material.dart';

import '../../models/feed_preview_item.dart';
import '../../services/engagement_store.dart';
import '../../services/saved_content_store.dart';
import '../../services/social_service.dart';
import '../collection_saved_toast.dart';
import '../save_to_collection_sheet.dart';

/// Shared save-state wiring for piece detail pages.
mixin DetailSaveState<T extends StatefulWidget> on State<T> {
  final SavedContentStore savedStore = SavedContentStore.instance;
  final EngagementStore engagementStore = EngagementStore.instance;
  bool saved = false;
  bool _saveBusy = false;
  bool _ownStoreWrite = false;
  int _saveGeneration = 0;

  FeedPreviewItem get saveItem;

  /// Bottom margin for the "Added to Collection" toast — override to clear
  /// any bottom bar/overlay sitting above the default SnackBar position.
  double get saveToastBottomMargin => 16;

  bool _resolveSaved(FeedPreviewItem item) {
    return engagementStore.resolveSaved(
      item.id,
      savedStore.isSaved(item.id) || item.isSaved,
    );
  }

  @override
  void initState() {
    super.initState();
    saved = _resolveSaved(saveItem);
    savedStore.addListener(onSavedStoreChanged);
    engagementStore.addListener(onSavedStoreChanged);
  }

  @override
  void dispose() {
    savedStore.removeListener(onSavedStoreChanged);
    engagementStore.removeListener(onSavedStoreChanged);
    super.dispose();
  }

  void applySaveItem(FeedPreviewItem item) {
    if (!mounted || _saveBusy) return;
    final nextSaved = _resolveSaved(item);
    if (nextSaved != saved) {
      setState(() => saved = nextSaved);
    }
  }

  void onSavedStoreChanged() {
    if (_ownStoreWrite || _saveBusy) return;
    final nextSaved = _resolveSaved(saveItem);
    if (nextSaved != saved && mounted) {
      setState(() => saved = nextSaved);
    }
  }

  Future<void> toggleSave() async {
    if (_saveBusy) return;
    final item = saveItem;
    final nextSaved = !saved;

    String? collectionId;
    if (nextSaved) {
      final resolution = await resolveSaveCollection(context);
      if (resolution.cancelled) return;
      collectionId = resolution.collectionId;
    }

    final generation = ++_saveGeneration;
    setState(() => saved = nextSaved);
    engagementStore.setSaved(item.id, nextSaved);

    if (!item.isApiBacked) {
      if (nextSaved) {
        savedStore.savePreview(item);
        if (collectionId != null) {
          savedStore.addEntryToCollection(
            collectionId,
            item.id,
            targetType: item.isScene ? 'post' : 'piece',
          );
        }
      } else {
        savedStore.unsave(item.id);
      }
      return;
    }

    _saveBusy = true;
    try {
      if (nextSaved) {
        if (item.isScene) {
          await SocialService.instance.savePost(item.id);
        } else {
          await SocialService.instance.savePiece(item.id);
        }
        _ownStoreWrite = true;
        savedStore.savePreview(item);
        if (collectionId != null) {
          savedStore.addEntryToCollection(
            collectionId,
            item.id,
            targetType: item.isScene ? 'post' : 'piece',
          );
        }
        _ownStoreWrite = false;
      } else {
        if (item.isScene) {
          await SocialService.instance.unsavePost(item.id);
        } else {
          await SocialService.instance.unsavePiece(item.id);
        }
        _ownStoreWrite = true;
        savedStore.unsave(item.id);
        _ownStoreWrite = false;
      }
      if (mounted && generation == _saveGeneration) {
        showCollectionSavedToast(
          context,
          saved: nextSaved,
          thumbnailUrl: item.heroImageUrl,
          bottomMargin: saveToastBottomMargin,
        );
      }
    } catch (_) {
      if (mounted && generation == _saveGeneration) {
        setState(() => saved = !nextSaved);
        engagementStore.setSaved(item.id, !nextSaved);
      }
    } finally {
      if (generation == _saveGeneration) _saveBusy = false;
    }
  }
}

/// Like toggle for API-backed piece/scene detail pages.
mixin DetailLikeState<T extends StatefulWidget> on State<T> {
  bool liked = false;
  int likeCount = 0;
  bool _likeBusy = false;
  int _likeGeneration = 0;

  FeedPreviewItem get likeItem;

  EngagementStore get _likeEngagement => EngagementStore.instance;

  void applyLikeItem(FeedPreviewItem item) {
    // Never overwrite an in-flight optimistic like with a stale detail fetch.
    if (!mounted || _likeBusy) return;
    final next = _likeEngagement.resolveLiked(item.id, item.isLiked);
    final nextCount = _likeEngagement.resolveLikeCount(item.id, item.likeCount);
    if (next != liked || nextCount != likeCount) {
      setState(() {
        liked = next;
        likeCount = nextCount;
      });
    }
  }

  Future<void> toggleLike() async {
    if (_likeBusy) return;
    final item = likeItem;
    if (!item.isApiBacked) {
      final nextLiked = !liked;
      final nextCount = (likeCount + (nextLiked ? 1 : -1)).clamp(0, 1 << 30);
      setState(() {
        liked = nextLiked;
        likeCount = nextCount;
      });
      _likeEngagement.setLiked(item.id, nextLiked, likeCount: nextCount);
      return;
    }

    final nextLiked = !liked;
    final optimisticCount =
        (likeCount + (nextLiked ? 1 : -1)).clamp(0, 1 << 30);
    final generation = ++_likeGeneration;
    setState(() {
      liked = nextLiked;
      likeCount = optimisticCount;
    });
    _likeEngagement.setLiked(item.id, nextLiked, likeCount: optimisticCount);
    _likeBusy = true;
    try {
      final EngagementToggleResult result;
      if (item.isScene) {
        result = nextLiked
            ? await SocialService.instance.likePost(item.id)
            : await SocialService.instance.unlikePost(item.id);
      } else {
        result = nextLiked
            ? await SocialService.instance.likePiece(item.id)
            : await SocialService.instance.unlikePiece(item.id);
      }
      if (!mounted || generation != _likeGeneration) return;
      final serverCount = result.likeCount;
      if (serverCount != null) {
        setState(() => likeCount = serverCount);
        _likeEngagement.setLiked(item.id, nextLiked, likeCount: serverCount);
      }
    } catch (_) {
      if (mounted && generation == _likeGeneration) {
        final reverted = (likeCount + (nextLiked ? -1 : 1)).clamp(0, 1 << 30);
        setState(() {
          liked = !nextLiked;
          likeCount = reverted;
        });
        _likeEngagement.setLiked(item.id, !nextLiked, likeCount: reverted);
      }
    } finally {
      if (generation == _likeGeneration) _likeBusy = false;
    }
  }
}
