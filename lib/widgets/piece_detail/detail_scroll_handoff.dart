import 'package:flutter/material.dart';

/// Scroll container for piece/scene detail. Stays on this page — no feed
/// advance when the user overscrolls the bottom.
class DetailScrollHandoff extends StatelessWidget {
  const DetailScrollHandoff({
    super.key,
    required this.slivers,
    this.scrollController,
    this.bottomInset = 0,
    this.bottomPadding = 24,
  });

  final List<Widget> slivers;
  final ScrollController? scrollController;
  final double bottomInset;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      controller: scrollController,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        ...slivers,
        SliverToBoxAdapter(
          child: SizedBox(height: bottomInset + bottomPadding),
        ),
      ],
    );
  }
}
