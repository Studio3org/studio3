import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../data/post_location_options.dart';
import '../services/location_search_service.dart';
import '../theme/studio_colors.dart';
import '../theme/studio_type.dart';
import 'post_picker_search_field.dart';
import 'studio/studio_button.dart';
import 'studio/studio_icon.dart';
import 'studio/studio_select_row.dart';
import 'studio/studio_sheet.dart';
import 'studio/studio_toast.dart';

/// Location picker (`PostLocation`): live city search via `LocationSearchService`
/// (Nominatim) and "Use my current city". The chosen city takes the left line; Done
/// confirms it. Only the city is ever public — the footer says so.
class ChooseLocationSheet extends StatefulWidget {
  const ChooseLocationSheet({
    super.key,
    required this.onLocationSelected,
    this.selected,
    this.subtitle = 'Where the piece is now.',
  });

  final ValueChanged<PostLocationOption> onLocationSelected;
  final PostLocationOption? selected;
  final String subtitle;

  /// Opens the sheet; [onLocationSelected] runs once Done is tapped (the sheet closes
  /// itself).
  static Future<void> show(
    BuildContext context, {
    required ValueChanged<PostLocationOption> onLocationSelected,
    PostLocationOption? selected,
    String subtitle = 'Where the piece is now.',
  }) {
    return showStudioSheet<void>(
      context: context,
      builder: (context) => ChooseLocationSheet(
        onLocationSelected: onLocationSelected,
        selected: selected,
        subtitle: subtitle,
      ),
    );
  }

  @override
  State<ChooseLocationSheet> createState() => _ChooseLocationSheetState();
}

class _ChooseLocationSheetState extends State<ChooseLocationSheet> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  late List<PostLocationOption> _results = [?widget.selected];
  late PostLocationOption? _selected = widget.selected;
  bool _searching = false;
  bool _locating = false;

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
        _results = [?_selected];
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
        if (mounted) showStudioToast(context, 'Location permission denied', icon: null);
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      final location = await LocationSearchService.reverseGeocode(
        position.latitude,
        position.longitude,
      );
      if (!mounted) return;
      if (location == null) {
        showStudioToast(context, 'Could not find your city', icon: null);
        return;
      }
      setState(() {
        _selected = location;
        _results = [location];
      });
    } catch (_) {
      if (mounted) showStudioToast(context, 'Could not get your location', icon: null);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _done() {
    final selected = _selected;
    if (selected == null) return;
    widget.onLocationSelected(selected);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final mq = MediaQuery.of(context);
    return PickerSheetFrame(
      title: 'Location',
      subtitle: widget.subtitle,
      search: PostPickerSearchField(
        controller: _searchController,
        hintText: 'Search cities',
        onChanged: _onQueryChanged,
      ),
      header: Semantics(
        button: true,
        child: GestureDetector(
          onTap: _locating ? null : _useCurrentLocation,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                if (_locating)
                  SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: c.textPrimary),
                  )
                else
                  StudioIcon(StudioIcons.location, size: 20, color: c.textPrimary),
                const SizedBox(width: 10),
                Text(
                  'Use my current city',
                  style: StudioType.sans(15, weight: StudioType.medium, color: c.textPrimary),
                ),
              ],
            ),
          ),
        ),
      ),
      footer: Text(
        'Only the city shows on your piece. Your exact pickup address stays private in '
        'payout settings.',
        style: StudioType.caption12(height: 1.5, color: c.textSecondary),
      ),
      done: StudioButton(label: 'Done', onPressed: _selected == null ? null : _done),
      maxHeight: mq.size.height - 120,
      list: _searching
          ? [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: c.textSecondary),
                  ),
                ),
              ),
            ]
          : [
              for (var i = 0; i < _results.length; i++)
                StudioListRow(
                  title: _results[i].name,
                  subtitle: _results[i].subtitle,
                  selected: _selected?.id == _results[i].id,
                  divider: i < _results.length - 1,
                  onTap: () => setState(() => _selected = _results[i]),
                ),
            ],
    );
  }
}

/// The picker sheet frame (`PostMedium`, `PostLocation`): grabber, 22/500 title over a
/// 14/1.45 Graphite line, the search field, an optional [header] (count or current city),
/// the scrolling [list], an optional [footer] line and the 52 Done button; 10 24 34
/// padding, 16 gaps, top 120 from the screen top.
class PickerSheetFrame extends StatelessWidget {
  const PickerSheetFrame({
    super.key,
    required this.title,
    required this.subtitle,
    required this.search,
    required this.list,
    required this.done,
    required this.maxHeight,
    this.header,
    this.footer,
  });

  final String title;
  final String subtitle;
  final Widget search;
  final Widget? header;
  final List<Widget> list;
  final Widget? footer;
  final Widget done;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: SizedBox(
        height: maxHeight,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 34),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: StudioSheetGrabber()),
              const SizedBox(height: 16),
              Text(title, style: StudioType.title22(color: c.textPrimary)),
              const SizedBox(height: 4),
              Text(subtitle, style: StudioType.body14(height: 1.45, color: c.textSecondary)),
              const SizedBox(height: 16),
              search,
              if (header != null) ...[const SizedBox(height: 16), header!],
              const SizedBox(height: 16),
              Expanded(
                child: ListView(padding: EdgeInsets.zero, children: list),
              ),
              if (footer != null) ...[const SizedBox(height: 16), footer!],
              const SizedBox(height: 16),
              done,
            ],
          ),
        ),
      ),
    );
  }
}
