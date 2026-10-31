import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../services/permission_service.dart';
import '../../services/photo_library_service.dart';
import '../../theme/studio_colors.dart';
import '../../theme/studio_metrics.dart';
import '../../theme/studio_type.dart';
import '../studio/studio_icon.dart';
import '../studio/studio_on_image.dart';

enum _LoadState { loading, denied, ready }

class _AlbumEntry {
  const _AlbumEntry({required this.path, required this.cover, required this.count});

  final AssetPathEntity path;
  final AssetEntity? cover;
  final int count;
}

/// Custom in-app photo grid + album picker replacing the native OS photo
/// picker, so the post-creation flow can show its own album list.
///
/// `PostPicker`: the page colour, 3 across with 2 gaps, newest first; each pick shows its
/// number in a 22 Ink circle and a 2 Ink outline inside the cell ([PostGalleryCell]). Video
/// length is a plain white Mono image label (no play circle); albums are rows with a Mono
/// count. [onDark] keeps the dark look for the host flyer picker, which sits under a dark bar.
class PostGalleryPicker extends StatefulWidget {
  const PostGalleryPicker({
    super.key,
    required this.openNotifier,
    required this.onAlbumChanged,
    required this.onSelectionChanged,
    required this.onPermissionPermanentlyDenied,
    this.maxSelection = 10,
    this.allowVideos = false,
    this.initialSelection = const [],
    this.onDark = false,
  });

  /// Dark in both themes (the host flyer cover).
  final bool onDark;

  final ValueNotifier<bool> openNotifier;
  final ValueChanged<String> onAlbumChanged;
  final ValueChanged<List<AssetEntity>> onSelectionChanged;
  final VoidCallback onPermissionPermanentlyDenied;
  final int maxSelection;
  /// When true (Scene posts), the grid mixes in videos alongside photos,
  /// uses a 3:4 cell ratio, and selecting a video is exclusive of photos.
  final bool allowVideos;

  /// Already picked (coming back from the cover step), in their order.
  final List<AssetEntity> initialSelection;

  @override
  State<PostGalleryPicker> createState() => _PostGalleryPickerState();
}

class _PostGalleryPickerState extends State<PostGalleryPicker> {
  _LoadState _state = _LoadState.loading;
  List<_AlbumEntry> _albums = const [];
  _AlbumEntry? _selectedAlbum;
  List<AssetEntity> _assets = const [];
  late final List<AssetEntity> _selected = List<AssetEntity>.from(widget.initialSelection);

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final outcome = await PhotoLibraryService.instance
        .ensureAccess(forVideo: widget.allowVideos);
    if (!mounted) return;
    if (outcome != GalleryPermissionOutcome.granted) {
      setState(() => _state = _LoadState.denied);
      if (outcome == GalleryPermissionOutcome.deniedForever) {
        widget.onPermissionPermanentlyDenied();
      }
      return;
    }
    await _loadAlbums();
  }

  Future<void> _loadAlbums() async {
    final paths = await PhotoLibraryService.instance.fetchAlbums(
      type: widget.allowVideos ? RequestType.common : RequestType.image,
    );
    if (!mounted) return;
    final entries = await Future.wait(paths.map((path) async {
      final cover = await PhotoLibraryService.instance.fetchCover(path);
      final count = await path.assetCountAsync;
      return _AlbumEntry(path: path, cover: cover, count: count);
    }));
    if (!mounted) return;
    setState(() => _albums = entries);
    if (entries.isNotEmpty) {
      await _selectAlbum(entries.first);
    }
    if (mounted) setState(() => _state = _LoadState.ready);
  }

  Future<void> _selectAlbum(_AlbumEntry entry) async {
    final assets = await PhotoLibraryService.instance.fetchAssets(entry.path, size: 300);
    if (!mounted) return;
    setState(() {
      _selectedAlbum = entry;
      _assets = assets;
    });
    widget.onAlbumChanged(entry.path.name);
    widget.openNotifier.value = false;
  }

  void _toggleSelect(AssetEntity asset) {
    final index = _selected.indexWhere((a) => a.id == asset.id);
    if (index >= 0) {
      setState(() => _selected.removeAt(index));
      widget.onSelectionChanged(List.unmodifiable(_selected));
      return;
    }
    // Video selection is exclusive: picking a video clears any photos, and
    // picking a photo while a video is selected clears the video first, so
    // the outgoing selection is always either N photos or exactly 1 video.
    if (asset.type == AssetType.video) {
      setState(() {
        _selected
          ..clear()
          ..add(asset);
      });
    } else {
      if (_selected.any((a) => a.type == AssetType.video)) {
        setState(() {
          _selected.clear();
          _selected.add(asset);
        });
      } else {
        if (widget.maxSelection == 1) {
          // Single pick: tapping another photo swaps it in.
          setState(() {
            _selected
              ..clear()
              ..add(asset);
          });
        } else {
          if (_selected.length >= widget.maxSelection) return;
          setState(() => _selected.add(asset));
        }
      }
    }
    widget.onSelectionChanged(List.unmodifiable(_selected));
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _retry() async {
    setState(() => _state = _LoadState.loading);
    await _init();
  }

  _PickerColors get _colors => _PickerColors.of(context, onDark: widget.onDark);

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: _colors.background, child: _buildBody()),
        ValueListenableBuilder<bool>(
          valueListenable: widget.openNotifier,
          builder: (context, open, _) =>
              open ? _buildAlbumMenu() : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case _LoadState.loading:
        return Center(
          child: SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _colors.secondary,
            ),
          ),
        );
      case _LoadState.denied:
        return _PermissionFallback(onRetry: _retry, colors: _colors);
      case _LoadState.ready:
        return GridView.builder(
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
            childAspectRatio: widget.allowVideos ? 3 / 4 : 1.0,
          ),
          itemCount: _assets.length,
          itemBuilder: (context, index) => _buildCell(_assets[index]),
        );
    }
  }

  Widget _buildCell(AssetEntity asset) {
    final index = _selected.indexWhere((a) => a.id == asset.id);
    final isVideo = asset.type == AssetType.video;
    return PostGalleryCell(
      number: index >= 0 ? index + 1 : null,
      videoLength: isVideo ? _formatDuration(asset.videoDuration) : null,
      onDark: widget.onDark,
      onTap: () => _toggleSelect(asset),
      child: _AssetThumbnail(key: ValueKey(asset.id), asset: asset, size: 200, colors: _colors),
    );
  }

  Widget _buildAlbumMenu() {
    final colors = _colors;
    return ColoredBox(
      color: colors.background,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _albums.length,
        itemBuilder: (context, index) {
          final entry = _albums[index];
          final selected = _selectedAlbum?.path.id == entry.path.id;
          return Semantics(
            button: true,
            selected: selected,
            child: GestureDetector(
              onTap: () => _selectAlbum(entry),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(StudioRadius.small),
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: entry.cover != null
                            ? _AssetThumbnail(
                                key: ValueKey(entry.cover!.id),
                                asset: entry.cover!,
                                size: 100,
                                colors: colors,
                              )
                            : ColoredBox(color: colors.placeholder),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.path.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: StudioType.sans(
                              15,
                              weight: StudioType.medium,
                              color: colors.primary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${entry.count}',
                            style: StudioType.mono(12, color: colors.secondary),
                          ),
                        ],
                      ),
                    ),
                    if (selected)
                      StudioIcon(
                        StudioIcons.check,
                        size: 18,
                        color: colors.primary,
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AssetThumbnail extends StatefulWidget {
  const _AssetThumbnail({super.key, required this.asset, required this.size, required this.colors});

  final AssetEntity asset;
  final int size;
  final _PickerColors colors;

  @override
  State<_AssetThumbnail> createState() => _AssetThumbnailState();
}

class _AssetThumbnailState extends State<_AssetThumbnail> {
  late Future<Uint8List?> _future = _load();

  Future<Uint8List?> _load() =>
      widget.asset.thumbnailDataWithSize(ThumbnailSize.square(widget.size));

  @override
  void didUpdateWidget(covariant _AssetThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only re-fetch if this slot now represents a different asset/size
    // (e.g. switching albums reuses the same grid slots for new assets) —
    // not just because the parent rebuilt (which happens on every
    // select/deselect tap and must not re-trigger a fresh fetch, or
    // `FutureBuilder` flashes back to its placeholder each time).
    if (oldWidget.asset.id != widget.asset.id || oldWidget.size != widget.size) {
      _future = _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _future,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null) return ColoredBox(color: widget.colors.placeholder);
        return Image.memory(bytes, fit: BoxFit.cover);
      },
    );
  }
}

class _PermissionFallback extends StatelessWidget {
  const _PermissionFallback({required this.onRetry, required this.colors});

  final VoidCallback onRetry;
  final _PickerColors colors;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: StudioSpace.marginForm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StudioIcon(StudioIcons.newFolder, size: 32, color: colors.primary),
            const SizedBox(height: 16),
            Text(
              'Please give access to your gallery',
              textAlign: TextAlign.center,
              style: StudioType.sans(
                15,
                weight: StudioType.medium,
                color: colors.primary,
              ),
            ),
            const SizedBox(height: 20),
            // The primary pill: Ink on the page, Gallery White on the dark flyer picker.
            Semantics(
              button: true,
              child: GestureDetector(
                onTap: onRetry,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: BorderRadius.circular(StudioRadius.round),
                  ),
                  child: Text(
                    'Allow access',
                    style: StudioType.sans(15, weight: StudioType.medium, color: colors.background),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The picker's colours: the theme's, or fixed dark ones for [PostGalleryPicker.onDark].
class _PickerColors {
  const _PickerColors({
    required this.background,
    required this.primary,
    required this.secondary,
    required this.placeholder,
  });

  factory _PickerColors.of(BuildContext context, {required bool onDark}) {
    if (onDark) {
      return const _PickerColors(
        background: StudioColors.ink,
        primary: StudioColors.galleryWhite,
        secondary: StudioColors.onDarkSecondary,
        placeholder: Color(0x1AFAFAF8),
      );
    }
    final c = context.studio;
    return _PickerColors(
      background: c.background,
      primary: c.textPrimary,
      secondary: c.textSecondary,
      placeholder: c.surface,
    );
  }

  final Color background;
  final Color primary;
  final Color secondary;
  final Color placeholder;
}

/// One grid cell (`PostPicker`): the picture; when picked, a 2 Ink outline inside it and its
/// order in a 22 Ink circle (1.5 page-colour ring, Mono 11); otherwise a 1.5 white ring over a
/// light shade. Videos carry their length as a white Mono label.
class PostGalleryCell extends StatelessWidget {
  const PostGalleryCell({
    super.key,
    required this.child,
    required this.number,
    required this.onTap,
    this.videoLength,
    this.onDark = false,
  });

  final Widget child;

  /// Its place in the order (1, 2, ...), or null when not picked.
  final int? number;
  final VoidCallback onTap;
  final String? videoLength;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final picked = number != null;
    // On the dark flyer picker the marks are white, so they still show.
    final mark = onDark ? StudioColors.galleryWhite : c.textPrimary;
    final markText = onDark ? StudioColors.ink : c.background;
    return Semantics(
      button: true,
      selected: picked,
      label: picked ? 'Photo $number' : 'Photo',
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            child,
            if (videoLength != null)
              Positioned(
                left: 8,
                bottom: 6,
                child: StudioImageLabel(videoLength!, icon: StudioIcons.video),
              ),
            if (picked) DecoratedBox(decoration: BoxDecoration(border: Border.all(color: mark, width: 2))),
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: picked ? mark : const Color(0x26000000),
                  border: Border.all(color: picked ? markText : Colors.white, width: 1.5),
                ),
                child: picked
                    ? Text('$number', style: StudioType.mono(11, height: 1, color: markText))
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
