import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/post_material_options.dart';
import '../data/post_media_assets.dart';
import '../theme/home_feed_tokens.dart';
import '../widgets/post_picker_search_field.dart';

/// Material search & pick list — second step of add materials flow.
class PickMaterialsPage extends StatefulWidget {
  const PickMaterialsPage({
    super.key,
    required this.initialSelection,
  });

  final List<PostMaterialOption> initialSelection;

  @override
  State<PickMaterialsPage> createState() => _PickMaterialsPageState();
}

class _PickMaterialsPageState extends State<PickMaterialsPage> {
  static const _neutral300 = Color(0xFFC8C5BC);

  late List<PostMaterialOption> _selected;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selected = List<PostMaterialOption>.from(widget.initialSelection);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<PostMaterialOption> _filter(List<PostMaterialOption> source) {
    if (_query.isEmpty) return source;
    final q = _query.toLowerCase();
    return source.where((m) => m.name.toLowerCase().contains(q)).toList();
  }

  void _toggleMaterial(PostMaterialOption material) {
    setState(() {
      final index = _selected.indexWhere((m) => m.id == material.id);
      if (index >= 0) {
        _selected.removeAt(index);
      } else {
        _selected.add(material);
      }
    });
  }

  List<Widget> _buildCategorySection(
    String category,
    List<PostMaterialOption> items,
  ) {
    if (items.isEmpty) return const [];
    return [
      _SectionHeader(title: category),
      const SizedBox(height: 8),
      ...items.map(
        (material) => _MaterialPickerTile(
          material: material,
          selected: _selected.any((m) => m.id == material.id),
          onTap: () => _toggleMaterial(material),
        ),
      ),
      const SizedBox(height: 20),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final byCategory = PostMaterialOptions.byCategory;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          ColoredBox(
            color: Colors.black,
            child: Padding(
              padding: EdgeInsets.only(top: topInset),
              child: SizedBox(
                height: 64,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        behavior: HitTestBehavior.opaque,
                        child: SvgPicture.asset(
                          PostMediaAssets.createCloseIcon,
                          width: 14,
                          height: 14,
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            'Add materials',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: HomeFeedTokens.textInverse,
                            ),
                          ),
                        ),
                      ),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.pop(context, _selected),
                          borderRadius: BorderRadius.circular(100),
                          child: Container(
                            width: 60,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _neutral300,
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              'Done',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: HomeFeedTokens.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 12, 10, 8),
            child: PostPickerSearchField(
              controller: _searchController,
              hintText: 'Search materials',
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(10, 8, 10, bottomInset + 16),
              children: [
                for (final category in PostMaterialOptions.categories)
                  ..._buildCategorySection(
                    category,
                    _filter(byCategory[category] ?? const []),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  static const _textSecondary = Color(0xFF8C8880);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 6),
        child: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: _textSecondary,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

class _MaterialRow extends StatelessWidget {
  const _MaterialRow({required this.material});

  final PostMaterialOption material;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(
        material.name,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: HomeFeedTokens.textInverse,
          height: 1.25,
        ),
      ),
    );
  }
}

class _MaterialPickerTile extends StatelessWidget {
  const _MaterialPickerTile({
    required this.material,
    required this.selected,
    required this.onTap,
  });

  final PostMaterialOption material;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? Colors.white.withValues(alpha: 0.06)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: _MaterialRow(material: material),
        ),
      ),
    );
  }
}
