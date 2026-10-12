import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../services/permission_service.dart';
import '../../services/photo_library_service.dart';

enum _LoadState { loading, denied, ready }

class _AlbumEntry {
  const _AlbumEntry({required this.path, required this.cover, required this.count});

  final AssetPathEntity path;
  final AssetEntity? cover;
  final int count;
}

/// Custom in-app photo grid + album picker replacing the native OS photo
/// picker, so the post-creation flow can show its own "Recents ⌄" album
/// dropdown (Figma post-gallery redesign).
class PostGalleryPicker extends StatefulWidget {
  const PostGalleryPicker({
    super.key,
    required this.openNotifier,
    required this.onAlbumChanged,
    required this.onSelectionChanged,
    required this.onPermissionPermanentlyDenied,
    this.maxSelection = 10,
    this.allowVideos = false,
  });

  final ValueNotifier<bool> openNotifier;
  final ValueChanged<String> onAlbumChanged;
  final ValueChanged<List<AssetEntity>> onSelectionChanged;
  final VoidCallback onPermissionPermanentlyDenied;
  final int maxSelection;
  /// When true (Scene posts), the grid mixes in videos alongside photos,
  /// uses a 3:4 cell ratio, and selecting a video is exclusive of photos.
  final bool allowVideos;

  @override
  State<PostGalleryPicker> createState() => _PostGalleryPickerState();
}

class _PostGalleryPickerState extends State<PostGalleryPicker> {
  _LoadState _state = _LoadState.loading;
  List<_AlbumEntry> _albums = const [];
  _AlbumEntry? _selectedAlbum;
  List<AssetEntity> _assets = const [];
  final List<AssetEntity> _selected = [];

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
        if (_selected.length >= widget.maxSelection) return;
        setState(() => _selected.add(asset));
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

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildBody(),
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
        return const Center(
          child: CircularProgressIndicator(color: Colors.white54),
        );
      case _LoadState.denied:
        return _PermissionFallback(onRetry: _retry);
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
    final selected = _selected.any((a) => a.id == asset.id);
    final isVideo = asset.type == AssetType.video;
    return GestureDetector(
      onTap: () => _toggleSelect(asset),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _AssetThumbnail(key: ValueKey(asset.id), asset: asset, size: 200),
          if (isVideo)
            Container(
              color: Colors.black.withValues(alpha: 0.22),
              alignment: Alignment.center,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          if (isVideo)
            Positioned(
              right: 6,
              bottom: 6,
              child: Text(
                _formatDuration(asset.videoDuration),
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: Colors.white,
                ),
              ),
            ),
          if (selected) Container(color: Colors.black.withValues(alpha: 0.35)),
          Positioned(
            top: 6,
            right: 6,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? Colors.white : Colors.black.withValues(alpha: 0.3),
                border: Border.all(color: Colors.white, width: 1.2),
              ),
              child: selected
                  ? const Icon(Icons.check, size: 14, color: Colors.black)
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlbumMenu() {
    return ColoredBox(
      color: Colors.black,
      child: ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: _albums.length,
        itemBuilder: (context, index) {
          final entry = _albums[index];
          final selected = _selectedAlbum?.path.id == entry.path.id;
          return ListTile(
            onTap: () => _selectAlbum(entry),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 44,
                height: 44,
                child: entry.cover != null
                    ? _AssetThumbnail(
                        key: ValueKey(entry.cover!.id),
                        asset: entry.cover!,
                        size: 100,
                      )
                    : const ColoredBox(color: Colors.white10),
              ),
            ),
            title: Text(
              entry.path.name,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 15,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            subtitle: Text(
              '${entry.count}',
              style: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
            ),
          );
        },
      ),
    );
  }
}

class _AssetThumbnail extends StatefulWidget {
  const _AssetThumbnail({super.key, required this.asset, required this.size});

  final AssetEntity asset;
  final int size;

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
        if (bytes == null) return const ColoredBox(color: Colors.white10);
        return Image.memory(bytes, fit: BoxFit.cover);
      },
    );
  }
}

class _PermissionFallback extends StatelessWidget {
  const _PermissionFallback({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.photo_library_outlined, color: Colors.white, size: 56),
          const SizedBox(height: 16),
          Text(
            'Please give access to your gallery',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: onRetry,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            child: Text('Allow access', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
