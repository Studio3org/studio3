import 'package:flutter/material.dart';

import '../../models/explore_feed_block.dart';
import '../../theme/studio_colors.dart';
import '../../theme/studio_metrics.dart';
import '../../theme/studio_type.dart';
import 'explore_category_chips.dart';
import 'explore_search_bar.dart';

/// Explore title, search pill and the category chips. Scrolls with the page.
class ExploreTop extends StatelessWidget {
  const ExploreTop({
    super.key,
    required this.searchController,
    required this.onSearchChanged,
    required this.selectedCategory,
    required this.onCategorySelected,
    this.mediums = const [],
    this.selectedMedium,
    this.onMediumSelected,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final ExploreCategory selectedCategory;
  final ValueChanged<ExploreCategory> onCategorySelected;
  final List<String> mediums;
  final String? selectedMedium;
  final ValueChanged<String>? onMediumSelected;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            StudioSpace.marginFeed,
            StudioSpace.s16,
            StudioSpace.marginFeed,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Explore', style: StudioType.title26(color: c.textPrimary)),
                ),
              ),
              const SizedBox(height: 14),
              ExploreSearchBar(
                controller: searchController,
                onChanged: onSearchChanged,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ExploreCategoryChips(
          selected: selectedCategory,
          onSelected: onCategorySelected,
          mediums: mediums,
          selectedMedium: selectedMedium,
          onMediumSelected: onMediumSelected,
        ),
      ],
    );
  }
}
