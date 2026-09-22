import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/post_location_options.dart';
import '../services/location_search_service.dart';
import '../screens/profile/profile_constants.dart';
import '../theme/home_feed_tokens.dart';
import 'create_flow/create_flow_widgets.dart';
import 'post_picker_search_field.dart';
import 'loading/app_skeletons.dart';

/// Draggable location picker — live search via `LocationSearchService`
/// (Nominatim), plus a "Use current location" option.
/// Starts at ~1/3 screen; expands to ~88% when scrolled/dragged.
class ChooseLocationSheet extends StatefulWidget {
  const ChooseLocationSheet({super.key, required this.onLocationSelected});

  final ValueChanged<PostLocationOption> onLocationSelected;

  static Future<void> show(
    BuildContext context, {
    required ValueChanged<PostLocationOption> onLocationSelected,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) =>
          ChooseLocationSheet(onLocationSelected: onLocationSelected),
    );
  }

  @override
  State<ChooseLocationSheet> createState() => _ChooseLocationSheetState();
}

class _ChooseLocationSheetState extends State<ChooseLocationSheet> {
  static const _sheetBg = HomeFeedTokens.background;
  static const _handleColor = Color(0xFFC8C5BC);
  static const _disabledFill = Color(0xFFC8C5BC);

  static const _initialSize = 0.55;
  static const _maxSize = 0.88;

  final _searchController = TextEditingController();
  Timer? _debounce;
  List<PostLocationOption> _results = const [];
  bool _searching = false;
  bool _locating = false;
  PostLocationOption? _pending;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 3) {
      setState(() {
        _results = const [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      final results = await LocationSearchService.search(value);
      if (!mounted) return;
      setState(() {
        _results = results;
        _searching = false;
      });
    });
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission denied')),
        );
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      final location = await LocationSearchService.reverseGeocode(
        position.latitude,
        position.longitude,
      );
      if (!mounted) return;
      if (location == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not determine your location')),
        );
        return;
      }
      setState(() => _pending = location);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not get current location')),
      );
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _onDone() {
    final selected = _pending;
    if (selected == null) return;
    widget.onLocationSelected(selected);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final canSubmit = _pending != null;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        initialChildSize: _initialSize,
        minChildSize: 0.4,
        maxChildSize: _maxSize,
        expand: false,
        builder: (context, scrollController) {
          return DecoratedBox(
            decoration: const BoxDecoration(
              color: _sheetBg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _handleColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Add location',
                      style: kProfileGeist(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: PostPickerSearchField(
                    controller: _searchController,
                    hintText: 'Search locations',
                    onChanged: _onQueryChanged,
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    children: [
                      if (_searchController.text.trim().isEmpty)
                        _UseCurrentLocationTile(
                          loading: _locating,
                          onTap: _locating ? null : _useCurrentLocation,
                        ),
                      if (_searching)
                        const OptionListSkeleton(
                          itemCount: 4,
                          padding: EdgeInsets.symmetric(vertical: 8),
                        )
                      else
                        for (final location in _results)
                          _LocationListTile(
                            location: location,
                            selected: _pending?.id == location.id,
                            onTap: () => setState(() => _pending = location),
                          ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(10, 8, 10, safeBottom + 16),
                  child: CreateFlowBottomButton(
                    label: 'Done',
                    height: 40,
                    backgroundColor: canSubmit
                        ? HomeFeedTokens.neutral800
                        : _disabledFill,
                    textColor: canSubmit
                        ? HomeFeedTokens.textInverse
                        : HomeFeedTokens.textPrimary,
                    onTap: canSubmit ? _onDone : null,
                    child: Text(
                      'Done',
                      style: GoogleFonts.geist(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: canSubmit
                            ? HomeFeedTokens.textInverse
                            : HomeFeedTokens.textPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _UseCurrentLocationTile extends StatelessWidget {
  const _UseCurrentLocationTile({required this.loading, required this.onTap});

  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              if (loading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                const Icon(
                  Icons.my_location,
                  size: 16,
                  color: HomeFeedTokens.textPrimary,
                ),
              const SizedBox(width: 10),
              Text(
                'Use current location',
                style: kProfileGeist(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocationListTile extends StatelessWidget {
  const _LocationListTile({
    required this.location,
    required this.onTap,
    this.selected = false,
  });

  static const _textSecondary = Color(0xFF8C8880);

  final PostLocationOption location;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              location.name,
              style: kProfileGeist(
                fontSize: 16,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            if (location.subtitle.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                location.subtitle,
                style: kProfileGeist(
                  fontSize: 12,
                  color: _textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
