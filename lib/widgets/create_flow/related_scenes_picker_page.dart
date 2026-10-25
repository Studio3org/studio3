import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../data/post_media_assets.dart';
import '../../models/post_summary.dart';
import '../../screens/profile/profile_constants.dart';
import '../../theme/home_feed_tokens.dart';
import 'create_flow_widgets.dart';
import '../../theme/app_fonts.dart';

/// Full-screen related-scenes picker for the piece Details tab.
class RelatedScenesPickerPage extends StatefulWidget {
  const RelatedScenesPickerPage({
    super.key,
    required this.scenes,
    required this.selectedIds,
  });

  final List<PostSummary> scenes;
  final Set<String> selectedIds;

  static Future<Set<String>?> show(
    BuildContext context, {
    required List<PostSummary> scenes,
    required Set<String> selectedIds,
  }) {
    return Navigator.of(context).push<Set<String>>(
      MaterialPageRoute(
        builder: (_) => RelatedScenesPickerPage(
          scenes: scenes,
          selectedIds: selectedIds,
        ),
      ),
    );
  }

  @override
  State<RelatedScenesPickerPage> createState() =>
      _RelatedScenesPickerPageState();
}

class _RelatedScenesPickerPageState extends State<RelatedScenesPickerPage> {
  static const _textSecondary = Color(0xFF8C8880);
  static const _disabledFill = Color(0xFFC8C5BC);

  late final Set<String> _selected = Set<String>.from(widget.selectedIds);

  bool get _canSave => _selected.isNotEmpty;

  void _toggle(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  double _aspectOf(PostSummary scene) {
    final raw = scene.mediaAspectRatio;
    if (raw == '16:9') return 16 / 9;
    if (raw == '3:4') return 3 / 4;
    return 3 / 4;
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final count = _selected.length;

    return Scaffold(
      backgroundColor: HomeFeedTokens.background,
      body: Column(
        children: [
          ColoredBox(
            color: HomeFeedTokens.background,
            child: Padding(
              padding: EdgeInsets.only(top: topInset),
              child: SizedBox(
                height: 53,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          behavior: HitTestBehavior.opaque,
                          child: SvgPicture.asset(
                            PostMediaAssets.createBannerBack,
                            width: 7,
                            height: 14,
                            colorFilter: const ColorFilter.mode(
                              HomeFeedTokens.textPrimary,
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                      ),
                      Text(
                        'Related Scenes',
                        style: kProfileGeist(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (count > 0)
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '$count selected',
                            style: kProfileGeist(
                              fontSize: 13,
                              color: _textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: widget.scenes.isEmpty
                ? Center(
                    child: Text(
                      'You don\'t have any scenes yet.',
                      textAlign: TextAlign.center,
                      style: kProfileGeist(
                        fontSize: 14,
                        color: _textSecondary,
                      ),
                    ),
                  )
                : MasonryGridView.count(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    crossAxisCount: 2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    itemCount: widget.scenes.length,
                    itemBuilder: (context, index) {
                      final scene = widget.scenes[index];
                      final selected = _selected.contains(scene.id);
                      final url = (scene.thumbnailUrl != null &&
                              scene.thumbnailUrl!.isNotEmpty)
                          ? scene.thumbnailUrl
                          : scene.mediaUrl;
                      return _SceneTile(
                        imageUrl: url,
                        aspectRatio: _aspectOf(scene),
                        selected: selected,
                        isVideo: scene.isVideo,
                        onTap: () => _toggle(scene.id),
                      );
                    },
                  ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(10, 8, 10, bottomInset + 16),
            child: CreateFlowBottomButton(
              label: 'Save',
              height: 40,
              backgroundColor:
                  _canSave ? HomeFeedTokens.neutral800 : _disabledFill,
              textColor: HomeFeedTokens.textInverse,
              onTap: _canSave
                  ? () => Navigator.pop(context, _selected)
                  : null,
              child: Text(
                'Save',
                style: AppFonts.geist(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: HomeFeedTokens.textInverse,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SceneTile extends StatelessWidget {
  const _SceneTile({
    required this.imageUrl,
    required this.aspectRatio,
    required this.selected,
    required this.isVideo,
    required this.onTap,
  });

  final String? imageUrl;
  final double aspectRatio;
  final bool selected;
  final bool isVideo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (imageUrl != null && imageUrl!.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: imageUrl!,
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) =>
                      const ColoredBox(color: Color(0xFFE2DED6)),
                )
              else
                const ColoredBox(color: Color(0xFFE2DED6)),
              if (isVideo)
                const Align(
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected
                        ? HomeFeedTokens.neutral800
                        : Colors.white.withValues(alpha: 0.35),
                    border: Border.all(
                      color: selected
                          ? HomeFeedTokens.neutral800
                          : Colors.white,
                      width: 1.4,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: selected
                      ? const Icon(
                          Icons.check,
                          size: 13,
                          color: HomeFeedTokens.textInverse,
                        )
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
