import 'package:flutter/material.dart';

import '../../models/feed_pop_result.dart';
import '../../models/feed_preview_item.dart';

/// Shared two-attempt bump + pop-to-home scroll behavior for detail pages.
class DetailScrollHandoff extends StatefulWidget {
  const DetailScrollHandoff({
    super.key,
    required this.tappedIndex,
    required this.filter,
    required this.slivers,
    this.onWillAdvance,
    this.scrollController,
    this.bottomInset = 0,
    this.bottomPadding = 48,
    this.collectBarHeight = 0,
  });

  final int tappedIndex;
  final FeedAvailabilityFilter filter;
  final List<Widget> slivers;
  final void Function(int nextIndex)? onWillAdvance;
  final ScrollController? scrollController;
  final double bottomInset;
  final double bottomPadding;
  final double collectBarHeight;

  @override
  State<DetailScrollHandoff> createState() => _DetailScrollHandoffState();
}

class _DetailScrollHandoffState extends State<DetailScrollHandoff> {
  static const double _bottomEpsilon = 4;
  static const double _maxBumpOffset = 14;

  late final ScrollController _scrollController;
  bool _ownsController = false;
  bool _didPop = false;
  bool _armPop = false;
  bool _overscrolledThisGesture = false;
  double _bumpOffset = 0;

  @override
  void initState() {
    super.initState();
    if (widget.scrollController != null) {
      _scrollController = widget.scrollController!;
    } else {
      _scrollController = ScrollController();
      _ownsController = true;
    }
  }

  @override
  void dispose() {
    if (_ownsController) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  bool _isAtBottom(ScrollMetrics metrics) {
    return metrics.maxScrollExtent <= 0 ||
        metrics.pixels >= metrics.maxScrollExtent - _bottomEpsilon;
  }

  void _popToHome() {
    if (_didPop) return;
    _didPop = true;
    final nextIndex = widget.tappedIndex + 1;
    widget.onWillAdvance?.call(nextIndex);
    Navigator.pop(
      context,
      FeedPopResult(
        nextIndex: nextIndex,
        filter: widget.filter,
      ),
    );
  }

  void _resetBump() {
    if (_bumpOffset == 0) return;
    setState(() => _bumpOffset = 0);
  }

  void _registerBottomOverscroll({double? rawOffset}) {
    _overscrolledThisGesture = true;
    final next = (rawOffset ?? _maxBumpOffset).clamp(0.0, _maxBumpOffset);
    if (next != _bumpOffset) {
      setState(() => _bumpOffset = next);
    }
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (_didPop) return false;

    final metrics = notification.metrics;

    if (notification is OverscrollNotification &&
        notification.metrics.axis == Axis.vertical &&
        notification.overscroll > 0 &&
        _isAtBottom(metrics)) {
      _registerBottomOverscroll(rawOffset: notification.overscroll);
    }

    if (notification is ScrollUpdateNotification &&
        _isAtBottom(metrics) &&
        notification.scrollDelta != null &&
        notification.scrollDelta! > 0) {
      _registerBottomOverscroll(
        rawOffset: _bumpOffset + notification.scrollDelta! * 0.35,
      );
    }

    if (notification is ScrollEndNotification) {
      _resetBump();

      if (!_overscrolledThisGesture) return false;
      _overscrolledThisGesture = false;

      if (!_isAtBottom(metrics)) return false;

      if (!_armPop) {
        _armPop = true;
        return false;
      }
      _popToHome();
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final bottomSpacer = widget.bottomInset +
        widget.bottomPadding +
        widget.collectBarHeight +
        _bumpOffset;

    return NotificationListener<ScrollNotification>(
      onNotification: _onScrollNotification,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          ...widget.slivers,
          SliverToBoxAdapter(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              transform: Matrix4.translationValues(0, _bumpOffset, 0),
              child: SizedBox(height: bottomSpacer),
            ),
          ),
        ],
      ),
    );
  }
}
