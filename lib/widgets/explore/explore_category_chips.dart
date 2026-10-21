import 'package:flutter/material.dart';

import '../../models/explore_feed_block.dart';
import '../../theme/studio_metrics.dart';
import '../studio/studio_chip.dart';

/// The existing All / Pieces / Scenes filter, drawn as the 36-tall chip.
class ExploreCategoryChips extends StatelessWidget {
  const ExploreCategoryChips({
    super.key,
    required this.selected,
    required this.onSelected,
    this.mediums = const [],
    this.selectedMedium,
    this.onMediumSelected,
  });

  final ExploreCategory selected;
  final ValueChanged<ExploreCategory> onSelected;

  /// Mediums already present on loaded pieces. Empty when the payload has none.
  final List<String> mediums;
  final String? selectedMedium;
  final ValueChanged<String>? onMediumSelected;

  static const _labels = {
    ExploreCategory.all: 'All',
    ExploreCategory.pieces: 'Pieces',
    ExploreCategory.scenes: 'Scenes',
  };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: StudioSpace.marginFeed),
        itemCount: ExploreCategory.values.length + mediums.length,
        separatorBuilder: (context, index) => const SizedBox(width: StudioSpace.s8),
        itemBuilder: (context, index) {
          if (index < ExploreCategory.values.length) {
            final category = ExploreCategory.values[index];
            return StudioChip(
              label: _labels[category]!,
              selected: category == selected,
              onTap: () => onSelected(category),
            );
          }
          final medium = mediums[index - ExploreCategory.values.length];
          return StudioChip(
            label: medium,
            selected: medium == selectedMedium,
            onTap: () => onMediumSelected?.call(medium),
          );
        },
      ),
    );
  }
}
